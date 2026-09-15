package dev.varn.gui

import android.annotation.SuppressLint
import android.app.AlertDialog
import android.content.Context
import android.text.Editable
import android.text.TextWatcher
import android.graphics.Color
import android.graphics.Paint
import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.TextureView
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Rect
import android.media.MediaPlayer
import android.view.MotionEvent
import android.view.TouchDelegate
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.*
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Builds the Android view that stands for one node type. */
object VarnViewFactory {
    fun make(context: Context, type: String): View = when (type) {
        "text", "richtext", "badge", "tooltip" -> TextView(context)
        "image" -> VarnPictureView(context)
        // A button carries no look of its own, since the style a commit carries is what paints it.
        "button" -> Button(context).apply {
            isAllCaps = false
            minWidth = 0
            minHeight = 0
            background = null
            stateListAnimator = null
            setPadding(0, 0, 0, 0)
        }
        "textinput", "searchbar" -> VarnTextField(context)
        "textarea" -> VarnTextField(context).apply { isSingleLine = false; minLines = 3 }
        "richeditor" -> VarnRichEditor(context)
        // One scrolling surface serves every scrolling type, since the engine sends all of them the same thing.
        "scroll", "list", "sectionlist", "grid", "carousel" -> VarnCollectionView(context)
        "switch" -> Switch(context)
        "checkbox" -> CheckBox(context)
        "radio" -> RadioButton(context)
        "slider" -> VarnSliderView(context)
        "progress" -> ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal)
        "activity" -> ProgressBar(context)
        "picker" -> VarnPickerView(context)
        "datepicker" -> DatePicker(context)
        "timepicker" -> TimePicker(context)
        "rating" -> RatingBar(context)
        "segmented" -> VarnSegmentedView(context)
        // A radio group holds the radios the engine placed, so it is a box rather than a linear layout.
        "stepper" -> VarnStepperView(context)
        "filepicker" -> VarnFilePicker(context)
        "colorpicker" -> VarnColorView(context)
        "webview" -> VarnWebView(context)
        "video" -> VarnVideoView(context)
        "camera" -> VarnCameraView(context)
        "recorder" -> VarnRecorderView(context)
        "audio" -> VarnAudioView(context)
        "canvas" -> VarnCanvasView(context)
        "gradient" -> VarnGradientView(context)
        "nineslice" -> VarnNineSliceView(context)
        "blur" -> VarnBlurView(context)
        "map" -> VarnMapView(context)
        "location" -> VarnLocationView(context)
        "divider" -> View(context)

        // A box is what the rest are: the engine positions them and their style paints them.
        else -> VarnBoxView(context)
    }

    /** Answers the view children are added to, which for a scrolling view is not the view itself. */
    fun contentView(view: View): ViewGroup {
        if (view is VarnCollectionView) {
            return view.content
        }

        return view as ViewGroup
    }
}

/**
 * How far a finger has gone since it landed, which is what a swipe is and a press is not.
 *
 * The distance is measured against the screen rather than against the view, since a view inside a list
 * moves under a finger that has not moved at all. It is the distance a page is dragged by rather than
 * the one a touch wanders by, because a finger on a phone is never still and a press held to that
 * shorter one is a control a reader has to press three times to be heard once.
 */
class VarnPressTravel(context: Context) {
    private val slop = ViewConfiguration.get(context).scaledPagingTouchSlop
    private var at: Pair<Float, Float>? = null

    val landed: Boolean
        get() = at != null

    fun began(event: MotionEvent) {
        at = event.rawX to event.rawY
    }

    fun ended() {
        at = null
    }

    fun swept(event: MotionEvent): Boolean {
        val landed = at ?: return false

        return abs(event.rawX - landed.first) > slop || abs(event.rawY - landed.second) > slop
    }

    fun directionOf(event: MotionEvent): String {
        val landed = at ?: return "right"
        val across = event.rawX - landed.first
        val down = event.rawY - landed.second

        if (abs(across) >= abs(down)) {
            return if (across < 0) "left" else "right"
        }

        return if (down < 0) "up" else "down"
    }
}

