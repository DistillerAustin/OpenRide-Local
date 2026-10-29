package dev.digitalducktape.openride.core.content

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LocalLibraryRepositoryTest {
    private fun repository() = LocalLibraryRepository(ApplicationProvider.getApplicationContext())

    @Test
    fun `valid remote ids are namespaced for distinct ride history`() {
        val id = "0123456789abcdef01234567"
        assertEquals("local:$id", LocalVideoIds.fromRemote(id))
        assertEquals(id, LocalVideoIds.remoteId("local:$id"))
        assertTrue(LocalVideoIds.isLocal("local:$id"))
        assertFalse(LocalVideoIds.isLocal("vidLong00001"))
        assertNull(LocalVideoIds.fromRemote("../../etc/passwd"))
        assertNull(LocalVideoIds.remoteId("local:invalid"))
    }

    @Test
    fun `catalog keeps nested collection folders and metadata`() {
        val first = "0123456789abcdef01234567"
        val second = "aaaaaaaaaaaaaaaaaaaaaaaa"
        val payload = """
          {
            "api_version":1,
            "classes":[
              {"id":"$first","collection":"Peloton/Intervals","title":"Interval Ride","instructor":"Morgan",
               "duration_seconds":1800,"modified_utc":"2026-10-27T12:00:00+00:00"},
              {"id":"$second","collection":"Scenic/Rivers","title":"Riverside","instructor":"",
               "duration_seconds":1200,"modified_utc":"2026-10-28T12:00:00+00:00"},
              {"id":"not-a-class","collection":"Scenic/Rivers","title":"Invalid"}
            ]
          }
        """.trimIndent()
        val result = repository().parseCatalog(payload, "http://192.168.1.73:8766")
        assertEquals(2, result.size)
        val workout = result.first { it.channelName == "NAS / Peloton/Intervals" }
        assertEquals(ContentCategory.Workout, workout.category)
        assertEquals(1, workout.videos.size)
        assertEquals("local:$first", workout.videos.single().id)
        assertEquals("Morgan", workout.videos.single().channelName)
        assertEquals(1800, workout.videos.single().durationSec)
        assertTrue(workout.sourceId < 0)
        assertEquals("http://192.168.1.73:8766/api/v1/classes/$first/thumbnail", workout.videos.single().thumbnailUrl)
        val scenic = result.first { it.channelName == "NAS / Scenic/Rivers" }
        assertEquals(ContentCategory.Scenic, scenic.category)
        assertEquals(1, scenic.videos.size)
        assertNotNull(scenic.videos.single().durationSec)
    }

    @Test
    fun `address validation and video urls cannot inject a file path`() {
        val repo = repository()
        assertEquals("http://192.168.1.73:8766", repo.normalizeServerUrl(" http://192.168.1.73:8766/ "))
        assertEquals("", repo.normalizeServerUrl("  "))
        assertEquals("", repo.normalizeServerUrl("/"))
        assertNull(repo.playbackUrl("local:../../etc/passwd"))
        assertNull(repo.playbackUrl("youtubevideo"))
        for (bad in listOf("file:///etc/passwd", "ftp://localhost", "http://user:pass@host", "http://localhost/path", "http://localhost?bad=1")) {
            try {
                repo.normalizeServerUrl(bad)
                throw AssertionError("Accepted unsafe server address: $bad")
            } catch (_: IllegalArgumentException) { }
        }
    }
}
