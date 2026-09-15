package dev.varn.gui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.graphics.ImageFormat
import android.graphics.Rect
import android.media.ImageReader
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

/**
 * What the camera sees, with what it captures written where the tree can show it.
 *
 * The device runs only while the view is attached, so leaving a screen puts the camera down rather than
 * leaving it open behind a screen nobody is looking at. Everything the camera is told is told on a thread
 * of its own, since opening one and configuring a session both block for as long as the hardware takes.
 *
 * A look is drawn over the preview and written into a photograph, which is what makes what a reader sees
 * before they capture the picture they get. A film is recorded as the camera sees it, since the encoder
 * takes frames straight from the hardware and rewriting each one is a different feature.
 */
class VarnCameraView(context: Context) : FrameLayout(context), VarnReleasing {
    /** Told what the camera produced, which is a file the tree can show and what it turned out to be. */
    var onEvent: ((String, JSONObject) -> Unit)? = null

    /** Asked with the permission the camera needs, since only an activity may ask a reader for one. */
    var onPermission: ((String, (Boolean) -> Unit) -> Unit)? = null

    var facing: String = "back"
        set(value) {
            if (field == value) {
                return
            }

            field = value
            reopen()
        }

    var zoom: Float = 1f
        set(value) {
            field = value
            settle()
        }

    var torch: Boolean = false
        set(value) {
            field = value
            settle()
        }

    var wantsAudio: Boolean = false
        set(value) {
            if (field == value) {
                return
            }

            field = value
            reopen()
        }

    var filter: FloatArray? = null
        set(value) {
            field = value
            showFilter()
        }

    private val preview = TextureView(context)

    private val cameras = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private var thread: HandlerThread? = null
    private var work: Handler? = null

    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var request: CaptureRequest.Builder? = null
    private var stills: ImageReader? = null
    private var films: MediaRecorder? = null
    private var began: Long = 0

    private var asked = false
    private var opening = false
    private var size = Size(1280, 720)

    init {
        setBackgroundColor(0xff000000.toInt())
        addView(preview, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        preview.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
                open()
            }

            override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) = Unit