/**
 * A field that remembers what it has told the tree since it was last written to.
 *
 * A tree answers a keystroke with the value it has just been told, and by the time that lands the
 * reader has typed two more: writing it back puts the field where it was and everything typed since is
 * gone. What the field itself said is not news, and anything it never said is a real change.
 */
class VarnTextField(context: Context) : EditText(context) {
    private val said = LinkedHashSet<String>()

    /** Says where the caret is, which a browser and the two phones each report at a different moment. */
    var onSelection: ((JSONObject) -> Unit)? = null

    override fun onSelectionChanged(start: Int, end: Int) {
        super.onSelectionChanged(start, end)

        onSelection?.invoke(
            JSONObject().put("start", start).put("end", end).put("marks", JSONObject()),
        )
    }

    /**
     * Told what was typed, by the one watcher this field ever has.
     *
     * A watcher is added rather than set, so binding the handler again — which a prop that comes and
     * goes does — left the field reporting every keystroke once per binding.
     */
    var onTyped: ((String) -> Unit)? = null

    init {
        // A field carries a look of its own from the platform, and the style is what decides it instead.
        //
        // An application draws a search pill and puts an editable run inside it, and the run arrives
        // with the platform's own underline, ground and padding, so the pill has a second box sitting in
        // it. What the platform owns is the caret, the selection and the keyboard, and the box around
        // them belongs to whoever wrote the screen. Setting the background clears the padding with it,
        // so the padding is written back afterwards rather than left to whatever the drawable had.
        background = null
        setPadding(0, 0, 0, 0)

        addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(text: Editable) {
                reported(text.toString())
                onTyped?.invoke(text.toString())
            }

            override fun beforeTextChanged(text: CharSequence, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(text: CharSequence, start: Int, before: Int, count: Int) = Unit
        })
    }

    fun reported(text: String) {
        said += text

        while (said.size > SAID) {
            said.remove(said.first())
        }
    }

    fun echoed(text: String) = said.contains(text)

    fun written() {
        said.clear()
    }

    private companion object {
        const val SAID = 64
    }
}

/**
 * The plain box everything else is built from.
 *
 * The engine sends finished frames, so this never measures or arranges anything: a child is placed
 * exactly where it was told to go.
 */
/**
 * A page drawn by the platform's own browser, which reports both ends of every load.
 *
 * A page takes as long as a page takes, so a screen drawing a spinner over one has to be told when it
 * started and when it finished, and told rather than left waiting when it cannot be loaded at all.
 */
class VarnWebView(context: Context) : WebView(context) {
    var onWillLoad: ((String) -> Unit)? = null
    var onLoad: ((String) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    init {
        webViewClient = object : android.webkit.WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                onWillLoad?.invoke(url ?: "")
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                onLoad?.invoke(url ?: "")
            }

            override fun onReceivedError(
                view: WebView?,
                request: android.webkit.WebResourceRequest?,
                error: android.webkit.WebResourceError?,
            ) {
                if (request?.isForMainFrame == true) {
                    onError?.invoke(error?.description?.toString() ?: "the page could not be loaded")
                }
            }
        }
    }
}

/**
 * A picture, drawn from what it was loaded with rather than from what was last written over it.
 *
 * A tint and a filter both ask for the one colour filter a view has, and the props of one batch arrive in
 * no order at all, so writing one and then the other lost whichever came first. Each is kept apart and
 * what draws the picture is worked out from both: a tint replaces the colours of a picture outright, so a
 * picture that carries one is drawn in it and a filter has nothing left to change.
 */
class VarnPictureView(context: Context) : ImageView(context) {
    var tint: Int? = null
        set(value) {
            field = value
            redraw()
        }

    var filter: FloatArray? = null
        set(value) {
            field = value
            redraw()
        }

    private fun redraw() {
        val colour = tint

        if (colour != null) {
            setColorFilter(colour)
            return
        }

        val matrix = filter

        if (matrix == null) {
            clearColorFilter()
            return
        }

        colorFilter = ColorMatrixColorFilter(ColorMatrix(matrix))
    }
}

open class VarnBoxView(context: Context) : ViewGroup(context) {
    /**
     * The range the surface holds this box against its leading edge over, which a header is given.
     *
     * A header placed from the tree follows a finger a commit late, which is a header drifting over the
     * rows it is meant to cover. The range is what the tree knows and the offset is what the surface
     * knows, so each says the part it has.
     */
    var pinned: Pair<Float, Float>? = null

