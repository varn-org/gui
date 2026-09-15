package dev.varn.gui

import android.content.Context
import android.media.MediaPlayer
import android.media.PlaybackParams
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
    val player = MediaPlayer()

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

    /** Told when the sound cannot be played at all, which is otherwise a button that does nothing. */
    var onError: ((String) -> Unit)? = null

    var rate: Float = 1f
        set(value) {
            field = value
            speed()
        }

    private val tick = object : Runnable {
        override fun run() {
            report()
            ticker.postDelayed(this, TICK)
        }
    }

    init {
        visibility = GONE

        player.setOnErrorListener { _, what, extra ->
            onError?.invoke("the sound could not be played ($what, $extra)")
            true
        }

        player.setOnPreparedListener {
            prepared = true

            if (!announced) {
                announced = true
                onReady?.invoke(JSONObject().put("duration", player.duration / 1000.0))
            }

            if (wanted) {
                player.start()
                speed()
            }
        }

        player.setOnCompletionListener {
            if (!player.isLooping) {
                onEnd?.invoke()
            }
        }

        ticker.postDelayed(tick, TICK)
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
        }.onFailure { problem ->
            onError?.invoke(problem.message ?: "the sound could not be opened")
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
            speed()
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

    /** Moves to a moment, which is a reader dragging a scrubber rather than anything the tree describes. */
    fun seek(seconds: Double) {
        if (closed || !prepared) {
            return
        }

        val bound = player.duration / 1000.0
        val wanted = seconds.coerceIn(0.0, if (bound > 0) bound else seconds)

        player.seekTo((wanted * 1000).toInt())
        report()
    }

    /**
     * Applies how fast the sound plays, which a player only takes while it is running.
     *
     * Handing a speed to one that is paused starts it, so it is applied where playing starts rather
     * than the moment the tree asks for it.
     */
    private fun speed() {
        if (closed || !prepared || !player.isPlaying) {
            return
        }

        player.playbackParams = PlaybackParams().setSpeed(rate)
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
