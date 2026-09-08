package dev.varn.gui

import android.content.Context
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.view.View
import org.json.JSONObject

/**
 * A sound with no picture and no player of its own.
 *
 * What draws a player is the tree, so this view is never seen. It is told whether it should be playing
 * and where to be, and it reports where it has got to and how long the whole thing is.
 */
class VarnAudioView(context: Context) : View(context), VarnReleasing {
    private val player = MediaPlayer()

    /** Whether the player this held has been given back, after which it answers nothing. */
    var closed = false
        private set

    private val ticker = Handler(Looper.getMainLooper())
    private var prepared = false
    private var wanted = false
    private var announced = false

    var onProgress: ((JSONObject) -> Unit)? = null
    var onReady: ((JSONObject) -> Unit)? = null
    var onEnd: (() -> Unit)? = null

    private val tick = object : Runnable {
        override fun run() {
            report()
            ticker.postDelayed(this, TICK)
        }
    }

    init {
        visibility = GONE

        player.setOnPreparedListener {
            prepared = true

            if (!announced) {
                announced = true
                onReady?.invoke(JSONObject().put("duration", player.duration / 1000.0))
            }

            if (wanted) {
                player.start()
            }
        }

        player.setOnCompletionListener {
            if (!player.isLooping) {
                onEnd?.invoke()
            }
        }

        ticker.postDelayed(tick, TICK)
    }

    override fun onDetachedFromWindow() {
        ticker.removeCallbacks(tick)
        super.onDetachedFromWindow()
    }

    override fun release() {
        if (closed) {
            return
        }

        closed = true
        ticker.removeCallbacks(tick)
        player.release()
    }

    fun setSource(value: String?) {
        prepared = false
        announced = false
        player.reset()

        if (value == null) {
            return
        }

        runCatching {
            player.setDataSource(value)
            player.prepareAsync()
        }
    }

    fun setPlaying(value: Boolean) {
        if (closed) {
            return
        }

        wanted = value

        if (!prepared) {
            return
        }

        if (value) {
            player.start()
            return
        }

        player.pause()
    }

    fun setLoops(value: Boolean) {
        player.isLooping = value
    }

    fun setVolume(value: Float) {
        player.setVolume(value, value)
    }

    /** Moves to a moment, which is what a scrubber asks for and never what playing reports back. */
    fun setPosition(seconds: Double) {
        if (!prepared || kotlin.math.abs(player.currentPosition / 1000.0 - seconds) <= 0.25) {
            return
        }

        player.seekTo((seconds * 1000).toInt())
    }

    private fun report() {
        if (!prepared) {
            return
        }

        onProgress?.invoke(
            JSONObject()
                .put("position", player.currentPosition / 1000.0)
                .put("duration", player.duration / 1000.0),
        )
    }

    private companion object {
        const val TICK = 250L
    }
}
