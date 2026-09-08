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
    /**
     * Asked with the chooser to start, since an activity's result belongs to the activity that started it.
     *
     * The renderer holds no activity, which is what would leak one on a rotation, so the request is
     * passed up and the answer comes back through [VarnFilePicker.chosen].
     */
    var onChoose: ((VarnFilePicker, android.content.Intent) -> Unit)? = null

    var onPermission: ((String, (Boolean) -> Unit) -> Unit)? = null

    private class Node(val view: View, val type: String) {
        val props = mutableMapOf<String, Any?>()

        /** Whether the node has been on screen once, which is what tells an arrival from a change. */
        var settled = false

        /** Whether the arrival it was given is still waiting for the frame it is drawn against. */
        var arriving = false
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
        "haptics" to true, "safearea" to true, "audio" to true, "map" to true, "location" to true, "gradient" to true, "blur" to true,
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

        (view as? VarnFilePicker)?.onOpen = { picker, intent -> onChoose?.invoke(picker, intent) }
        (view as? VarnLocationView)?.onPermission = { permission, decide ->
            onPermission?.invoke(permission, decide)
        }

        view.id = View.generateViewId()
        val node = Node(view, type)
        nodes[id] = node

        op.optJSONObject("props")?.let { apply(it, node, id) }

        node.settled = true
        node.arriving = node.props["enter"] != null
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
    private val structural = setOf(
        "segments", "options", "count", "text", "title", "label", "transition", "enter",
    )

    private fun apply(props: JSONObject, node: Node, id: Int) {
        val ordered = props.keys().asSequence().sortedBy { if (structural.contains(it)) 0 else 1 }

        for (key in ordered) {
            val raw = props.get(key)
            val value = if (VarnValue.isRemoved(raw)) null else raw
            node.props[key] = value

            if (key == "transition" || key == "enter") {
                continue
            }

            if (key == "style") {
                applyStyle(value as? JSONObject ?: JSONObject(), node)
            } else {
                VarnProps.apply(key, value, node.view, node.type, id, density, emit)
            }
        }

        (node.view as? VarnSettling)?.settle()
    }

    /** Applies a style, over time when the node was told how long the change should take. */
    private fun applyStyle(style: JSONObject, node: Node) {
        val timing = if (node.settled) VarnMotion.timing(node.props["transition"]) else null

        if (timing == null) {
            VarnStyle.apply(style, node.view, node.type, density)
            return
        }

        VarnStyle.apply(style, node.view, node.type, density)
        VarnMotion.animate(node.view, style, timing)
    }

    /**
     * Draws the arrival of a node that was given a state to come from, once it knows what size it is.
     *
     * It waits for the frame because a state is written against the node it moves: a panel that arrives
     * from the whole of its own height has no height to travel until the layout has given it one.
     */
    private fun arrive(node: Node) {
        node.arriving = false

        val entering = node.props["enter"] as? JSONObject ?: return
        val timing = VarnMotion.timing(node.props["transition"]) ?: return

        VarnMotion.arrive(
            node.view,
            entering,
            node.props["style"] as? JSONObject ?: JSONObject(),
            node.type,
            density,
            timing,
        )
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

        (node.view as? VarnReleasing)?.release()
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

        // What a map is looking at depends on how big it turned out to be, so it is settled with the
        // frame rather than only with the props, and a box held against an edge is held again from
        // wherever the frame has just put it.
        (node.view as? VarnSettling)?.settle()

        if ((node.view as? VarnBoxView)?.pinned != null) {
            ((node.view.parent as? View)?.parent as? VarnCollectionView)?.hold()
        }

        // A pill radius is only known to be one once the box has a size, so the box is painted again
        // now that it has one.
        (node.props["style"] as? JSONObject)?.let { VarnStyle.apply(it, node.view, node.type, density) }

        // A label never wraps into a line it has no room for, unless the tree said how many it may run
        // to, which is a caller's own decision and not one a frame may take back.
        val label = node.view as? TextView
        if (label != null && label.lineHeight > 0) {
            val declared = node.props["numberOfLines"] as? Int

            label.maxLines = declared ?: maxOf(1, height / label.lineHeight)
            label.ellipsize = android.text.TextUtils.TruncateAt.END
        }

        if (node.arriving) {
            arrive(node)
        }
    }

    /** Answers what a string measures, which the layout engine caches and never guesses at. */
    fun measureText(text: String, style: JSONObject, bound: Double?): JSONObject {
        val paint = VarnStyle.paint(style, density)
        val leading = style.optDouble("lineHeight", 0.0)

        // What a string measures changes with everything it is drawn with, so all of it names the answer.
        val key = "$text|${paint.textSize}|${paint.typeface.hashCode()}|${paint.letterSpacing}|$leading|$bound"

        val cached = measurements.getOrPut(key) {
            val bounds = Rect()
            paint.getTextBounds(text, 0, text.length, bounds)

            // A text view lays its own text out with getDesiredWidth, so it is measured the same way
            // here. Measured any other way a label ends a fraction short, and it wraps and clips.
            val natural = android.text.Layout.getDesiredWidth(text, paint) + spacingWidth(text, paint)
            val lineHeight = if (leading > 0.0) (paint.fontSpacing * leading).toFloat() else paint.fontSpacing

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
     * Answers the room the space between letters takes, which not every layout counts for itself.
     *
     * The platform's own measurement does not always answer for the tracking a paint carries, and a
     * label that is measured without it is given a frame narrower than the text it goes on to draw.
     */
    private fun spacingWidth(text: String, paint: android.text.TextPaint): Float =
        paint.letterSpacing * paint.textSize * text.length

    /**
     * Answers the size the platform draws a control at, which is the one thing about it Lua cannot know.
     *
     * A number written into the tree is a number that was true of one platform on one day, and a frame
     * worked out from the old one spills the control out of the box it was given.
     */
    /**
     * Answers the size the platform draws a control at, which is the one thing about it Lua cannot know.
     *
     * A variant names which of a control the tree asked for. Android has no wheel of its own for a date,
     * so it answers nothing for that one rather than the size of the control it does have.
     */
    fun measureControl(type: String, variant: String?): JSONObject {
        if (variant == "wheel") {
            return JSONObject().put("width", 0).put("height", 0)
        }

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
            .put("platform", "android")
            .put("appearance", if (night == android.content.res.Configuration.UI_MODE_NIGHT_YES) "dark" else "light")
            .put("safeArea", insets)
    }
}

class VarnRendererException(message: String) : RuntimeException(message)

object VarnValue {
    /** The sentinel an update carries for a prop the new description no longer has. */
    fun isRemoved(value: Any?): Boolean = value == "__varn_removed__" || value == JSONObject.NULL
}
