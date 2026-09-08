package dev.varn.gui

import android.content.Intent
import android.graphics.Rect
import android.net.Uri
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

    /**
     * Called with the chooser a tree asked to open, since only an activity may start one for a result.
     *
     * A host starts the intent from its activity and hands what came back to [chose], the same way it
     * hands over a back press. Leaving this unset is a tree with a file picker that opens nothing.
     */
    var onChoose: ((VarnFilePicker, Intent) -> Unit)?
        get() = renderer.onChoose
        set(value) { renderer.onChoose = value }

    /**
     * Called with the permission a tree asked for, since only an activity may ask a reader for one.
     *
     * The answer goes back through the function it is handed, so a screen that was refused is told
     * rather than left waiting. Leaving this unset is a tree that can never be allowed anything.
     */
    var onPermission: ((String, (Boolean) -> Unit) -> Unit)?
        get() = renderer.onPermission
        set(value) { renderer.onPermission = value }

    /** Hands a host's activity result to the picker that asked for it. */
    fun chose(picker: VarnFilePicker, uris: List<Uri>) {
        picker.chosen(uris)
    }

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

    /**
     * Reports the platform's own way back, which is what an activity hands over on a back press.
     *
     * A host calls this from `onBackPressed` and acts on what it answers: a tree that had somewhere to
     * go back to has gone there, and one that did not leaves the activity to close itself.
     */
    fun goBack(): Boolean {
        runtime.emit("gui.back", "{}")
        return running
    }

    /**
     * Takes the surface down, which is the tree as well as the loop that was driving it.
     *
     * Stopping the pump alone leaves every screen mounted: a timer a screen asked for goes on firing and
     * everything a node opened is still open, on an interface nobody is looking at.
     */
    fun stop() {
        runtime.emit("gui.stop", "{}")
        runtime.poll()

        running = false
        choreographer.removeFrameCallback(frame)
    }

    /**
     * Registers one call the engine can make, answering an error rather than throwing through it.
     *
     * What is registered here is called from the engine's own frame, so a failure that escapes unwinds
     * through it and takes the process with it. The engine is answered instead, and the application is
     * told what went wrong.
     */
    private fun answering(name: String, empty: String, work: (String) -> String?) {
        runtime.register(name) { json ->
            runCatching { work(json) }
                .getOrElse { problem ->
                    onProblem?.invoke("$name failed: ${problem.message ?: problem}")
                    empty
                }
        }
    }

    private fun register() {
        answering("gui_apply", "null") { json ->
            renderer.apply(JSONArray(json))
            "null"
        }

        answering("gui_measure", "{\"width\":0,\"height\":0}") { json ->
            val request = JSONObject(json)
            val style = request.optJSONObject("style") ?: JSONObject()
            val bound = if (request.isNull("bound")) null else request.optDouble("bound")

            renderer.measureText(request.optString("text"), style, bound).toString()
        }

        answering("gui_measure_control", "{\"width\":0,\"height\":0}") { json ->
            val request = JSONObject(json)
            renderer.measureControl(request.getString("type"), request.optString("variant", null)).toString()
        }

        answering("gui_invoke", "false") { json ->
            val request = JSONObject(json)
            val arguments = request.optJSONObject("arguments") ?: JSONObject()

            renderer.invoke(request.getInt("id"), request.getString("method"), arguments).toString()
        }

        answering("gui_problem", "null") { json ->
            onProblem?.invoke(JSONObject(json).optString("problem", "the application failed"))
            "null"
        }

        answering("gui_capabilities", "{}") { JSONObject(renderer.capabilities.toMap()).toString() }

        answering("gui_surface", "{}") { renderer.surfaceDescription().toString() }

        answering("gui_register_font", "null") { json ->
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
