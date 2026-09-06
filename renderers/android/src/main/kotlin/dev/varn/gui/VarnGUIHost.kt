package dev.varn.gui

import android.graphics.Rect
import android.view.Choreographer
import android.view.ViewGroup
import org.json.JSONArray
import org.json.JSONObject

/**
 * Drives a Varn GUI application on Android, owning the run loop the engine is advanced from.
 *
 * The engine is never given a thread of its own. The chunk is loaded and then advanced one frame at a
 * time on the main thread, so every host call the script makes arrives on the thread that owns the
 * interface and the renderer touches its views with no post and no lock.
 */
class VarnGUIHost(
    private val runtime: VarnRuntimeDriving,
    private val surface: ViewGroup,
) {
    private val renderer = VarnRenderer(surface.context, surface) { id, name, payload ->
        runtime.emit(
            "gui.event",
            JSONObject().put("id", id).put("name", name).put("payload", payload ?: JSONObject.NULL).toString(),
        )
    }

    private val choreographer = Choreographer.getInstance()
    private val density = surface.context.resources.displayMetrics.density

    private var running = false
    private var keyboard = 0
    private var reportedWidth = 0
    private var reportedHeight = 0
    private var reportedAppearance = ""

    /** Called with anything that went wrong where the application could not be told itself. */
    var onProblem: ((String) -> Unit)? = null

    private val frame = object : Choreographer.FrameCallback {
        override fun doFrame(nanos: Long) {
            if (!running) {
                return
            }

            reportSurface()
            runtime.poll()
            choreographer.postFrameCallback(this)
        }
    }

    /**
     * Runs an application archive, which is the same file the iOS and web hosts run.
     *
     * The framework is Lua the application carries, so the engine is told where it was unpacked and
     * requires it from there.
     */
    fun start(archive: String, framework: String, cache: String) {
        register()
        observeInsets()

        val source = """
            package.path = "$framework/?.lua;$framework/?/init.lua;" .. package.path
            require("gui.host.launch").start({
                path = "$archive",
                cache = "$cache",
                onProblem = function(problem) host.gui_problem({ problem = problem }) end,
            })
        """.trimIndent()

        val code = runtime.loadString(source, "=varn-gui")
        if (code != 0) {
            throw VarnRendererException("the engine rejected the application with code $code")
        }

        running = true
        choreographer.postFrameCallback(frame)
    }

    fun stop() {
        running = false
        choreographer.removeFrameCallback(frame)
    }

    private fun register() {
        runtime.register("gui_apply") { json ->
            renderer.apply(JSONArray(json))
            "null"
        }

        runtime.register("gui_measure") { json ->
            val request = JSONObject(json)
            val style = request.optJSONObject("style") ?: JSONObject()
            val bound = if (request.isNull("bound")) null else request.optDouble("bound")

            renderer.measureText(request.optString("text"), style, bound).toString()
        }

        runtime.register("gui_measure_control") { json ->
            renderer.measureControl(JSONObject(json).getString("type")).toString()
        }

        runtime.register("gui_invoke") { json ->
            val request = JSONObject(json)
            val arguments = request.optJSONObject("arguments") ?: JSONObject()

            renderer.invoke(request.getInt("id"), request.getString("method"), arguments).toString()
        }

        runtime.register("gui_problem") { json ->
            onProblem?.invoke(JSONObject(json).optString("problem", "the application failed"))
            "null"
        }

        runtime.register("gui_capabilities") { JSONObject(renderer.capabilities.toMap()).toString() }

        runtime.register("gui_surface") { renderer.surfaceDescription().toString() }

        runtime.register("gui_register_font") { json ->
            val request = JSONObject(json)
            renderer.registerFont(request.getString("family"), request.getString("path"))
            runtime.emit("gui.fontsRegistered", "{}")
            "null"
        }
    }

    /**
     * Reports the keyboard and the safe area as measurements, which the tree treats as layout inputs.
     *
     * The window insets are the platform's own answer to both, so a screen avoids the notch and the
     * keyboard without ever asking what platform it is running on.
     */
    private fun observeInsets() {
        surface.viewTreeObserver.addOnGlobalLayoutListener {
            val visible = Rect()
            surface.getWindowVisibleDisplayFrame(visible)

            val covered = maxOf(0, surface.rootView.height - visible.bottom)
            val height = (covered / density).toInt()

            if (height != keyboard) {
                keyboard = height
                runtime.emit("gui.keyboard", JSONObject().put("height", height).toString())
            }
        }
    }

    private fun reportSurface() {
        val description = renderer.surfaceDescription()
        val appearance = description.optString("appearance")

        if (appearance != reportedAppearance) {
            reportedAppearance = appearance
            runtime.emit("gui.appearance", JSONObject().put("appearance", appearance).toString())
        }

        if (surface.width == reportedWidth && surface.height == reportedHeight) {
            return
        }

        reportedWidth = surface.width
        reportedHeight = surface.height

        runtime.emit("gui.resize", description.toString())
    }

    /** What the host needs of a runtime, so the renderer can be driven by a test as well as by the engine. */
    interface VarnRuntimeDriving {
        fun register(name: String, function: (String) -> String?): Int
        fun emit(name: String, jsonArgument: String): Int
        fun loadString(source: String, chunkName: String): Int
        fun poll(): Boolean
    }
}
