package dev.varn.gui

import android.app.Activity
import android.graphics.Bitmap
import android.view.MotionEvent
import android.widget.FrameLayout
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

/**
 * The map Android draws itself, which is the one node here that is a whole control rather than a view
 * with props on it.
 *
 * Everything a tree relies on comes out of the projection: where a drag leaves the map, which mark a
 * press landed on, and whether a finger that travelled counts as a press at all. None of that is the
 * platform's here, so all of it is tested rather than trusted.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class PlaceTest {
    private lateinit var surface: FrameLayout
    private lateinit var renderer: VarnRenderer
    private val events = mutableListOf<Triple<Int, String, Any?>>()

    @Before
    fun setUp() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

        surface = FrameLayout(activity)
        activity.setContentView(surface)
        events.clear()

        renderer = VarnRenderer(activity, surface) { id, name, payload ->
            events.add(Triple(id, name, payload))
        }
    }

    private fun map(props: Map<String, Any?>): VarnMapView {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to 1, "type" to "map", "props" to JSONObject(props))),
                    JSONObject(mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1)),
                    JSONObject(mapOf("op" to "frame", "id" to 1, "x" to 0, "y" to 0, "width" to 300, "height" to 300)),
                ),
            ),
        )

        val view = surface.getChildAt(0) as VarnMapView
        view.layout(0, 0, 300, 300)

        return view
    }

    private fun touch(view: VarnMapView, action: Int, x: Float, y: Float) {
        val event = MotionEvent.obtain(0, 0, action, x, y, 0)

        view.onTouchEvent(event)
        event.recycle()
    }

    private fun reported(name: String) = events.filter { it.second == name }.map { it.third as JSONObject }

    private fun london() = JSONObject(mapOf("latitude" to 51.5074, "longitude" to -0.1278))

    @Test
    fun `a drag moves the map and reports where it ended up`() {
        val view = map(
            mapOf(
                "center" to london(),
                "zoom" to 12.0,
                "interactive" to true,
                "onRegionChange" to true,
                "onPress" to true,
            ),
        )

        touch(view, MotionEvent.ACTION_DOWN, 200f, 150f)
        touch(view, MotionEvent.ACTION_MOVE, 100f, 150f)
        touch(view, MotionEvent.ACTION_UP, 100f, 150f)

        val region = reported("onRegionChange")

        assertEquals(1, region.size)
        assertTrue(
            "dragging west moves the map east, it reported ${region[0]}",
            region[0].getJSONObject("center").getDouble("longitude") > -0.1278,
        )
        assertEquals("a drag is not a press", 0, reported("onPress").size)
    }

    @Test
    fun `a finger that stays put presses the map where it landed`() {
        val view = map(mapOf("center" to london(), "zoom" to 12.0, "interactive" to true, "onPress" to true))

        touch(view, MotionEvent.ACTION_DOWN, 150f, 150f)
        touch(view, MotionEvent.ACTION_UP, 150f, 150f)

        val pressed = reported("onPress")

        assertEquals(1, pressed.size)
        assertEquals(51.5074, pressed[0].getDouble("latitude"), 0.01)
        assertEquals(-0.1278, pressed[0].getDouble("longitude"), 0.01)
    }

    @Test
    fun `a press on a mark is that mark rather than the map under it`() {
        val view = map(
            mapOf(
                "center" to london(),
                "zoom" to 12.0,
                "interactive" to true,
                "markers" to JSONArray(
                    listOf(
                        JSONObject(mapOf("key" to "home", "latitude" to 51.5074, "longitude" to -0.1278)),
                    ),
                ),
                "onPress" to true,
                "onMarkerPress" to true,
            ),
        )

        touch(view, MotionEvent.ACTION_DOWN, 150f, 150f)
        touch(view, MotionEvent.ACTION_UP, 150f, 150f)

        assertEquals("home", reported("onMarkerPress").single().getString("key"))
        assertEquals("the map is not told about a press on one of its marks", 0, reported("onPress").size)
    }

    @Test
    fun `a map that may not be moved is not moved`() {
        val view = map(
            mapOf("center" to london(), "zoom" to 12.0, "interactive" to false, "onRegionChange" to true),
        )

        touch(view, MotionEvent.ACTION_DOWN, 200f, 150f)
        touch(view, MotionEvent.ACTION_MOVE, 100f, 150f)
        touch(view, MotionEvent.ACTION_UP, 100f, 150f)

        assertEquals(0, reported("onRegionChange").size)
    }

    @Test
    fun `a fix is asked for through the host, since a permission belongs to the activity`() {
        var wanted: String? = null
        var decide: ((Boolean) -> Unit)? = null

        renderer.onPermission = { permission, answer ->
            wanted = permission
            decide = answer
        }

        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(
                        mapOf(
                            "op" to "create",
                            "id" to 2,
                            "type" to "location",
                            "props" to JSONObject(mapOf("watch" to false, "accuracy" to "fine", "onError" to true)),
                        ),
                    ),
                    JSONObject(mapOf("op" to "insert", "id" to 2, "parent" to 0, "index" to 1)),
                ),
            ),
        )

        assertNotNull("a location node asks for the permission it needs", wanted)
        assertEquals(android.Manifest.permission.ACCESS_FINE_LOCATION, wanted)

        decide?.invoke(false)
        assertEquals("a reader who refuses is told rather than left waiting", 1, reported("onError").size)
    }

    @Test
    fun `a fix is asked for once however many props arrive with it`() {
        var asks = 0

        renderer.onPermission = { _, _ -> asks += 1 }

        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(
                        mapOf(
                            "op" to "create",
                            "id" to 3,
                            "type" to "location",
                            "props" to JSONObject(mapOf("watch" to false, "accuracy" to "fine", "onChange" to true)),
                        ),
                    ),
                    JSONObject(mapOf("op" to "insert", "id" to 3, "parent" to 0, "index" to 1)),
                    JSONObject(
                        mapOf(
                            "op" to "update",
                            "id" to 3,
                            "props" to JSONObject(mapOf("onChange" to true)),
                        ),
                    ),
                ),
            ),
        )

        assertEquals("a handler arriving is not a reason to ask the reader again", 1, asks)
    }

    @Test
    fun `a location node is not something a reader sees`() {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(
                        mapOf(
                            "op" to "create",
                            "id" to 4,
                            "type" to "location",
                            "props" to JSONObject(mapOf("watch" to false)),
                        ),
                    ),
                    JSONObject(mapOf("op" to "insert", "id" to 4, "parent" to 0, "index" to 1)),
                ),
            ),
        )

        val view = surface.getChildAt(0)

        assertTrue(view is VarnLocationView)
        assertEquals(android.view.View.GONE, view.visibility)
        assertNull("nothing is drawn for it", view.background)
    }

    /**
     * A box the tree pinned is held against the leading edge by the surface, not by the tree.
     *
     * A commit follows a finger rather than leading it, so a header placed from the tree drifts across
     * the rows it is meant to cover on every flick.
     */
    @Test
    fun `a pinned box is held while the surface scrolls`() {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(
                        mapOf(
                            "op" to "create", "id" to 6, "type" to "list",
                            "props" to JSONObject(mapOf("contentExtent" to 4000)),
                        ),
                    ),
                    JSONObject(mapOf("op" to "insert", "id" to 6, "parent" to 0, "index" to 1)),
                    JSONObject(
                        mapOf("op" to "frame", "id" to 6, "x" to 0, "y" to 0, "width" to 390, "height" to 800),
                    ),
                    JSONObject(
                        mapOf(
                            "op" to "create", "id" to 7, "type" to "view",
                            "props" to JSONObject(
                                mapOf("pinned" to JSONObject(mapOf("from" to 0, "to" to 1200))),
                            ),
                        ),
                    ),
                    JSONObject(mapOf("op" to "insert", "id" to 7, "parent" to 6, "index" to 1)),
                    JSONObject(mapOf("op" to "frame", "id" to 7, "x" to 0, "y" to 0, "width" to 390, "height" to 30)),
                ),
            ),
        )

        val list = surface.getChildAt(0) as VarnCollectionView
        val header = list.content.getChildAt(0) as VarnBoxView
        val density = list.context.resources.displayMetrics.density

        assertEquals(0f, header.translationY, 0.5f)

        list.scrollTo(0f, 400f * density, false)
        assertEquals("it follows the edge with no commit behind it", 400f * density, header.translationY, 0.5f)

        list.scrollTo(0f, 1190f * density, false)
        assertEquals(
            "until its range runs out and the next one pushes it off",
            1170f * density,
            header.translationY,
            0.5f,
        )

        // A row realised while the surface scrolls is inserted where the tree puts it, which is after
        // the header it belongs under, so the header has to be drawn over what arrives beneath it.
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to 8, "type" to "view", "props" to JSONObject())),
                    JSONObject(mapOf("op" to "insert", "id" to 8, "parent" to 6, "index" to 2)),
                    JSONObject(mapOf("op" to "frame", "id" to 8, "x" to 0, "y" to 1200,
                        "width" to 390, "height" to 44)),
                ),
            ),
        )

        assertEquals(
            "a row that arrives beneath a held box does not cover it",
            header,
            list.content.getChildAt(list.content.childCount - 1),
        )
    }

    /**
     * A tile is the same picture for every map, so what one fetched is there for the next one to open.
     *
     * A store of its own per map is a screen that re-fetches the world every time a reader comes back
     * to it, which is bandwidth on a phone and the one thing the tile service asks a client not to do.
     */
    @Test
    fun `a map that has gone leaves its tiles for the one that opens next`() {
        val first = map(mapOf("center" to JSONObject(mapOf("latitude" to 0, "longitude" to 0)), "zoom" to 3))

        VarnTiles.hold("3/1/1", Bitmap.createBitmap(4, 4, Bitmap.Config.ARGB_8888))

        renderer.apply(JSONArray(listOf(JSONObject(mapOf("op" to "remove", "id" to 1)))))

        assertTrue("the map that has gone asks for nothing more", first.closed)
        assertNotNull("and what it fetched is still there to draw", VarnTiles.get("3/1/1"))

        val second = map(mapOf("center" to JSONObject(mapOf("latitude" to 0, "longitude" to 0)), "zoom" to 3))

        assertEquals("the next map draws from the same store", false, second.closed)
        assertNotNull("without asking for the tile again", VarnTiles.get("3/1/1"))
    }
}