    /**
     * Where the last touch landed, which is what a menu raised by a long press is drawn at.
     *
     * A long click carries no position on this platform, so the one the touch before it landed at is
     * what a menu has to be drawn from — the corner of the box is not where the finger was.
     */
    var touchedAt = Pair(0f, 0f)
        private set

    /**
     * Which axis this box claims a drag along, and what it reports while one is happening.
     *
     * A scrolling parent takes a touch the moment it decides the finger is a scroll, so a box that wants
     * the drag has to say so before that: once the finger has gone further than the platform's own
     * threshold along the claimed axis, the parents are told to stop intercepting.
     */
    var panAxis: String? = null
    var onPan: ((String, Float, Float, Float, Float) -> Unit)? = null

    private var panFrom: Pair<Float, Float>? = null
    private var panning = false
    private val panSlop = ViewConfiguration.get(context).scaledTouchSlop

    private fun pan(event: MotionEvent): Boolean {
        val report = onPan ?: return false

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                panFrom = Pair(event.x, event.y)
                panning = false
            }

            MotionEvent.ACTION_MOVE -> {
                val from = panFrom ?: return false
                val dx = event.x - from.first
                val dy = event.y - from.second

                if (!panning) {
                    val along = when (panAxis) {
                        "horizontal" -> abs(dx)
                        "vertical" -> abs(dy)
                        else -> max(abs(dx), abs(dy))
                    }

                    if (along < panSlop) {
                        return false
                    }

                    panning = true
                    parent?.requestDisallowInterceptTouchEvent(true)
                    report("onPanStart", from.first, from.second, 0f, 0f)
                }

                report("onPanMove", event.x, event.y, dx, dy)
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val from = panFrom ?: return false

                panFrom = null

                if (!panning) {
                    return false
                }

                panning = false
                parent?.requestDisallowInterceptTouchEvent(false)
                report("onPanEnd", event.x, event.y, event.x - from.first, event.y - from.second)
                return true
            }
        }

        return false
    }

    /** Answers where it sits for an offset, which is against the edge until its range runs out. */
    fun held(offset: Float, extent: Int): Float {
        val range = pinned ?: return offset

        return min(max(offset, range.first), max(range.first, range.second - extent))
    }

    /** How far outside its own box this one answers a finger, which is what a small control needs. */
    var slop: Int = 0
        set(value) {
            field = value
            (parent as? VarnBoxView)?.refreshSlop()
        }

    /** Told when a finger lands on this box and when it leaves, which a press reports both edges of. */
    var onPressIn: (() -> Unit)? = null
    var onPressOut: (() -> Unit)? = null

    /** Told the way a finger went when it went far enough to be a swipe rather than a press. */
    var onSwipe: ((String) -> Unit)? = null

    /**
     * Told when a finger landed twice in the time the platform counts as one gesture.
     *
     * The platform's own detector is what answers this, since how long two taps may be apart and how
     * far they may be from each other are the platform's rather than a number chosen here.
     */
    var onDoublePress: ((Unit) -> Unit)? = null
        set(value) {
            field = value
            twice = if (value == null) null else android.view.GestureDetector(
                context,
                object : android.view.GestureDetector.SimpleOnGestureListener() {
                    override fun onDoubleTap(event: MotionEvent): Boolean {
                        onDoublePress?.invoke(Unit)
                        return true
                    }
                },
            )
        }

    private var twice: android.view.GestureDetector? = null

    /**
     * Whether a finger passes through this box and everything inside it.
     *
     * Refusing to dispatch is what makes it pass through: the platform carries on to the next sibling,
     * which is what the other two renderers do for the same prop. Disabling the box alone left every
     * control inside it answering a finger that should never have reached it.
     */
    var passesThrough = false

    private var reaching: VarnSlopDelegate? = null
    private val travel = VarnPressTravel(context)
    private var swept: String? = null

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (passesThrough) {
            return false
        }

        return super.dispatchTouchEvent(event)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            touchedAt = Pair(event.x, event.y)
        }

        if (pan(event)) {
            return true
        }

        // A box nothing is listening to answers a finger the way any other box does, which is not at all.
        if (!isClickable) {
            return super.onTouchEvent(event)
        }

        twice?.onTouchEvent(event)

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                travel.began(event)
                alpha = 0.55f
                onPressIn?.invoke()
            }

            // A swipe across a row is the row being swiped rather than pressed, and nothing else takes
            // a press away: a view gives one up when the touch leaves its bounds, and the surface takes
            // the whole gesture when it turns into a scroll.
            MotionEvent.ACTION_MOVE -> {
                if (onSwipe != null && travel.swept(event)) {
                    swept = travel.directionOf(event)
                    release()

                    val cancelled = MotionEvent.obtain(event)
                    cancelled.action = MotionEvent.ACTION_CANCEL
                    super.onTouchEvent(cancelled)
                    cancelled.recycle()

                    return false
                }
            }

            MotionEvent.ACTION_UP -> {
                release()

                swept?.let { onSwipe?.invoke(it) }
                swept = null
            }

            MotionEvent.ACTION_CANCEL -> {
                release()
                swept = null
            }
        }

        return super.onTouchEvent(event)
    }

    /** Ends the press once, wherever it ended, so a finger is never reported as having left twice. */
    private fun release() {
        if (!travel.landed) {
            return
        }

        travel.ended()
        animate().alpha(1f).setDuration(220).start()
        onPressOut?.invoke()
    }

    /** Answers the way a finger went, which is whichever axis it went furthest along. */
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        for (index in 0 until childCount) {
            val child = getChildAt(index)
            val params = child.layoutParams

            child.layout(child.left, child.top, child.left + params.width, child.top + params.height)
        }

        refreshSlop()
    }

    /**
     * Tells this box which of its children answer a finger from outside their own bounds.
     *
     * A view only ever receives a touch inside itself, and the platform's answer to that is a delegate
     * on the view above it. A view holds one delegate, so one holds every child that asked for slop.
     */
    private fun refreshSlop() {
        val reaches = (0 until childCount)
            .map { getChildAt(it) }
            .filterIsInstance<VarnBoxView>()
            .filter { it.slop > 0 }

        if (reaches.isEmpty()) {
            if (reaching != null) {
                touchDelegate = null
                reaching = null
            }

            return
        }

        val delegate = reaching ?: VarnSlopDelegate(this).also {
            reaching = it
            touchDelegate = it
        }

        delegate.hold(reaches)
    }

    override fun onMeasure(widthSpec: Int, heightSpec: Int) {
        setMeasuredDimension(
            MeasureSpec.getSize(widthSpec),
            MeasureSpec.getSize(heightSpec),
        )

        for (index in 0 until childCount) {
            val child = getChildAt(index)
            val params = child.layoutParams

            child.measure(
                MeasureSpec.makeMeasureSpec(params.width, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(params.height, MeasureSpec.EXACTLY),
            )
        }
    }
}

