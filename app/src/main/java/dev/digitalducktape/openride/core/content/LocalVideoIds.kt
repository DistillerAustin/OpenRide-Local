package dev.digitalducktape.openride.core.content

/**
 * Namespaced IDs keep NAS classes distinct from YouTube videos in the existing ride database.
 * The NAS API IDs are the first 24 hex chars of SHA-256(relative path).
 * Never include the filename or a URL in the route or persisted ride ID.
 */
object LocalVideoIds {
    const val PREFIX = "local:"
    private val remoteId = Regex("^[0-9a-f]{24}$")

    fun fromRemote(remote: String): String? = if (remoteId.matches(remote)) "$PREFIX$remote" else null

    fun remoteId(id: String): String? = id.takeIf { it.startsWith(PREFIX) }
        ?.removePrefix(PREFIX)?.takeIf { remoteId.matches(it) }

    fun isLocal(id: String): Boolean = remoteId(id) != null
}
