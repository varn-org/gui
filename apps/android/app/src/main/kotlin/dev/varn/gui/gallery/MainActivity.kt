package dev.varn.gui.gallery

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import com.varn.VarnRuntime
import dev.varn.gui.VarnBoxView
import dev.varn.gui.VarnFilePicker
import dev.varn.gui.VarnGUIHost
import java.io.File
import java.util.zip.ZipInputStream

/** Shows the gallery, which is the packed archive the iOS and web hosts run unchanged. */
class MainActivity : Activity() {
    private var host: VarnGUIHost? = null
    private var choosing: VarnFilePicker? = null
    private var deciding: ((Boolean) -> Unit)? = null

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)

        val surface = VarnBoxView(this)
        setContentView(surface, FrameLayout.LayoutParams(MATCH, MATCH))

        surface.post { start(surface) }
    }

    @Deprecated("The tree is what decides where back goes, so it is asked before the activity closes.")
    override fun onBackPressed() {
        if (host?.goBack() == true) {
            return
        }

        @Suppress("DEPRECATION")
        super.onBackPressed()
    }

    /**
     * Hands what the chooser came back with to the picker that asked for it.
     *
     * A result belongs to the activity that started the chooser, which is why the tree asks for one
     * rather than opening it itself.
     */
    override fun onActivityResult(request: Int, result: Int, data: Intent?) {
        super.onActivityResult(request, result, data)

        val picker = choosing

        if (request != CHOOSE || picker == null) {
            return
        }

        choosing = null

        if (result != RESULT_OK || data == null) {
            return
        }

        host?.chose(picker, chosen(data))
    }

    /** Hands the reader's answer to the node that asked for the permission. */
    override fun onRequestPermissionsResult(request: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(request, permissions, results)

        val decide = deciding

        if (request != ALLOW || decide == null) {
            return
        }

        deciding = null
        decide(results.firstOrNull() == PackageManager.PERMISSION_GRANTED)
    }

    /** Answers everything a chooser came back with, which is one file or a set of them. */
    private fun chosen(data: Intent): List<Uri> {
        val several = data.clipData

        if (several != null) {
            return (0 until several.itemCount).map { at -> several.getItemAt(at).uri }
        }

        return listOfNotNull(data.data)
    }

    override fun onDestroy() {
        host?.stop()
        super.onDestroy()
    }

    private fun start(surface: VarnBoxView) {
        try {
            val archive = copyOut("gallery.vap")
            val framework = unpack("framework.zip")

            val driver = VarnDriver(VarnRuntime())
            val host = VarnGUIHost(driver, surface)
            host.onProblem = { problem -> report(surface, problem) }

            host.onChoose = { picker, intent ->
                choosing = picker
                startActivityForResult(intent, CHOOSE)
            }

            host.onPermission = { permission, decide ->
                deciding = decide
                requestPermissions(arrayOf(permission), ALLOW)
            }

            this.host = host
            host.start(archive.absolutePath, framework.absolutePath, File(cacheDir, "varn-gui").absolutePath)
        } catch (problem: Exception) {
            report(surface, "the gallery failed to start: ${problem.message}")
        }
    }

    /** Copies an asset out to a real file, since the engine reads a filesystem and assets are not one. */
    private fun copyOut(name: String): File {
        val target = File(cacheDir, name)

        assets.open(name).use { source ->
            target.outputStream().use { into -> source.copyTo(into) }
        }

        return target
    }

    /** Unpacks the framework beside the archive, which is what the engine requires from. */
    private fun unpack(name: String): File {
        val root = File(cacheDir, "framework")
        root.deleteRecursively()
        root.mkdirs()

        ZipInputStream(assets.open(name)).use { source ->
            var entry = source.nextEntry

            while (entry != null) {
                val target = File(root, entry.name)

                if (entry.isDirectory) {
                    target.mkdirs()
                } else {
                    target.parentFile?.mkdirs()
                    target.outputStream().use { into -> source.copyTo(into) }
                }

                entry = source.nextEntry
            }
        }

        return root
    }

    /** Shows what went wrong as something a reader can put away, rather than as part of the screen. */
    private fun report(surface: VarnBoxView, message: String) {
        runOnUiThread {
            android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_LONG).show()
        }
    }

    private companion object {
        const val MATCH = FrameLayout.LayoutParams.MATCH_PARENT
        const val CHOOSE = 1
        const val ALLOW = 2
    }
}

/** Carries the engine's runtime to the host, which knows only the four calls it needs. */
private class VarnDriver(private val runtime: VarnRuntime) : VarnGUIHost.VarnRuntimeDriving {
    override fun register(name: String, function: (String) -> String?): Int =
        runtime.register(name) { argument -> function(argument) }

    override fun emit(name: String, jsonArgument: String): Int = runtime.emit(name, jsonArgument)

    override fun loadString(source: String, chunkName: String): Int = runtime.loadString(source, chunkName)

    override fun poll(): Boolean = runtime.poll()
}