/**
 * A swatch showing the colour that was chosen, which opens the three sliders that choose another.
 *
 * Android ships no colour picker of its own, so this is the whole of one: a box in the current colour
 * and a dialog behind it. What it answers is the eight hex digits every renderer reads a colour as, so
 * the three platforms report the same thing for the same gesture.
 */
class VarnColorView(context: Context) : View(context) {
    var onChoose: ((String) -> Unit)? = null

    var color: Int = Color.BLACK
        set(value) {
            field = value
            setBackgroundColor(value)
        }

    init {
        setBackgroundColor(color)
        isClickable = true
        setOnClickListener { open() }
    }

    private fun open() {
        val holder = LinearLayout(context)
        holder.orientation = LinearLayout.VERTICAL
        holder.setPadding(48, 32, 48, 8)

        val parts = intArrayOf(Color.red(color), Color.green(color), Color.blue(color))
        val bars = List(parts.size) { at ->
            SeekBar(context).apply {
                max = 255
                progress = parts[at]
                holder.addView(this)
            }
        }

        AlertDialog.Builder(context)
            .setTitle("Colour")
            .setView(holder)
            .setNegativeButton(android.R.string.cancel, null)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                color = Color.rgb(bars[0].progress, bars[1].progress, bars[2].progress)
                onChoose?.invoke(String.format("#%06xff", color and 0xffffff))
            }
            .show()
    }
}

