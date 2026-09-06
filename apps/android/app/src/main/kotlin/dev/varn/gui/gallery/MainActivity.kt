package dev.varn.gui.gallery

import android.app.Activity
import android.os.Bundle
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import com.varn.VarnRuntime
import dev.varn.gui.VarnBoxView
import dev.varn.gui.VarnGUIHost
import java.io.File
import java.util.zip.ZipInputStream

/** Shows the gallery, which is the packed archive the iOS and web hosts run unchanged. */
class MainActivity : Activity() {
    private var host: VarnGUIHost? = null

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)

        val surface = VarnBoxView(this)
        setContentView(surface, FrameLayout.LayoutParams(MATCH, MATCH))

        surface.post { start(surface) }
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

    private fun report(surface: VarnBoxView, message: String) {
        val label = TextView(this)
        label.text = message
        label.setPadding(32, 32, 32, 32)
        label.layoutParams = ViewGroup.LayoutParams(surface.width, surface.height)
        surface.addView(label)
        label.layout(0, 0, surface.width, surface.height)
    }

    private companion object {
        const val MATCH = FrameLayout.LayoutParams.MATCH_PARENT
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
