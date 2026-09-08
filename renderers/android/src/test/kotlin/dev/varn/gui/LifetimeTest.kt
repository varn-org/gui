package dev.varn.gui

import android.app.Activity
import android.widget.FrameLayout
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

/**
 * What a node opens is given back when the node goes, and not before.
 *
 * A cell that scrolls out of a list detaches and comes back, so a player closed on detaching is a sound
 * that never plays again and a map whose fetchers were shut down never draws another tile. Removing the
 * node is the one moment that is right, and it is the renderer that knows it.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LifetimeTest {
    private lateinit var surface: FrameLayout
    private lateinit var renderer: VarnRenderer

    @Before
    fun setUp() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

        surface = FrameLayout(activity)
        activity.setContentView(surface)
        renderer = VarnRenderer(activity, surface) { _, _, _ -> }
    }

    private fun build(id: Int, type: String, props: Map<String, Any?>) {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to id, "type" to type, "props" to JSONObject(props))),
                    JSONObject(mapOf("op" to "insert", "id" to id, "parent" to 0, "index" to 1)),
                ),
            ),
        )
    }

    private fun remove(id: Int) {
        renderer.apply(JSONArray(listOf(JSONObject(mapOf("op" to "remove", "id" to id)))))
    }

    @Test
    fun `a sound that left the window and came back can still be played`() {
        build(1, "audio", mapOf("source" to "loop.mp3", "playing" to false))

        val sound = surface.getChildAt(0) as VarnAudioView

        surface.removeView(sound)
        surface.addView(sound)

        assertEquals("nothing it holds was given back on the way out", false, sound.closed)

        sound.setPlaying(true)
        sound.setPlaying(false)
    }

    @Test
    fun `a map that left the window and came back still asks for its tiles`() {
        build(2, "map", mapOf("center" to JSONObject(mapOf("latitude" to 0, "longitude" to 0)), "zoom" to 3))

        val map = surface.getChildAt(0) as VarnMapView

        surface.removeView(map)
        surface.addView(map)
        map.layout(0, 0, 200, 200)
        map.settle()

        assertTrue("the map is still the one that was built", map.isAttachedToWindow)
        assertEquals("and it still asks for its tiles", false, map.closed)
    }

    @Test
    fun `a node that goes takes what it opened with it`() {
        build(3, "audio", mapOf("source" to "loop.mp3", "playing" to false))

        val sound = surface.getChildAt(0) as VarnAudioView

        remove(3)

        assertEquals("the view is off the screen", 0, surface.childCount)
        assertEquals("and the player it held is given back", true, sound.closed)
    }
}