/**
 * Hands a box the touches that land just outside the children that asked to answer them.
 *
 * The platform's own delegate carries one view, and a box holds many, so this stands in for all of
 * them. Only a touch outside a child's own bounds is claimed, since one inside already reaches it.
 */
class VarnSlopDelegate(private val host: VarnBoxView) : TouchDelegate(Rect(), host) {
    private var reaches: List<VarnBoxView> = emptyList()
    private var receiving: View? = null

    fun hold(views: List<VarnBoxView>) {
        reaches = views
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val x = event.x.toInt()
        val y = event.y.toInt()

        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            receiving = reaching(x, y)
        }

        val target = receiving ?: return false

        if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) {
            receiving = null
        }

        val moved = MotionEvent.obtain(event)
        moved.setLocation((x - target.left).toFloat(), (y - target.top).toFloat())

        val handled = target.dispatchTouchEvent(moved)
        moved.recycle()

        return handled
    }

    private fun reaching(x: Int, y: Int): View? = reaches.firstOrNull {
        it.visibility == View.VISIBLE
            && !Rect(it.left, it.top, it.right, it.bottom).contains(x, y)
            && Rect(it.left - it.slop, it.top - it.slop, it.right + it.slop, it.bottom + it.slop).contains(x, y)
    }
}

/**
 * Plays what it was given, holding what it was told until the player is ready to be told it.
 *
 * A player answers none of this before it is prepared, and it reports being prepared to one listener, so
 * every one of these setting its own left whichever arrived last replacing the rest.
 *
 * It draws into a texture rather than into a surface of its own, which is what lets a look reach it: a
 * surface is composited past the view hierarchy, so nothing drawn by the tree can colour it, and a video
 * in black and white on the other two platforms came out untouched here. The platform's own controls are
 * kept by answering what the controller asks of whatever it is attached to.
 */
class VarnVideoView(context: Context) : FrameLayout(context), VarnReleasing, MediaController.MediaPlayerControl {
    var muted: Boolean = false
        set(value) { field = value; settle() }

    var volume: Float = 1f
        set(value) { field = value; settle() }

    var looping: Boolean = false
        set(value) { field = value; settle() }

    var rate: Float = 1f
        set(value) { field = value; settle() }

    var resizeMode: String = "contain"
        set(value) { field = value; shape() }

    var filter: FloatArray? = null
        set(value) {
            field = value
            paint()
        }

    var onEnd: (() -> Unit)? = null

    /** Told when what it was given cannot be played at all, which is otherwise a black box. */
    var onError: ((String) -> Unit)? = null

    private val screen = TextureView(context)
    private var player: MediaPlayer? = null
    private var source: android.net.Uri? = null
    private var prepared = false
    private var wanted = false
    private var controller: MediaController? = null

    init {
        addView(screen, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        screen.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
                open()
            }

            override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) {
                shape()
            }

