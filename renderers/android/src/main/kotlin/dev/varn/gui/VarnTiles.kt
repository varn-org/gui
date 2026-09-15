package dev.varn.gui

import android.content.ComponentCallbacks2
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import java.net.HttpURLConnection
import java.net.URL
import java.util.Collections
import java.util.concurrent.Executors

/**
 * The tiles every map draws from, fetched once and held for all of them.
 *
 * A tile is the same picture for every map on a screen and for the next screen to open one, and the
 * service they are served from asks a client to keep what it has already been given rather than asking
 * again — a map that forgets its tiles when a reader leaves the screen re-fetches the world on the way
 * back. What is held is given up when the application goes out of sight, which is what the platform
 * asks of anything holding pictures.
 */
internal object VarnTiles {
    private const val HELD = 24 * 1024
    private const val SERVED_AT = "https://tile.openstreetmap.org"
    private const val AGENT = "varn-gui"
    private const val TIMEOUT = 10000

    private val held = object : LruCache<String, Bitmap>(HELD) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount / 1024
    }

    private val asked = Collections.synchronizedSet(mutableSetOf<String>())
    private val fetchers = Executors.newFixedThreadPool(3)

    private var listening = false

    /** Answers a tile that has already been fetched, or nothing when it has not. */
    fun get(name: String): Bitmap? = held.get(name)

    /** Keeps a tile for every map that draws it, giving up the oldest once the store is full. */
    fun hold(name: String, tile: Bitmap) {
        held.put(name, tile)
    }

    /**
     * Asks for a tile once, however many maps are drawing it, and says when it has arrived.
     *
     * The tile is stored before anything is told about it, so a map that has gone by then leaves the
     * work of value behind rather than throwing it away.
     */
    fun ask(name: String, arrived: () -> Unit) {
        if (!asked.add(name)) {
            return
        }

        fetchers.execute {
            val drawn = read(name)

            if (drawn != null) {
                hold(name, drawn)
            }

            asked.remove(name)

            if (drawn != null) {
                arrived()
            }
        }
    }

    /** Gives the store back what it is holding when the platform asks for the memory. */
    fun listen(context: Context) {
        if (listening) {
            return
        }

        listening = true

        context.applicationContext.registerComponentCallbacks(object : ComponentCallbacks2 {
            override fun onTrimMemory(level: Int) {
                if (level >= ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
                    held.evictAll()
                }
            }

            override fun onLowMemory() {
                held.evictAll()
            }

            override fun onConfigurationChanged(configuration: Configuration) {}
        })
    }

    private fun read(name: String): Bitmap? {
        return runCatching {
            val connection = URL("$SERVED_AT/$name.png").openConnection() as HttpURLConnection

            connection.setRequestProperty("User-Agent", AGENT)
            connection.connectTimeout = TIMEOUT
            connection.readTimeout = TIMEOUT

            connection.inputStream.use { BitmapFactory.decodeStream(it) }
        }.getOrNull()
    }
}
