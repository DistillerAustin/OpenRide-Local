package dev.digitalducktape.openride.core.content

import android.content.Context
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

/** Optional, LAN-only NAS source. Existing YouTube sources work when this server is offline. */
class LocalLibraryRepository(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("openride_local_library", Context.MODE_PRIVATE)

    var serverUrl: String
        get() = prefs.getString(SERVER_KEY, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL
        set(value) {
            prefs.edit().putString(SERVER_KEY, normalizeServerUrl(value)).apply()
        }

    /** Converts only a base http(s) URL; blank disables local content entirely. */
    fun normalizeServerUrl(raw: String): String {
        val candidate = raw.trim().trimEnd('/')
        if (candidate.isEmpty()) return ""
        val uri = try { URI(candidate) } catch (_: Exception) { null }
        require(
            uri != null &&
                (uri.scheme.equals("http", ignoreCase = true) || uri.scheme.equals("https", ignoreCase = true)) &&
                !uri.host.isNullOrBlank() &&
                uri.port in -1..65535 && uri.port != 0 &&
                uri.userInfo == null && uri.query == null && uri.fragment == null &&
                uri.path.isNullOrEmpty()
        ) { "Use an address such as http://192.168.1.73:8766 (or leave blank to disable)" }
        return candidate
    }

    /** Builds playback and thumbnail URLs from validated server IDs, never untrusted API URLs. */
    fun playbackUrl(localVideoId: String): String? =
        LocalVideoIds.remoteId(localVideoId)?.let { remote ->
            serverUrl.takeIf { it.isNotEmpty() }?.let { "$it/api/v1/classes/$remote/video" }
        }

    private fun thumbnailUrl(remoteId: String, baseUrl: String): String =
        "$baseUrl/api/v1/classes/$remoteId/thumbnail"

    suspend fun sections(): List<ChannelSection> = withContext(Dispatchers.IO) {
        val url = serverUrl
        if (url.isBlank()) return@withContext emptyList()
        val connection = URL("$url/api/v1/classes").openConnection() as HttpURLConnection
        connection.connectTimeout = 3500
        connection.readTimeout = 8000
        connection.requestMethod = "GET"
        connection.setRequestProperty("Accept", "application/json")
        try {
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                throw IOException("NAS library returned HTTP ${connection.responseCode}")
            }
            // Bounded response: no accidental unlimited read on a buggy/compromised endpoint.
            val text = connection.inputStream.bufferedReader().use { reader ->
                val content = StringBuilder()
                val chars = CharArray(8192)
                while (true) {
                    val count = reader.read(chars)
                    if (count < 0) break
                    content.append(chars, 0, count)
                    if (content.length > MAX_CATALOG_CHARS) throw IOException("NAS catalog is too large")
                }
                content.toString()
            }
            parseCatalog(text, url)
        } finally {
            connection.disconnect()
        }
    }

    /** Internal for tests; keeps parsing independent from a live NAS. */
    internal fun parseCatalog(json: String, baseUrl: String): List<ChannelSection> {
        val root = JSONObject(json)
        require(root.optInt("api_version", -1) == 1) { "Unsupported NAS library API version" }
        val entries = root.getJSONArray("classes")
        val grouped = linkedMapOf<String, MutableList<Video>>()
        for (index in 0 until entries.length()) {
            val item = entries.optJSONObject(index) ?: continue
            val remote = item.optString("id", "")
            val id = LocalVideoIds.fromRemote(remote) ?: continue
            val collection = item.optString("collection", "").trim().ifBlank { "Unsorted" }
            val instructor = item.optString("instructor", "").trim()
            val title = item.optString("title", "").trim().ifBlank { "Untitled class" }
            val duration = item.optInt("duration_seconds", -1).takeIf { it >= 0 }
            val published = try { Instant.parse(item.optString("modified_utc")).toEpochMilli() }
                catch (_: Exception) { 0L }
            grouped.getOrPut(collection) { mutableListOf() }.add(
                Video(
                    id = id,
                    title = title,
                    thumbnailUrl = thumbnailUrl(remote, baseUrl),
                    channelName = instructor.ifBlank { collection },
                    durationSec = duration,
                    publishedEpochMs = published,
                ),
            )
        }
        return grouped.toSortedMap(String.CASE_INSENSITIVE_ORDER).map { (collection, videos) ->
            // Negative IDs never alias real source-row IDs (Room autoincrements positive).
            val sectionId = -1L - (collection.hashCode().toLong() and 0x7fffffffL)
            ChannelSection(
                sourceId = sectionId,
                channelId = "local:$collection",
                channelName = "NAS / $collection",
                category = if (collection.split('/').any { it.contains("scenic", ignoreCase = true) })
                    ContentCategory.Scenic else ContentCategory.Workout,
                videos = videos.sortedByDescending { it.publishedEpochMs },
                refreshFailed = false,
            )
        }
    }

    companion object {
        const val DEFAULT_SERVER_URL = "http://192.168.1.73:8766"
        private const val SERVER_KEY = "server_url"
        private const val MAX_CATALOG_CHARS = 5_000_000
    }
}