            override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
                release()
                return true
            }

            override fun onSurfaceTextureUpdated(texture: SurfaceTexture) = Unit
        }
    }

    fun setVideoURI(uri: android.net.Uri) {
        source = uri
        release()
        open()
    }

    /** Shows the still a video stands behind until it has something of its own to draw. */
    fun showPoster(path: String?) {
        background = path?.let { android.graphics.drawable.Drawable.createFromPath(it) }
    }

    /** Draws the platform's own controls over the video, or takes them away. */
    fun showControls(showing: Boolean) {
        if (!showing) {
            controller?.hide()
            controller = null
            return
        }

        val built = MediaController(context)

        built.setAnchorView(this)
        built.setMediaPlayer(this)
        built.isEnabled = true

        controller = built
    }

    override fun start() {
        wanted = true

        if (prepared) {
            player?.start()
            settle()
        }
    }

    override fun pause() {
        wanted = false
        player?.pause()
    }

    override fun release() {
        player?.release()
        player = null
        prepared = false
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        controller?.show()
        return controller != null
    }

    private fun open() {
        val uri = source ?: return
        val texture = screen.surfaceTexture ?: return

        if (player != null) {
            return
        }

        val built = MediaPlayer()

        built.setSurface(Surface(texture))
        built.setOnPreparedListener {
            prepared = true
            settle()
            shape()

            if (wanted) {
                built.start()
            }
        }

        built.setOnCompletionListener { onEnd?.invoke() }
        built.setOnErrorListener { _, what, extra ->
            onError?.invoke("the film could not be played ($what, $extra)")
            true
        }

        runCatching {
            built.setDataSource(context, uri)
            built.prepareAsync()
        }.onFailure { problem ->
            built.release()
            onError?.invoke(problem.message ?: "the film could not be opened")
            return
        }

        player = built
    }

    private fun settle() {
        val ready = player ?: return
        val level = if (muted) 0f else volume

        ready.setVolume(level, level)
        ready.isLooping = looping

        if (rate > 0f && ready.isPlaying) {
            ready.playbackParams = ready.playbackParams.setSpeed(rate)
        }
    }

    /** Fits what the player produced into the box the engine gave it, the way each mode says. */
    private fun shape() {
        val ready = player ?: return
        val wide = ready.videoWidth.toFloat()
        val tall = ready.videoHeight.toFloat()

        if (wide <= 0f || tall <= 0f || width <= 0 || height <= 0) {
            return
        }

        val across = width / wide
        val down = height / tall
        val scale = if (resizeMode == "cover") max(across, down) else min(across, down)

        val matrix = android.graphics.Matrix()

        matrix.setScale(wide * scale / width, tall * scale / height, width / 2f, height / 2f)
        screen.setTransform(matrix)
    }

    private fun paint() {
        val matrix = filter

        if (matrix == null || matrix.size != 20) {
            screen.setLayerType(View.LAYER_TYPE_NONE, null)
            return
        }

        val paint = Paint()
        paint.colorFilter = ColorMatrixColorFilter(ColorMatrix(matrix))

        screen.setLayerType(View.LAYER_TYPE_HARDWARE, paint)
    }

    override fun getDuration(): Int = if (prepared) player?.duration ?: 0 else 0

    override fun getCurrentPosition(): Int = if (prepared) player?.currentPosition ?: 0 else 0

    override fun seekTo(position: Int) {
        if (prepared) {
            player?.seekTo(position)
        }
    }

    override fun isPlaying(): Boolean = prepared && player?.isPlaying == true

    override fun getBufferPercentage(): Int = 0

    override fun canPause(): Boolean = true

    override fun canSeekBackward(): Boolean = true

    override fun canSeekForward(): Boolean = true

    override fun getAudioSessionId(): Int = player?.audioSessionId ?: 0
}

/**
 * A value with a button either side of it, which is what Android has in place of a stepper.
 *
 * The engine sizes it, so the three parts simply share the width it was given.
 */
class VarnStepperView(context: Context) : VarnBoxView(context), VarnSettling {
    private val less = Button(context).apply { text = "\u2212" }
    private val more = Button(context).apply { text = "+" }
    private val readout = TextView(context).apply { gravity = android.view.Gravity.CENTER }

    var value: Double = 0.0
        private set

    var step: Double = 1.0
    var minimum: Double = Double.NEGATIVE_INFINITY
    var maximum: Double = Double.POSITIVE_INFINITY
    var onValueChange: ((Double) -> Unit)? = null

    init {
        addView(less)
        addView(readout)
        addView(more)

        less.setOnClickListener { move(-step) }
        more.setOnClickListener { move(step) }
        show()
    }

    fun setValue(next: Double) {
        value = next
        show()
    }

    /**
     * Holds the value to the bounds once the whole batch is in.
     *
     * How far it may go and what it is worth are three props of one batch, which arrive in no order, so
     * a value clamped as it arrives is clamped against whichever bound was applied before it.
     */
    override fun settle() {
        value = value.coerceIn(minOf(minimum, maximum), maxOf(minimum, maximum))
        show()
    }

    private fun move(by: Double) {
        value = (value + by).coerceIn(minOf(minimum, maximum), maxOf(minimum, maximum))
        show()
        onValueChange?.invoke(value)
    }

    private fun show() {
        readout.text = if (value == value.toLong().toDouble()) value.toLong().toString() else value.toString()
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val height = bottom - top
        val side = minOf(height, (right - left) / 3)

        less.layout(0, 0, side, height)
        readout.layout(side, 0, right - left - side, height)
        more.layout(right - left - side, 0, right - left, height)
    }
}

