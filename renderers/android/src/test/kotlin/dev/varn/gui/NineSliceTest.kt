package dev.varn.gui

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
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
import java.io.File

/**
 * A picture cut into nine, drawn here as nine pieces rather than through a compiled nine-patch.
 *
 * None of this is visible from the tree: a frame with the pieces in the wrong places has the right type,
 * the right props and the right size, and what is wrong with it is that the ornament on its corners came
 * out stretched. So what is read here is where each piece was actually taken from and put.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class NineSliceTest {
    private lateinit var activity: Activity
    private lateinit var surface: FrameLayout
    private lateinit var renderer: VarnRenderer

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()

        surface = FrameLayout(activity)
        activity.setContentView(surface)

        renderer = VarnRenderer(activity, surface) { _, _, _ -> }
    }

    /** Writes a picture out to a file, since a frame is cut in the pixels of a real one. */
    private fun drawn(width: Int, height: Int): String {
        val picture = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Canvas(picture).drawColor(Color.MAGENTA)

        val file = File.createTempFile("frame", ".png", activity.cacheDir)
        file.outputStream().use { picture.compress(Bitmap.CompressFormat.PNG, 100, it) }

        return file.absolutePath
    }

    private fun frame(props: Map<String, Any?>, width: Int, height: Int): VarnNineSliceView {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to 1, "type" to "nineslice", "props" to JSONObject(props))),
                    JSONObject(mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1)),
                    JSONObject(
                        mapOf("op" to "frame", "id" to 1, "x" to 0, "y" to 0, "width" to width, "height" to height),
                    ),
                ),
            ),
        )

        return surface.getChildAt(0) as VarnNineSliceView
    }

    /** Records what was taken from where, which is the whole of what drawing nine pieces amounts to. */
    private class Pieces : Canvas() {
        val taken = mutableListOf<Pair<Rect, Rect>>()

        override fun drawBitmap(bitmap: Bitmap, source: Rect?, destination: Rect, paint: android.graphics.Paint?) {
            taken += Rect(source) to Rect(destination)
        }
    }

    private fun pieces(view: VarnNineSliceView): List<Pair<Rect, Rect>> {
        val drawing = Pieces()
        view.draw(drawing)

        return drawing.taken
    }

    @Test
    fun aFrameIsDrawnAsNinePieces() {
        val picture = drawn(48, 48)
        val view = frame(
            mapOf("source" to picture, "slice" to JSONObject(mapOf("top" to 12, "right" to 12, "bottom" to 12, "left" to 12))),
            300,
            120,
        )

        assertEquals(9, pieces(view).size)
    }

    /** The corners are taken from the corners and put at the corners, at the size they were cut at. */
    @Test
    fun theCornersAreNeverStretched() {
        val picture = drawn(48, 48)
        val view = frame(
            mapOf("source" to picture, "slice" to JSONObject(mapOf("top" to 12, "right" to 12, "bottom" to 12, "left" to 12))),
            300,
            120,
        )

        val drawn = pieces(view)

        assertTrue(
            "the top left corner is drawn at its own size",
            drawn.any { it.first == Rect(0, 0, 12, 12) && it.second == Rect(0, 0, 12, 12) },
        )

        assertTrue(
            "the bottom right corner is drawn at its own size, against the far edge",
            drawn.any { it.first == Rect(36, 36, 48, 48) && it.second == Rect(288, 108, 300, 120) },
        )
    }

    /** The middle is stretched across everything the corners and the edges left of the box. */
    @Test
    fun theMiddleFillsWhatIsLeft() {
        val picture = drawn(48, 48)
        val view = frame(
            mapOf("source" to picture, "slice" to JSONObject(mapOf("top" to 12, "right" to 12, "bottom" to 12, "left" to 12))),
            300,
            120,
        )

        assertTrue(
            "the middle of the picture is stretched across the middle of the box",
            pieces(view).any { it.first == Rect(12, 12, 36, 36) && it.second == Rect(12, 12, 288, 108) },
        )
    }

    /** Drawn twice as thick, the pieces are taken from the same place and put down twice the size. */
    @Test
    fun theScaleSaysHowThickTheBorderIsDrawn() {
        val picture = drawn(48, 48)
        val view = frame(
            mapOf(
                "source" to picture,
                "slice" to JSONObject(mapOf("top" to 12, "right" to 12, "bottom" to 12, "left" to 12)),
                "sliceScale" to 2,
            ),
            300,
            120,
        )

        assertTrue(
            "the same corner, drawn twice as large",
            pieces(view).any { it.first == Rect(0, 0, 12, 12) && it.second == Rect(0, 0, 24, 24) },
        )
    }

    /** A picture cut wider than itself has no middle left to stretch, so it is drawn whole instead. */
    @Test
    fun aPictureCutWiderThanItselfIsDrawnWhole() {
        val picture = drawn(20, 20)
        val view = frame(
            mapOf("source" to picture, "slice" to JSONObject(mapOf("top" to 30, "right" to 30, "bottom" to 30, "left" to 30))),
            300,
            120,
        )

        val drawn = pieces(view)

        assertEquals(1, drawn.size)
        assertEquals(Rect(0, 0, 20, 20) to Rect(0, 0, 300, 120), drawn.first())
    }

    /** A frame holds what is written inside it, which is what makes the same thing a window. */
    @Test
    fun aFrameHoldsWhatIsInsideIt() {
        val picture = drawn(48, 48)

        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(
                        mapOf(
                            "op" to "create", "id" to 1, "type" to "nineslice",
                            "props" to JSONObject(
                                mapOf(
                                    "source" to picture,
                                    "slice" to JSONObject(mapOf("top" to 12, "right" to 12, "bottom" to 12, "left" to 12)),
                                ),
                            ),
                        ),
                    ),
                    JSONObject(mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1)),
                    JSONObject(mapOf("op" to "create", "id" to 2, "type" to "text", "props" to JSONObject(mapOf("text" to "inside")))),
                    JSONObject(mapOf("op" to "insert", "id" to 2, "parent" to 1, "index" to 1)),
                ),
            ),
        )

        val view = surface.getChildAt(0) as VarnNineSliceView
        assertEquals(1, view.childCount)
    }

    /** The renderer says it draws one, so a screen can ask before it builds itself out of frames. */
    @Test
    fun theRendererSaysItDrawsOne() {
        assertEquals(true, renderer.capabilities["nineSlice"])
    }

    /**
     * A frame draws the artwork the state it is in names, and the plain one for a state naming none.
     *
     * Which picture is drawn is told apart by where the pieces are cut from: the two are different sizes,
     * so the far corner of one is taken from somewhere the other has no pixels at all.
     */
    @Test
    fun aFrameDrawsTheArtworkForTheStateItIsIn() {
        val plain = drawn(48, 48)
        val held = drawn(64, 64)

        val view = frame(
            mapOf(
                "source" to plain,
                "sources" to JSONObject(mapOf("pressed" to held)),
                "slice" to JSONObject(mapOf("top" to 12, "right" to 12, "bottom" to 12, "left" to 12)),
            ),
            300,
            120,
        )

        assertTrue(
            "a frame nobody is touching is cut from the plain picture",
            pieces(view).any { it.first == Rect(36, 36, 48, 48) },
        )

        view.isPressed = true

        assertTrue(
            "and one under a finger is cut from the picture named for that",
            pieces(view).any { it.first == Rect(52, 52, 64, 64) },
        )

        view.isPressed = false
        view.isEnabled = false

        assertTrue(
            "a state the frame names no artwork for keeps the plain picture",
            pieces(view).any { it.first == Rect(36, 36, 48, 48) },
        )
    }

}
