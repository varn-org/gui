package dev.varn.gui

import android.app.Activity
import android.widget.FrameLayout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner

/**
 * What the host sets up around the surface, and what it gives back when it is finished with it.
 *
 * A host event is delivered by the engine's loop rather than in place, so a tree only comes down on a
 * tick, and what was set up to watch the window outlives the surface unless it is taken off.
 */
@RunWith(RobolectricTestRunner::class)
class HostTest {
    /** Stands in for the engine, keeping every call in the order it was made. */
    private class Engine : VarnGUIHost.VarnRuntimeDriving {
        val calls = mutableListOf<String>()
        val registered = mutableListOf<String>()

        override fun register(name: String, function: (String) -> String?): Int {
            registered.add(name)
            return 0
        }

        override fun emit(name: String, jsonArgument: String): Int {
            calls.add("emit:$name")
            return 0
        }

        override fun loadString(source: String, chunkName: String): Int {
            calls.add("load")
            return 0
        }

        override fun poll(): Boolean {
            calls.add("poll")
            return true
        }
    }

    private lateinit var activity: Activity
    private lateinit var surface: FrameLayout
    private lateinit var engine: Engine
    private lateinit var host: VarnGUIHost

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        surface = FrameLayout(activity)
        activity.setContentView(surface)

        engine = Engine()
        host = VarnGUIHost(engine, surface)
        host.start("/archive.vap", "/framework", "/cache")
    }

    @Test
    fun `the tree is taken down on a tick the pump is still there to take`() {
        engine.calls.clear()
        host.stop()

        val stopped = engine.calls.indexOf("emit:gui.stop")
        val polled = engine.calls.indexOf("poll")

        assertTrue("the host says it is finished: ${engine.calls}", stopped >= 0)
        assertTrue("and the loop is given the tick that delivers it: ${engine.calls}", polled > stopped)
    }

    @Test
    fun `what watches the window is given back with it`() {
        host.stop()
        engine.calls.clear()

        surface.layout(0, 0, 400, 800)
        surface.viewTreeObserver.dispatchOnGlobalLayout()

        assertEquals("a stopped host reports nothing more", emptyList<String>(), engine.calls)
    }

    @Test
    fun `the calls the engine may make are registered before the application is loaded`() {
        assertTrue("the batch is applied through the host", engine.registered.contains("gui_apply"))
        assertTrue("the surface is described to it", engine.registered.contains("gui_surface"))
        assertEquals("and the application is loaded once", 1, engine.calls.count { it == "load" })
    }
}
