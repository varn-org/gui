package dev.varn.gui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.view.ViewConfiguration
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.atan
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.log2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sinh
import org.json.JSONArray
import org.json.JSONObject

/**
 * The map, drawn from the raster tiles every map on the web is served as.
 *
 * Android's own map is the Google one, which is a dependency, a key and an account before a screen can
 * show a street. The projection here is the one those tiles are cut in, which is what makes a centre
 * and a zoom mean on this screen exactly what they mean under MapKit and in a browser.
 */
class VarnMapView(context: Context) : View(context), VarnSettling, VarnReleasing {
    private var latitude = 0.0
    private var longitude = 0.0
    private var zoom = 14.0
    private var markers: List<Marker> = emptyList()
    private var interactive = true

    var onRegionChange: ((JSONObject) -> Unit)? = null
    var onMarkerPress: ((JSONObject) -> Unit)? = null
    var onPress: ((JSONObject) -> Unit)? = null

    private class Marker(val key: String, val latitude: Double, val longitude: Double, val title: String?)

    private val tiles = object : LruCache<String, Bitmap>(HELD) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount / 1024
    }

    /** Whether the tiles this was drawing have been given back, after which it asks for none. */
    var closed = false
        private set

    private val asked = mutableSetOf<String>()
    private val fetchers = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())

    private val tilePaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val pinPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#E5484D") }
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#1C1C1E") }
    private val platePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#E6FFFFFF") }
    private val creditPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#8A000000") }

    private val density = context.resources.displayMetrics.density
    private val slop = ViewConfiguration.get(context).scaledTouchSlop

    private var heldX = 0f
    private var heldY = 0f
    private var travelled = 0f
    private var pinching = false

    private val pinch = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
        override fun onScale(detector: ScaleGestureDetector): Boolean {
            pinching = true
            zoom = clamped(zoom + log2(detector.scaleFactor.toDouble()))
            invalidate()
            return true
        }
    })

    init {
        setBackgroundColor(Color.parseColor("#E8E5E0"))
        labelPaint.textSize = 11f * density
        labelPaint.isFakeBoldText = true
        creditPaint.textSize = 10f * density
    }

    fun setCenter(center: JSONObject?) {
        latitude = center?.optDouble("latitude") ?: return
        longitude = center.optDouble("longitude")
    }

    fun setZoom(value: Double) {
        zoom = clamped(value)
    }

    fun setMarkers(value: JSONArray?) {
        val read = mutableListOf<Marker>()

        for (index in 0 until (value?.length() ?: 0)) {
            val entry = value?.optJSONObject(index) ?: continue
            val key = entry.optString("key", "")

            if (key.isEmpty()) {
                continue
            }

            read += Marker(
                key,
                entry.optDouble("latitude"),
                entry.optDouble("longitude"),
                if (entry.isNull("title")) null else entry.optString("title"),
            )
        }

        markers = read
    }

    fun setInteractive(value: Boolean) {
        interactive = value
    }

    override fun settle() {
        invalidate()
    }

    override fun release() {
        if (closed) {
            return
        }

        closed = true
        fetchers.shutdownNow()
        main.removeCallbacksAndMessages(null)
        tiles.evictAll()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (width == 0 || height == 0) {
            return
        }

        drawTiles(canvas)
        drawMarkers(canvas)

        canvas.drawText(CREDIT, width - creditPaint.measureText(CREDIT) - 4 * density, height - 4 * density, creditPaint)
    }

    private fun drawTiles(canvas: Canvas) {
        val level = max(1, min(19, Math.round(zoom).toInt()))
        val span = TILE * 2.0.pow(zoom - level)
        val across = 1 shl level

        val left = projectX(longitude, zoom) - width / 2.0
        val top = projectY(latitude, zoom) - height / 2.0

        var y = floor(top / span).toInt()

        while (y <= floor((top + height) / span).toInt()) {
            var x = floor(left / span).toInt()

            while (x <= floor((left + width) / span).toInt()) {
                if (y in 0 until across) {
                    val around = ((x % across) + across) % across
                    val at = Rect(
                        (x * span - left).toInt(),
                        (y * span - top).toInt(),
                        ((x + 1) * span - left).toInt() + 1,
                        ((y + 1) * span - top).toInt() + 1,
                    )

                    tile(level, around, y)?.let { canvas.drawBitmap(it, null, at, tilePaint) }
                }

                x += 1
            }

            y += 1
        }
    }

    private fun drawMarkers(canvas: Canvas) {
        val middleX = projectX(longitude, zoom)
        val middleY = projectY(latitude, zoom)

        for (marker in markers) {
            val x = (projectX(marker.longitude, zoom) - middleX + width / 2).toFloat()
            val y = (projectY(marker.latitude, zoom) - middleY + height / 2).toFloat()

            canvas.drawCircle(x, y, 9 * density, ringPaint)
            canvas.drawCircle(x, y, 7 * density, pinPaint)

            val title = marker.title ?: continue
            val wide = labelPaint.measureText(title)
            val plate = 7 * density

            canvas.drawRoundRect(
                x - wide / 2 - 4 * density,
                y - 14 * density - plate * 2,
                x + wide / 2 + 4 * density,
                y - 14 * density,
                3 * density,
                3 * density,
                platePaint,
            )

            canvas.drawText(title, x - wide / 2, y - 17 * density, labelPaint)
        }
    }

    /** Answers a tile if it is already here, and asks for it once if it is not. */
    private fun tile(level: Int, x: Int, y: Int): Bitmap? {
        if (closed) {
            return null
        }

        val name = "$level/$x/$y"
        val held = tiles.get(name)

        if (held != null) {
            return held
        }

        if (!asked.add(name)) {
            return null
        }

        fetchers.execute {
            val drawn = fetch(name)

            main.post {
                if (closed) {
                    return@post
                }

                asked.remove(name)

                if (drawn != null) {
                    tiles.put(name, drawn)
                    invalidate()
                }
            }
        }

        return null
    }

    private fun fetch(name: String): Bitmap? {
        return runCatching {
            val connection = URL("$TILES_AT/$name.png").openConnection() as HttpURLConnection

            connection.setRequestProperty("User-Agent", AGENT)
            connection.connectTimeout = 10000
            connection.readTimeout = 10000

            connection.inputStream.use { BitmapFactory.decodeStream(it) }
        }.getOrNull()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!interactive) {
            return false
        }

        pinch.onTouchEvent(event)

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                heldX = event.x
                heldY = event.y
                travelled = 0f
                pinching = false
                parent?.requestDisallowInterceptTouchEvent(true)
            }

            MotionEvent.ACTION_MOVE -> {
                if (!pinching) {
                    panBy((heldX - event.x).toDouble(), (heldY - event.y).toDouble())
                }

                travelled += abs(event.x - heldX) + abs(event.y - heldY)
                heldX = event.x
                heldY = event.y
                invalidate()
            }

            MotionEvent.ACTION_UP -> report(event)

            MotionEvent.ACTION_CANCEL -> parent?.requestDisallowInterceptTouchEvent(false)
        }

        return true
    }

    private fun report(event: MotionEvent) {
        parent?.requestDisallowInterceptTouchEvent(false)

        if (travelled > slop || pinching) {
            onRegionChange?.invoke(
                JSONObject()
                    .put("center", JSONObject().put("latitude", latitude).put("longitude", longitude))
                    .put("zoom", zoom),
            )

            return
        }

        val marker = pressedMarker(event)

        // A press on a mark is a press on that mark, so the map is not told about it as well.
        if (marker != null) {
            onMarkerPress?.invoke(JSONObject().put("key", marker.key))
            return
        }

        val x = projectX(longitude, zoom) + event.x - width / 2
        val y = projectY(latitude, zoom) + event.y - height / 2

        onPress?.invoke(
            JSONObject()
                .put("latitude", unprojectY(y, zoom))
                .put("longitude", unprojectX(x, zoom)),
        )
    }

    /** Answers the mark a press landed on, which is the nearest one within a finger of it. */
    private fun pressedMarker(event: MotionEvent): Marker? {
        val middleX = projectX(longitude, zoom)
        val middleY = projectY(latitude, zoom)
        val reach = 22 * density

        return markers.firstOrNull { marker ->
            val x = (projectX(marker.longitude, zoom) - middleX + width / 2).toFloat()
            val y = (projectY(marker.latitude, zoom) - middleY + height / 2).toFloat()

            abs(event.x - x) <= reach && abs(event.y - y) <= reach
        }
    }

    private fun panBy(x: Double, y: Double) {
        longitude = unprojectX(projectX(longitude, zoom) + x, zoom)
        latitude = unprojectY(projectY(latitude, zoom) + y, zoom)
    }

    private fun clamped(value: Double) = min(20.0, max(1.0, value))

    private fun projectX(longitude: Double, zoom: Double) = (longitude + 180) / 360 * world(zoom)

    private fun projectY(latitude: Double, zoom: Double): Double {
        val sine = sin(latitude * Math.PI / 180)

        return (0.5 - ln((1 + sine) / (1 - sine)) / (4 * Math.PI)) * world(zoom)
    }

    private fun unprojectX(x: Double, zoom: Double) = x / world(zoom) * 360 - 180

    private fun unprojectY(y: Double, zoom: Double): Double {
        val share = 0.5 - y / world(zoom)

        return atan(sinh(2 * Math.PI * share)) * 180 / Math.PI
    }

    private fun world(zoom: Double) = TILE * 2.0.pow(zoom)

    private companion object {
        const val TILE = 256.0
        const val HELD = 24 * 1024
        const val TILES_AT = "https://tile.openstreetmap.org"
        const val CREDIT = "© OpenStreetMap"
        const val AGENT = "varn-gui"
    }
}