            override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
                close()
                return true
            }

            override fun onSurfaceTextureUpdated(texture: SurfaceTexture) = Unit
        }
    }

    override fun release() {
        close()
    }

    /** Asks the reader for what it needs, and opens the camera once they have answered. */
    private fun open() {
        if (opening || device != null || !preview.isAvailable) {
            return
        }

        opening = true

        allowed(Manifest.permission.CAMERA) { granted ->
            if (!granted) {
                opening = false
                report("onError", JSONObject().put("message", "the camera was refused"))
                return@allowed
            }

            if (!wantsAudio) {
                start()
                return@allowed
            }

            allowed(Manifest.permission.RECORD_AUDIO) { allowedSound ->
                if (!allowedSound) {
                    report("onError", JSONObject().put("message", "the microphone was refused"))
                }

                start()
            }
        }
    }

    /** Asks for a permission once, answering straight away when the reader has already allowed it. */
    private fun allowed(permission: String, then: (Boolean) -> Unit) {
        if (context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            then(true)
            return
        }

        val ask = onPermission

        if (ask == null) {
            then(false)
            return
        }

        ask(permission) { granted -> then(granted) }
    }

    private fun start() {
        val id = cameraId()

        if (id == null) {
            opening = false
            report("onError", JSONObject().put("message", "there is no camera to open"))
            return
        }

        val loop = HandlerThread("varn-camera").also { it.start() }

        thread = loop
        work = Handler(loop.looper)
        size = previewSize(id)
        asked = true

        try {
            cameras.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(opened: CameraDevice) {
                    device = opened
                    opening = false
                    configure()
                }

                override fun onDisconnected(opened: CameraDevice) {
                    opened.close()
                    device = null
                    opening = false
                }

                override fun onError(opened: CameraDevice, problem: Int) {
                    opened.close()
                    device = null
                    opening = false
                    post { report("onError", JSONObject().put("message", "the camera could not be opened")) }
                }
            }, work)
        } catch (problem: CameraAccessException) {
            opening = false
            report("onError", JSONObject().put("message", problem.message ?: "the camera could not be opened"))
        } catch (problem: SecurityException) {
            opening = false
            report("onError", JSONObject().put("message", "the camera was refused"))
        }
    }

    /** Answers the camera facing the way the tree asked for, or whichever one there is. */
    private fun cameraId(): String? {
        val wanted =
            if (facing == "front") CameraCharacteristics.LENS_FACING_FRONT
            else CameraCharacteristics.LENS_FACING_BACK

        val ids = try {
            cameras.cameraIdList
        } catch (problem: CameraAccessException) {
            return null
        }

        for (id in ids) {
            val about = cameras.getCameraCharacteristics(id)

            if (about.get(CameraCharacteristics.LENS_FACING) == wanted) {
                return id
            }
        }

        return ids.firstOrNull()
    }

    /** Answers the size the preview runs at, which is the largest one that is not more than the screen. */
    private fun previewSize(id: String): Size {
        val about = cameras.getCameraCharacteristics(id)
        val map = about.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP) ?: return Size(1280, 720)
        val offered = map.getOutputSizes(SurfaceTexture::class.java) ?: return Size(1280, 720)

        return offered.filter { it.width <= 1920 && it.height <= 1080 }
            .maxByOrNull { it.width.toLong() * it.height } ?: offered.first()
    }

    /** Builds the session the preview and the stills are drawn from, replacing whichever one is running. */
    private fun configure() {
        val opened = device ?: return
        val texture = preview.surfaceTexture ?: return

        texture.setDefaultBufferSize(size.width, size.height)

        val screen = Surface(texture)
        val reader = ImageReader.newInstance(size.width, size.height, ImageFormat.JPEG, 2)

        stills?.close()
        stills = reader

        reader.setOnImageAvailableListener({ from ->
            val image = from.acquireLatestImage() ?: return@setOnImageAvailableListener
            val buffer = image.planes[0].buffer
            val bytes = ByteArray(buffer.remaining())

            buffer.get(bytes)
            image.close()

            post { wrote(bytes) }
        }, work)

        val surfaces = mutableListOf(screen, reader.surface)
        val recorder = films?.surface

        if (recorder != null) {
            surfaces.add(recorder)
        }

        val built = opened.createCaptureRequest(
            if (recorder != null) CameraDevice.TEMPLATE_RECORD else CameraDevice.TEMPLATE_PREVIEW,
        )

        built.addTarget(screen)

        if (recorder != null) {
            built.addTarget(recorder)
        }

        request = built

        @Suppress("DEPRECATION")
        opened.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(made: CameraCaptureSession) {
                session = made
                applyRequest()
                post {
                    showFilter()
                    report("onReady", JSONObject().put("facing", facing))
                }
            }

            override fun onConfigureFailed(made: CameraCaptureSession) {
                post { report("onError", JSONObject().put("message", "the camera session could not be built")) }
            }
        }, work)
    }

    /** Puts the camera down, which is what leaving a screen has to do with a device the system lends. */
    private fun close() {
        films?.let { recorder ->
            runCatching { recorder.stop() }
            recorder.release()
        }

        films = null

        session?.close()
        session = null

        device?.close()
        device = null

        stills?.close()
        stills = null

        thread?.quitSafely()
        thread = null
        work = null

        opening = false
    }

    /** Turns the camera round, which is a different device rather than a different setting on this one. */
    private fun reopen() {
        if (!asked) {
            return
        }

        close()
        open()
    }

    /** Applies how far in the camera is and whether its light is on, which the request carries. */
    private fun settle() {
        val built = request ?: return
        val opened = device ?: return

        val about = cameras.getCameraCharacteristics(opened.id)
        val most = about.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM) ?: 1f
        val whole = about.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)

        val held = min(max(1f, zoom), most)

        if (whole != null) {
            val width = (whole.width() / held).toInt()
            val height = (whole.height() / held).toInt()
            val left = (whole.width() - width) / 2
            val top = (whole.height() - height) / 2

            built.set(CaptureRequest.SCALER_CROP_REGION, Rect(left, top, left + width, top + height))
        }

        val lit = about.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true

        if (lit) {
            built.set(
                CaptureRequest.FLASH_MODE,
                if (torch) CameraMetadata.FLASH_MODE_TORCH else CameraMetadata.FLASH_MODE_OFF,
            )
        }

        applyRequest()
    }

    private fun applyRequest() {
        val made = session ?: return
        val built = request ?: return

        runCatching { made.setRepeatingRequest(built.build(), null, work) }
    }

    /** Draws the preview through the look the tree asked for, which a layer of its own is what applies. */
    private fun showFilter() {
        val matrix = filter

        if (matrix == null || matrix.size != 20) {
            preview.setLayerType(View.LAYER_TYPE_NONE, null)
            return
        }

        val paint = Paint()
        paint.colorFilter = ColorMatrixColorFilter(ColorMatrix(matrix))

        preview.setLayerType(View.LAYER_TYPE_HARDWARE, paint)
    }

    fun capturePhoto() {
        val made = session ?: return
        val opened = device ?: return
        val reader = stills ?: return

        val built = opened.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
        built.addTarget(reader.surface)

        request?.get(CaptureRequest.SCALER_CROP_REGION)?.let {
            built.set(CaptureRequest.SCALER_CROP_REGION, it)
        }

        runCatching { made.capture(built.build(), null, work) }
    }

    /** Writes what the hardware produced, drawn through the look the reader was looking at. */
    private fun wrote(bytes: ByteArray) {
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)

        if (decoded == null) {
            report("onError", JSONObject().put("message", "the picture could not be read"))
            return
        }

        val drawn = painted(decoded)
        val file = somewhere("photo", "jpg")

        runCatching {
            file.outputStream().use { out -> drawn.compress(Bitmap.CompressFormat.JPEG, 90, out) }
        }.onFailure { problem ->
            report("onError", JSONObject().put("message", problem.message ?: "the picture could not be written"))
            return
        }

        report(
            "onCapture",
            JSONObject()
                .put("path", file.absolutePath)
                .put("width", drawn.width)
                .put("height", drawn.height),
        )
    }

    /** Answers the picture drawn through the look, which is what makes a capture carry what was seen. */
    private fun painted(source: Bitmap): Bitmap {
        val matrix = filter

        if (matrix == null || matrix.size != 20) {
            return source
        }

        val drawn = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        val paint = Paint()

        paint.colorFilter = ColorMatrixColorFilter(ColorMatrix(matrix))
        Canvas(drawn).drawBitmap(source, 0f, 0f, paint)

        return drawn
    }

    fun startRecording() {
        if (films != null || device == null) {
            return
        }

        val file = somewhere("film", "mp4")
        val recorder = VarnCameraView.recorder(context)

        runCatching {
            if (wantsAudio) {
                recorder.setAudioSource(MediaRecorder.AudioSource.CAMCORDER)
            }

            recorder.setVideoSource(MediaRecorder.VideoSource.SURFACE)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setOutputFile(file.absolutePath)
            recorder.setVideoEncodingBitRate(6_000_000)
            recorder.setVideoFrameRate(30)
            recorder.setVideoSize(size.width, size.height)
            recorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264)

            if (wantsAudio) {
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            }

            recorder.prepare()
        }.onFailure { problem ->
            recorder.release()
            report("onError", JSONObject().put("message", problem.message ?: "the film could not be started"))
            return
        }

        films = recorder
        recording = file
        began = System.currentTimeMillis()

        // The encoder takes its frames from a surface the session has to carry, so the session is built
        // again with it rather than a recording being started on the one already running.
        session?.close()
        session = null
        configure()

        recorder.start()
    }

    private var recording: File? = null

    fun stopRecording() {
        val recorder = films ?: return
        val file = recording

        films = null
        recording = null

        runCatching { recorder.stop() }
        recorder.release()

        session?.close()
        session = null
        configure()

        if (file == null) {
            return
        }

        report(
            "onRecord",
            JSONObject()
                .put("path", file.absolutePath)
                .put("duration", (System.currentTimeMillis() - began) / 1000.0),
        )
    }

    private fun report(name: String, payload: JSONObject) {
        post { onEvent?.invoke(name, payload) }
    }

    companion object {
        /** Answers where a capture is written, which is a file of the application's own. */
        fun somewhere(context: Context, name: String, ending: String): File {
            return File(context.cacheDir, "varn-$name-${UUID.randomUUID()}.$ending")
        }

        /**
         * Answers a recorder, which from Android 12 is built against the context that owns it.
         *
         * The context is what an attribution is drawn from, so the system can say which part of an
         * application is holding the microphone rather than only that something is.
         */
        fun recorder(context: Context): MediaRecorder {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                return MediaRecorder(context)
            }

            @Suppress("DEPRECATION")
            return MediaRecorder()
        }

        /** Answers the colour matrix a filter arrived as, or nothing when it carries none. */
        fun matrix(value: JSONArray?): FloatArray? {
            if (value == null || value.length() != 20) {
                return null
            }

            return FloatArray(20) {
                val number = value.optDouble(it, 0.0)

                if (it % 5 == 4) (number * 255).toFloat() else number.toFloat()
            }
        }
    }

    private fun somewhere(name: String, ending: String): File = somewhere(context, name, ending)
}

