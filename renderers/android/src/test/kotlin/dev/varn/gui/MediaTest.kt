package dev.varn.gui

import android.app.Activity
import android.os.Looper
import android.widget.FrameLayout
import java.io.IOException
import java.time.Duration
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowMediaPlayer
import org.robolectric.shadows.util.DataSource

/**
 * What a sound is asked to do, and what it keeps doing once the tree has moved it.
 *
 * Moving to a moment is an action rather than a prop, since a prop is sent only when it differs from the
 * last one and a reader dragging a scrubber back to a moment they have already been at is still asking.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class MediaTest {
    private lateinit var surface: FrameLayout
    private lateinit var renderer: VarnRenderer
    private val heard = mutableListOf<Pair<String, JSONObject?>>()

    @Before
    fun setUp() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

        surface = FrameLayout(activity)
        activity.setContentView(surface)
        heard.clear()

        renderer = VarnRenderer(activity, surface) { _, name, payload ->
            heard.add(name to payload as? JSONObject)
        }
    }

    private fun build(id: Int, type: String, props: Map<String, Any?>): android.view.View {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to id, "type" to type, "props" to JSONObject(props))),
                    JSONObject(mapOf("op" to "insert", "id" to id, "parent" to 0, "index" to 1)),
                ),
            ),
        )

        return surface.getChildAt(surface.childCount - 1)
    }

    private fun settle() = shadowOf(Looper.getMainLooper()).idle()

    @Test
    fun seekingMovesTheSoundAndAskingTwiceMovesItTwice() {
        ShadowMediaPlayer.addMediaInfo(
            DataSource.toDataSource(SOURCE),
            ShadowMediaPlayer.MediaInfo(184_000, 0),
        )

        val sound = build(1, "audio", mapOf("source" to SOURCE)) as VarnAudioView

        settle()

        renderer.invoke(1, "seek", JSONObject(mapOf("seconds" to 12.0)))
        settle()
        assertEquals(12_000, sound.player.currentPosition)

        // A reader who drags back to a moment the sound has already been at is asking for it again.
        sound.player.seekTo(13_000)
        settle()

        renderer.invoke(1, "seek", JSONObject(mapOf("seconds" to 12.0)))
        settle()
        assertEquals(12_000, sound.player.currentPosition)
    }

    @Test
    fun aMomentPastTheEndIsHeldToTheEnd() {
        ShadowMediaPlayer.addMediaInfo(
            DataSource.toDataSource(SOURCE),
            ShadowMediaPlayer.MediaInfo(10_000, 0),
        )

        val sound = build(1, "audio", mapOf("source" to SOURCE)) as VarnAudioView

        settle()

        renderer.invoke(1, "seek", JSONObject(mapOf("seconds" to 400.0)))
        settle()
        assertEquals(10_000, sound.player.currentPosition)

        renderer.invoke(1, "seek", JSONObject(mapOf("seconds" to -5.0)))
        settle()
        assertEquals(0, sound.player.currentPosition)
    }

    /**
     * A sound reports where it is for as long as it holds one, however the tree moves it.
     *
     * A move is a detach and an attach on this platform, so a ticker tied to the window stops the first
     * time a sibling appears above the sound and never starts again: the sound plays on and the scrubber
     * beside it stays where it was.
     */
    @Test
    fun aSoundThatIsMovedKeepsReportingWhereItIs() {
        ShadowMediaPlayer.addMediaInfo(
            DataSource.toDataSource(SOURCE),
            ShadowMediaPlayer.MediaInfo(184_000, 0),
        )

        val sound = build(1, "audio", mapOf("source" to SOURCE, "onProgress" to true)) as VarnAudioView

        settle()

        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to 2, "type" to "text", "props" to JSONObject())),
                    JSONObject(mapOf("op" to "insert", "id" to 2, "parent" to 0, "index" to 1)),
                    JSONObject(mapOf("op" to "move", "id" to 1, "parent" to 0, "index" to 2)),
                ),
            ),
        )

        heard.clear()
        sound.player.seekTo(30_000)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(400))

        val position = heard.lastOrNull { it.first == "onProgress" }?.second?.optDouble("position")

        assertEquals(30.0, position ?: -1.0, 0.001)
    }

    /**
     * A sound that cannot be opened says so, which is otherwise a play button that does nothing.
     *
     * Every other platform answers this: iOS reads it off the item's status and a browser raises `error`
     * on the element, so a sound that swallows what it was told is the one of the three that goes quiet.
     */
    @Test
    fun aSoundThatCannotBeOpenedSaysSo() {
        ShadowMediaPlayer.addException(DataSource.toDataSource(MISSING), IOException("there is no such file"))

        build(1, "audio", mapOf("source" to MISSING, "onError" to true))

        settle()

        val said = heard.lastOrNull { it.first == "onError" }

        assertNotNull("a sound that cannot be opened must report it, it reported $heard", said)
    }

    /**
     * How fast a sound plays is a prop it declares, so it reaches the player rather than the video alone.
     */
    @Test
    fun aSoundPlaysAtTheRateItWasGiven() {
        ShadowMediaPlayer.addMediaInfo(
            DataSource.toDataSource(SOURCE),
            ShadowMediaPlayer.MediaInfo(184_000, 0),
        )

        val sound = build(1, "audio", mapOf("source" to SOURCE, "playing" to true, "rate" to 1.5)) as VarnAudioView

        settle()

        assertEquals(1.5f, sound.rate, 0.001f)
    }

    @Test
    fun seekingSomethingThatIsNotASoundIsRefused() {
        build(2, "text", mapOf("text" to "nothing to play"))

        assertThrows(VarnRendererException::class.java) {
            renderer.invoke(2, "seek", JSONObject(mapOf("seconds" to 1.0)))
        }
    }

    private companion object {
        const val SOURCE = "https://example.test/loop.mp3"
        const val MISSING = "/nowhere/there-is-no-such-sound.mp3"
    }
}