/**
 * A row of segments that reports a choice once, and reports nothing for a choice written into it.
 *
 * A RadioGroup checked programmatically runs its listener down two paths and reports twice, and the
 * tree writing back the segment a handler just chose would come round again as a second choice.
 */
class VarnSegmentedView(context: Context) : RadioGroup(context) {
    private var written = 0

    var onChoose: ((Int) -> Unit)? = null

    init {
        orientation = HORIZONTAL

        setOnCheckedChangeListener { group, checked ->
            val at = group.indexOfChild(group.findViewById(checked)) + 1

            if (at > 0 && at != written) {
                written = at
                onChoose?.invoke(at)
            }
        }
    }

    /** Shows the segment at a position as the chosen one. */
    fun choose(index: Int) {
        if (index <= 0 || index > childCount) {
            return
        }

        written = index
        check(getChildAt(index - 1).id)
    }
}

/**
 * A chooser that reports the value of what was chosen rather than where it sat in the list.
 *
 * An option carries a label a reader sees and a value a handler is given, and the platform's own
 * adapter holds only the labels, so the values are kept here to be reported by.
 */
class VarnPickerView(context: Context) : Spinner(context) {
    private var written: String? = null

    var values: List<String> = emptyList()
    var onChoose: ((String) -> Unit)? = null

    init {
        onItemSelectedListener = object : OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val chosen = values.getOrNull(position) ?: return

                // The tree writing a value back is not a person choosing one, so the first selection
                // after a write is the write arriving rather than a choice to report.
                if (chosen == written) {
                    written = null
                    return
                }

                onChoose?.invoke(chosen)
            }

            override fun onNothingSelected(parent: AdapterView<*>?) = Unit
        }
    }

    /** Shows the option carrying a value as the chosen one. */
    fun choose(value: String?) {
        val at = values.indexOf(value)
        if (at < 0) {
            return
        }

        written = value
        setSelection(at)
    }
}

/**
 * A slider that reports the number a caller asked for rather than the position the platform tracks.
 *
 * A SeekBar counts whole positions from zero, so the range and the step a tree declares are mapped onto
 * one here and mapped back when the value is reported. Reading the position as the value leaves every
 * slider with a range other than nought to one hundred at one end of its travel.
 */
class VarnSliderView(context: Context) : SeekBar(context) {
    private var current: Double = 0.0

    var minimum: Double = 0.0
        set(value) {
            field = value
            reposition()
        }

    var maximum: Double = 1.0
        set(value) {
            field = value
            reposition()
        }

    var step: Double? = null
        set(value) {
            field = value
            reposition()
        }

    var continuous: Boolean = true

    var onValueChange: ((Double) -> Unit)? = null
    var onValueCommit: ((Double) -> Unit)? = null

    init {
        setOnSeekBarChangeListener(object : OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar, position: Int, fromUser: Boolean) {
                if (!fromUser) {
                    return
                }

                current = valueAt(position)

                if (continuous) {
                    onValueChange?.invoke(current)
                }
            }

            override fun onStartTrackingTouch(bar: SeekBar) = Unit

            override fun onStopTrackingTouch(bar: SeekBar) {
                if (!continuous) {
                    onValueChange?.invoke(current)
                }

                onValueCommit?.invoke(current)
            }
        })

        reposition()
    }

    fun setValue(next: Double) {
        current = next
        reposition()
    }

    /** How many positions the travel is divided into, which is the step when one was declared. */
    private fun positions(): Int {
        val span = maximum - minimum
        if (span <= 0.0) {
            return 1
        }

        val stepping = step
        if (stepping != null && stepping > 0.0) {
            return maxOf(1, Math.round(span / stepping).toInt())
        }

        return FINE
    }

    private fun valueAt(position: Int): Double = minimum + (maximum - minimum) * position / positions()

    private fun reposition() {
        val span = maximum - minimum
        max = positions()
        progress = if (span <= 0.0) 0 else Math.round((current - minimum) / span * positions()).toInt()
    }

    private companion object {
        /** The travel of a slider with no step, fine enough that a drag reads as continuous. */
        const val FINE = 1000
    }
}
