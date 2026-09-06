package dev.varn.gui

import android.content.Context
import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject

/**
 * Applies the operations a commit carries to real Android views, and reports events back.
 *
 * It decides nothing. Every size, colour and position arrives already resolved, which is what keeps
 * this renderer in agreement with the ones on iOS and the web.
 */
class VarnRenderer(
    private val context: Context,
    private val surface: ViewGroup,
    private val emit: (Int, String, Any?) -> Unit,
) {
    private class Node(val view: View, val type: String) {
        val props = mutableMapOf<String, Any?>()
    }

    private val nodes = mutableMapOf<Int, Node>()
    private val measurements = mutableMapOf<String, FloatArray>()

    // The label that answers what a string measures, styled exactly like the one that will draw it.
    private val gauge = TextView(context)
    private val density = context.resources.displayMetrics.density

    val capabilities: Map<String, Boolean> = mapOf(
        "text" to true, "image" to true, "list" to true, "scroll" to true, "input" to true,
        "video" to true, "webview" to true, "canvas" to true,
        "picker" to true, "datepicker" to true,
        "haptics" to true, "safearea" to true,
    )

    /** Applies one batch, which is the whole of what a commit does to the interface. */
    fun apply(ops: JSONArray) {
        for (index in 0 until ops.length()) {
            val op = ops.getJSONObject(index)

            when (val kind = op.getString("op")) {
                "create" -> create(op)
                "update" -> update(op)
                "insert", "move" -> place(op)
                "remove" -> remove(op.getInt("id"))
                "frame" -> frame(op)
                else -> throw VarnRendererException("unknown operation $kind")
            }
        }
    }

    private fun create(op: JSONObject) {
        val id = op.getInt("id")
        val type = op.getString("type")
        val view = VarnViewFactory.make(context, type)

        view.id = View.generateViewId()
        val node = Node(view, type)
        nodes[id] = node

        op.optJSONObject("props")?.let { apply(it, node, id) }
    }

    private fun expect(id: Int): Node =
        nodes[id] ?: throw VarnRendererException("the batch touched node $id, which was never created")

    private fun update(op: JSONObject) {
        val id = op.getInt("id")
        val props = op.optJSONObject("props")
            ?: throw VarnRendererException("an update carried no props")

        apply(props, expect(id), id)
    }

    /**
     * The props that build what a node holds, which are applied before the ones that choose among it.
     *
     * A batch carries props as a map, so they arrive in no order at all. Rebuilding the segments of a
     * control after the chosen one was set would drop the choice on whichever batch happened to be
     * ordered that way, which is a defect that comes and goes rather than one that can be found.
     */
    private val structural = setOf("segments", "options", "count", "text", "title", "label")

    private fun apply(props: JSONObject, node: Node, id: Int) {
        val ordered = props.keys().asSequence().sortedBy { if (structural.contains(it)) 0 else 1 }

        for (key in ordered) {
            val raw = props.get(key)
            val value = if (VarnValue.isRemoved(raw)) null else raw
            node.props[key] = value

            if (key == "style") {
                VarnStyle.apply(value as? JSONObject ?: JSONObject(), node.view, node.type, density)
            } else {
                VarnProps.apply(key, value, node.view, node.type, id, density, emit)
            }
        }
    }

    private fun place(op: JSONObject) {
        val node = expect(op.getInt("id"))
        val parent = op.getInt("parent")
        val index = op.getInt("index")

        val container = if (parent == 0) surface else VarnViewFactory.contentView(expect(parent).view)
        (node.view.parent as? ViewGroup)?.removeView(node.view)

        val position = index.minus(1).coerceIn(0, container.childCount)
        container.addView(node.view, position)
    }

    private fun remove(id: Int) {
        val node = nodes.remove(id) ?: return
        (node.view.parent as? ViewGroup)?.removeView(node.view)
    }

    private fun frame(op: JSONObject) {
        val node = expect(op.getInt("id"))
        val left = (op.getDouble("x") * density).toInt()
        val top = (op.getDouble("y") * density).toInt()
        val width = (op.getDouble("width") * density).toInt()
        val height = (op.getDouble("height") * density).toInt()

        // The engine sends finished frames, so a view is laid out rather than measured by its parent.
        node.view.layout(left, top, left + width, top + height)
        node.view.layoutParams = ViewGroup.LayoutParams(width, height)

        // A pill radius is only known to be one once the box has a size, so the box is painted again
        // now that it has one.
        (node.props["style"] as? JSONObject)?.let { VarnStyle.apply(it, node.view, node.type, density) }

        // The engine decided how many lines fit, so a label never wraps into one it has no room for.
        val label = node.view as? TextView
        if (label != null && label.lineHeight > 0) {
            label.maxLines = maxOf(1, height / label.lineHeight)
            label.ellipsize = android.text.TextUtils.TruncateAt.END
        }
    }

    /** Answers what a string measures, which the layout engine caches and never guesses at. */
    fun measureText(text: String, style: JSONObject, bound: Double?): JSONObject {
        val paint = VarnStyle.paint(style, density)
        val key = "$text|${paint.textSize}|${paint.typeface.hashCode()}|$bound"

        val cached = measurements.getOrPut(key) {
            val bounds = Rect()
            paint.getTextBounds(text, 0, text.length, bounds)

            // A text view lays its own text out with getDesiredWidth, so it is measured the same way
            // here. Measured any other way a label ends a fraction short, and it wraps and clips.
            val natural = android.text.Layout.getDesiredWidth(text, paint)
            val lineHeight = paint.fontSpacing

            // A bound of zero is a node that has not been measured yet, not a node with no room.
            val usable = if (bound != null && bound > 0) (bound * density).toFloat() else 0f

            if (usable > 0f && natural > usable) {
                floatArrayOf(usable, Math.ceil((natural / usable).toDouble()).toInt() * lineHeight)
            } else {
                // A width is rounded up, or a label ends a fraction of a pixel short and clips its text.
                floatArrayOf(Math.ceil(natural.toDouble()).toFloat(), lineHeight)
            }
        }

        return JSONObject()
            .put("width", cached[0] / density)
            .put("height", cached[1] / density)
    }

    /**
     * Answers the size the platform draws a control at, which is the one thing about it Lua cannot know.
     *
     * A number written into the tree is a number that was true of one platform on one day, and a frame
     * worked out from the old one spills the control out of the box it was given.
     */
    fun measureControl(type: String): JSONObject {
        val control = VarnViewFactory.make(context, type)
        val unbounded = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)

        control.measure(unbounded, unbounded)

        return JSONObject()
            .put("width", control.measuredWidth / density)
            .put("height", control.measuredHeight / density)
    }

    /** Registers a font from the bundle, after which any style may name its family. */
    fun registerFont(family: String, path: String) {
        VarnStyle.registerFont(family, path)
        measurements.clear()
    }

    /** Reaches a node imperatively, which is what a ref calls through. */
    fun invoke(id: Int, method: String, arguments: JSONObject): Boolean =
        VarnActions.perform(method, expect(id).view, arguments, density)

    /** Answers the surface the engine lays out inside, plus the insets the platform reports. */
    fun surfaceDescription(): JSONObject {
        val insets = VarnInsets.of(surface, density)

        val night = surface.context.resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK

        return JSONObject()
            .put("width", surface.width / density)
            .put("height", surface.height / density)
            .put("scale", density)
            .put("appearance", if (night == android.content.res.Configuration.UI_MODE_NIGHT_YES) "dark" else "light")
            .put("safeArea", insets)
    }
}

class VarnRendererException(message: String) : RuntimeException(message)

object VarnValue {
    /** The sentinel an update carries for a prop the new description no longer has. */
    fun isRemoved(value: Any?): Boolean = value == "__varn_removed__" || value == JSONObject.NULL
}
