package dev.varn.gui

import android.content.Intent
import android.graphics.Rect
import android.net.Uri
import android.view.Choreographer
import android.view.ViewGroup
import android.view.ViewTreeObserver
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
    private var started = false
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

    /**
     * Keeps a file where the system keeps pictures and films, or hands it to whatever sends one.
     *
     * What a camera captures is written where the application may write, which nothing outside it can
     * reach: a reader who took a picture has nothing until it is in the store the gallery reads. Sharing
     * goes through the same store, since an address anything else may open is what a chooser needs.
     */
    private fun keep(request: JSONObject) {
        val ticket = request.optInt("ticket")
        val file = java.io.File(request.optString("path"))

        fun answer(reply: JSONObject) {
            runtime.emit("gui.files", reply.put("ticket", ticket).toString())
        }

        if (!file.exists()) {
            answer(JSONObject().put("problem", "there is no file at ${file.path}"))
            return
        }

        runCatching {
            val kept = VarnLibrary.keep(surface.context, file)

            if (request.optString("action") == "share") {
                val given = request.optString("title")
                val chooser = VarnLibrary.share(surface.context, kept, file, given.ifEmpty { null })
                surface.context.startActivity(chooser)
            }

            answer(JSONObject().put("path", kept.toString()))
        }.onFailure { problem ->
            answer(JSONObject().put("problem", problem.message ?: "the file could not be kept"))
        }
    }

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
    /**
     * Takes a link while the application is running, which is what a deep link and an app link arrive as.
     *
     * Where the application was asked to be is what a router opens on, so one that arrives before the
     * engine has started is held rather than dropped, and one that arrives after is reported.
     */
    fun open(address: String) {
        renderer.address = address

        if (!started) {
            return
        }

        runtime.emit("gui.address", JSONObject().put("address", address).toString())
    }

    fun start(archive: String, framework: String, cache: String, address: String = "/") {
        renderer.address = address
        started = true

        register()
        observeInsets()

        val source = """
            package.path = "$framework/?.lua;$framework/?/init.lua;" .. package.path
            require("gui.host.launch").start({
                path = "$archive",
                framework = "$framework",
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
    /**
     * Tells the engine where the application is, which an activity knows and a view does not.
     *
     * An activity that is paused goes on running, unlike an application a phone has suspended and unlike
     * a tab a browser has hidden, so the same tree would otherwise behave three ways. It is handed over
     * and pumped in the same breath, since the frames stop coming once the window is gone and a moment
     * queued for a pump that is not coming is a screen never told it went away.
     */
    fun report(state: String) {
        if (!running || renderer.state == state) {
            return
        }

        renderer.state = state
        runtime.emit("gui.lifecycle", JSONObject().put("state", state).toString())
        runtime.poll()
    }

    /** Asks the engine for back what it can work out again, which is what the platform is asking for. */
    fun trimMemory() {
        if (!running) {
            return
        }

        runtime.emit("gui.memory", "{}")
        runtime.poll()
    }

    fun stop() {
        runtime.emit("gui.stop", "{}")
        runtime.poll()

        running = false
        choreographer.removeFrameCallback(frame)
        surface.viewTreeObserver.removeOnGlobalLayoutListener(insets)
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
            renderer.measureControl(JSONObject(json).getString("type")).toString()
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

        answering("gui_files", "null") { json ->
            keep(JSONObject(json))
            "null"
        }

        // A value crosses as json so it comes back as what it was rather than as the text of what it was.
        answering("gui_preferences", "null") { json ->
            val request = JSONObject(json)
            val ticket = request.optInt("ticket")
            val name = request.optString("name")
            val reply = JSONObject().put("ticket", ticket)

            try {
                when (request.optString("action")) {
                    "set" -> VarnPreferences.set(surface.context, name, request.opt("value").let { held ->
                        JSONArray().put(held).toString()
                    })

                    "get" -> {
                        val held = VarnPreferences.get(surface.context, name)

                        if (held != null) {
                            reply.put("value", JSONArray(held).opt(0))
                        }
                    }

                    "remove" -> VarnPreferences.remove(surface.context, name)
                    "clear" -> VarnPreferences.clear(surface.context)
                    "names" -> reply.put("value", JSONArray(VarnPreferences.names(surface.context)))
                    else -> reply.put("problem", "a preference is set, read, removed, cleared or listed")
                }
            } catch (problem: Throwable) {
                reply.put("problem", problem.message ?: "the keystore refused it")
            }

            runtime.emit("gui.preferences", reply.toString())
            "null"
        }

        answering("gui_theme", "null") { json ->
            renderer.showTheme(JSONObject(json))
            "null"
        }

        answering("gui_capabilities", "{}") { JSONObject(renderer.capabilities.toMap()).toString() }

        answering("gui_surface", "{}") { renderer.surfaceDescription().toString() }

        answering("gui_register_font", "null") { json ->
            val request = JSONObject(json)
            val weight = request.optString("weight", "400").toIntOrNull() ?: 400

            renderer.registerFont(request.getString("family"), weight, request.getString("path"))
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
        surface.viewTreeObserver.addOnGlobalLayoutListener(insets)
    }

    private val insets = ViewTreeObserver.OnGlobalLayoutListener {
        val visible = Rect()
        surface.getWindowVisibleDisplayFrame(visible)

        val covered = maxOf(0, surface.rootView.height - visible.bottom)
        val height = (covered / density).toInt()

        if (height != keyboard) {
            keyboard = height
            runtime.emit("gui.keyboard", JSONObject().put("height", height).toString())
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