/**
 * A microphone with nothing to draw, which is what a voice note is made of.
 *
 * It is told whether it should be running rather than asked to start, since that is what the tree holds:
 * a state that says recording, and a file that arrives when it stops.
 */
class VarnRecorderView(context: Context) : View(context), VarnReleasing {
    var onEvent: ((String, JSONObject) -> Unit)? = null
    var onPermission: ((String, (Boolean) -> Unit) -> Unit)? = null

    var recording: Boolean = false
        set(value) {
            if (field == value) {
                return
            }

            field = value

            if (value) {
                start()
                return
            }

            finish()
        }

    private var recorder: MediaRecorder? = null
    private var file: File? = null
    private var began: Long = 0

    override fun release() {
        recorder?.let { made ->
            runCatching { made.stop() }
            made.release()
        }

        recorder = null
        file = null
    }

    private fun start() {
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            listen()
            return
        }

        val ask = onPermission

        if (ask == null) {
            recording = false
            onEvent?.invoke("onError", JSONObject().put("message", "this application cannot ask to record"))
            return
        }

        ask(Manifest.permission.RECORD_AUDIO) { granted ->
            if (!granted) {
                recording = false
                onEvent?.invoke("onError", JSONObject().put("message", "the microphone was refused"))
                return@ask
            }

            listen()
        }
    }

    private fun listen() {
        val written = VarnCameraView.somewhere(context, "note", "m4a")
        val made = VarnCameraView.recorder(context)

        runCatching {
            made.setAudioSource(MediaRecorder.AudioSource.MIC)
            made.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            made.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            made.setOutputFile(written.absolutePath)
            made.prepare()
            made.start()
        }.onFailure { problem ->
            made.release()
            recording = false
            onEvent?.invoke("onError", JSONObject().put("message", problem.message ?: "the microphone would not open"))
            return
        }

        recorder = made
        file = written
        began = System.currentTimeMillis()

        onEvent?.invoke("onReady", JSONObject())
    }

    private fun finish() {
        val made = recorder ?: return
        val written = file

        recorder = null
        file = null

        runCatching { made.stop() }
        made.release()

        if (written == null) {
            return
        }

        onEvent?.invoke(
            "onFinish",
            JSONObject()
                .put("path", written.absolutePath)
                .put("duration", (System.currentTimeMillis() - began) / 1000.0),
        )
    }
}
