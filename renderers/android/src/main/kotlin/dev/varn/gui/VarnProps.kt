package dev.varn.gui

import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.BaseInputConnection
import android.webkit.WebView
import android.widget.*
import org.json.JSONArray
import org.json.JSONObject

/** Applies one prop to the view that stands for a node, and wires the events it declares. */
object VarnProps {

    fun apply(
        key: String,
        value: Any?,
        view: View,
        type: String,
        id: Int,
        density: Float,
        emit: (Int, String, Any?) -> Unit,
    ) {
        // Layout is computed by the engine, so a node that asked to hear about its frame hears from there.
        if (key == "onLayout") {
            return
        }

        if (key.startsWith("on")) {
            bind(key, view, id, density, emit)
            return
        }

        when (key) {
            "text", "title", "label" -> (view as? TextView)?.text = value?.toString() ?: ""
            "placeholder" -> applyPlaceholder(value as? String, view)
            "muted" -> (view as? VarnVideoView)?.muted = value as? Boolean ?: false
            "volume" -> {
                (view as? VarnVideoView)?.volume = (value as? Number)?.toFloat() ?: 1f
                (view as? VarnAudioView)?.setVolume((value as? Number)?.toFloat() ?: 1f)
            }
            "rate" -> {
                (view as? VarnVideoView)?.rate = (value as? Number)?.toFloat() ?: 1f
                (view as? VarnAudioView)?.rate = (value as? Number)?.toFloat() ?: 1f
            }
            "value" -> applyValue(value, view)
            "selected" -> (view as? RadioButton)?.isChecked = value as? Boolean ?: false
            "count" -> (view as? RatingBar)?.numStars = (value as? Number)?.toInt() ?: 5
            "options" -> applyOptions(value as? JSONArray, view)
            "spans" -> applySpans(value as? JSONArray, view, density)
            "source" -> applySource(value, view)
            "sources" -> applySources(value as? JSONObject, view)
            "linkColor" -> (view as? VarnRichEditor)?.linkColor = VarnStyle.color(value)
            "slice" -> applySlice(value, view)
            "sliceScale" -> (view as? VarnNineSliceView)?.setSliceScale(
                (value as? Number)?.toFloat() ?: 1f
            )
            "pointerEvents" -> applyPointerEvents(value as? String, view)
            "tint" -> {
                (view as? VarnBlurView)?.setTint(value as? String)
                applyTint(value, view)
            }
            "color" -> applyControlColour(value, view)
            "barContent" -> applyBarContent(value as? String, view)
            "bars" -> applyBars(value as? JSONArray, view)

            "colors" -> (view as? VarnGradientView)?.setColors(value as? JSONArray)

            "locations" -> (view as? VarnGradientView)?.setLocations(value as? JSONArray)

            "direction" -> (view as? VarnGradientView)?.setDirection(value as? String)

            "intensity" -> (view as? VarnBlurView)?.setIntensity((value as? Number)?.toFloat() ?: 0.85f)

            "pinned" -> applyPinned(value as? JSONObject, view, density)

            "center" -> (view as? VarnMapView)?.setCenter(value as? JSONObject)

            // A map is zoomed to a level and a camera to a factor, which are two different numbers under
            // one name: each type reads the one it means rather than a second branch never being reached.
            "zoom" -> {
                (view as? VarnMapView)?.setZoom((value as? Number)?.toDouble() ?: 14.0)
                (view as? VarnCameraView)?.zoom = (VarnValue.number(value) ?: 1.0).toFloat()
            }

            "markers" -> (view as? VarnMapView)?.setMarkers(value as? JSONArray)

            "interactive" -> (view as? VarnMapView)?.setInteractive(value as? Boolean ?: true)

            "watch" -> (view as? VarnLocationView)?.setWatch(value as? Boolean ?: false)

            "accuracy" -> (view as? VarnLocationView)?.setAccuracy(value as? String)

            "playing" -> (view as? VarnAudioView)?.setPlaying(value as? Boolean ?: false)

            "kind" -> (view as? VarnFilePicker)?.setKind(value as? String)

            "accept" -> (view as? VarnFilePicker)?.setAccept(strings(value as? JSONArray))

            "multiple" -> (view as? VarnFilePicker)?.setMultiple(value as? Boolean ?: false)

            "maxBytes" -> (view as? VarnFilePicker)?.setMaxBytes((value as? Number)?.toInt() ?: 0)
            "onColor", "trackColor" -> applyTrackColour(value, view)
            "offColor" -> applyOffColour(value, view)
            "thumbColor" -> VarnStyle.color(value)?.let { applyThumbColour(it, view) }
            "hitSlop" -> (view as? VarnBoxView)?.slop = ((value as? Number)?.toFloat() ?: 0f).let {
                (it * density).toInt()
            }
            "step" -> applyStep((value as? Number)?.toDouble(), view)
            "continuous" -> (view as? VarnSliderView)?.continuous = value as? Boolean ?: true
            "poster" -> applyPoster(value as? String, view)
            "loop" -> {
                (view as? VarnVideoView)?.looping = value as? Boolean ?: false
                (view as? VarnAudioView)?.setLoops(value as? Boolean ?: false)
            }
            "autoplay" -> if (value as? Boolean == true) (view as? VarnVideoView)?.start()
            "controls" -> applyControls(value as? Boolean ?: true, view)
            "javaScriptEnabled" -> (view as? WebView)?.settings?.javaScriptEnabled = value as? Boolean ?: true
            "resizeMode" -> applyResizeMode(value as? String, view)
            "filter" -> {
                (view as? VarnPictureView)?.filter = matrix(value as? JSONArray)
                (view as? VarnCameraView)?.filter = VarnCameraView.matrix(value as? JSONArray)
                (view as? VarnVideoView)?.filter = VarnCameraView.matrix(value as? JSONArray)
            }
            "facing" -> (view as? VarnCameraView)?.facing = value as? String ?: "back"
            "torch" -> (view as? VarnCameraView)?.torch = value as? Boolean ?: false
            "audio" -> (view as? VarnCameraView)?.wantsAudio = value as? Boolean ?: false
            "recording" -> (view as? VarnRecorderView)?.recording = value as? Boolean ?: false
            "disabled" -> view.isEnabled = !(value as? Boolean ?: false)
            "editable" -> view.isEnabled = value as? Boolean ?: true
            "secure" -> applySecure(value as? Boolean ?: false, view)
            "maxLength" -> applyLimit((value as? Number)?.toInt(), view)
            "autoCapitalize" -> applyCapitalisation(value as? String, view)
            "autoCorrect" -> applyCorrection(value as? Boolean ?: true, view)
            "placeholderColor" -> VarnStyle.color(value)?.let { (view as? EditText)?.setHintTextColor(it) }

            "autoFocus" -> if (value as? Boolean == true) {
                view.post {
                    view.requestFocus()

                    view.context.getSystemService(android.view.inputmethod.InputMethodManager::class.java)
                        ?.showSoftInput(view, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT)
                }
            }
            "keyboard" -> (view as? EditText)?.inputType = inputType(value as? String)
            "returnKey" -> (view as? EditText)?.imeOptions = imeAction(value as? String)
            "refreshing" -> (view as? VarnCollectionView)?.showRefreshing(value as? Boolean ?: false)
            "keyboardDismissMode" -> (view as? VarnCollectionView)?.dismissesKeyboard =
                value as? String == "on-drag"
            "numberOfLines" -> (view as? TextView)?.maxLines = (value as? Int) ?: Int.MAX_VALUE
            "minimum" -> applyBound(value as? Number, view, least = true)
            "maximum" -> applyBound(value as? Number, view, least = false)
            "animating" -> view.visibility = if (value as? Boolean != false) View.VISIBLE else View.GONE
            "indeterminate" -> (view as? ProgressBar)?.isIndeterminate = value as? Boolean ?: false
            "thickness" -> applyThickness((value as? Number)?.toFloat() ?: 4f, view, density)
            "visible", "open" -> view.visibility = if (value as? Boolean == true) View.VISIBLE else View.GONE
            "url" -> (view as? WebView)?.loadUrl(value as? String ?: "")
            "html" -> (view as? WebView)?.loadDataWithBaseURL(null, value as? String ?: "", "text/html", "utf-8", null)
            "commands" -> (view as? VarnCanvasView)?.commands = value as? JSONArray ?: JSONArray()
            "segments" -> applySegments(value as? JSONArray, view)
            "selectedIndex" -> applySelectedSegment((value as? Number)?.toInt() ?: 1, view)
            "accessibilityLabel" -> view.contentDescription = value as? String
            "panAxis" -> (view as? VarnBoxView)?.panAxis = value as? String
            "focusable" -> {
                val wanted = value as? Boolean == true

                view.isFocusable = wanted
                view.isFocusableInTouchMode = wanted
            }
            "accessibilityRole" -> VarnAccess.role(view, value as? String)
            "accessibilityState" -> VarnAccess.state(view, value as? JSONObject)
            "accessibilityValue" -> VarnAccess.reading(view, value as? JSONObject)
            "testID" -> view.tag = value as? String
            "contentExtent" -> (view as? VarnCollectionView)?.setContentExtent(((value as? Number)?.toFloat() ?: 0f) * density)
            "horizontal" -> (view as? VarnCollectionView)?.setHorizontal(value as? Boolean ?: false)
            "scrollEnabled" -> (view as? VarnCollectionView)?.setScrollEnabled(value as? Boolean ?: true)
            "bounces" -> (view as? VarnCollectionView)?.bounces = value as? Boolean ?: true
            "paging" -> (view as? VarnCollectionView)?.paging = value as? Boolean ?: false
            "showsIndicator" -> (view as? VarnCollectionView)?.setShowsIndicator(value as? Boolean ?: true)
        }
    }

    private fun applyValue(value: Any?, view: View) {
        // An editor holds a document rather than a string, which is the runs the tree carries.
        if (view is VarnRichEditor) {
            view.setValue(value as? JSONArray ?: JSONArray())
            return
        }

        if (view is VarnStepperView) {
            view.setValue((value as? Number)?.toDouble() ?: 0.0)
            return
        }

        if (view is RatingBar) {
            view.rating = (value as? Number)?.toFloat() ?: 0f
            return
        }

        if (view is VarnPickerView) {
            view.choose(value as? String)
            return
        }

        if (view is VarnColorView) {
            VarnStyle.color(value)?.let { view.color = it }
            return
        }

        if (view is DatePicker) {
            chooseDay(value as? String, view)
            return
        }

        if (view is TimePicker) {
            chooseClock(value as? String, view)
            return
        }

        when (view) {
            // A radio's value is the identity it reports when chosen, never whether it is chosen,
            // which is what `selected` says. Reading it as a state leaves every radio in a group off.
            is RadioButton -> Unit
            is Switch -> view.isChecked = value as? Boolean ?: false
            is CheckBox -> view.isChecked = value as? Boolean ?: false
            is VarnSliderView -> view.setValue((value as? Number)?.toDouble() ?: 0.0)
            is ProgressBar -> view.progress = ((value as? Number)?.toDouble()?.times(100))?.toInt() ?: 0
            is EditText -> {
                // Writing the text a field already holds puts the caret back at the start of it, so a
                // reader typing into a controlled field would lose their place on every keystroke. What
                // the field itself said a moment ago is not news either: the tree answers a keystroke a
                // commit later, by which time the reader has typed again.
                val text = value as? String ?: ""
                val field = view as? VarnTextField

                // A word an input method is still composing is held in the field as a span of its own,
                // and writing the tree's own value over it takes the half-written word away.
                if (BaseInputConnection.getComposingSpanStart(view.text) >= 0) {
                    return
                }

                if (field == null || !field.echoed(text)) {
                    if (view.text.toString() != text) {
                        view.setText(text)
                        view.setSelection(text.length)
                    }

                    field?.written()
                }
            }
        }
    }

    /** Draws what stands in for a picture while it is on its way, and stays when it never comes. */
    private fun applyPlaceholder(value: String?, view: View) {
        (view as? EditText)?.hint = value

        val image = view as? ImageView ?: return

        if (image.drawable == null && value != null) {
            image.setImageDrawable(android.graphics.drawable.Drawable.createFromPath(value))
        }
    }

    /** Says how a picture fills the frame the engine gave it, which is never the frame's own shape. */
    private fun applyResizeMode(mode: String?, view: View) {
        (view as? VarnVideoView)?.resizeMode = mode ?: "contain"

        val image = view as? ImageView ?: return

        image.scaleType = when (mode) {
            "contain" -> ImageView.ScaleType.FIT_CENTER
            "stretch" -> ImageView.ScaleType.FIT_XY
            "center" -> ImageView.ScaleType.CENTER
            else -> ImageView.ScaleType.CENTER_CROP
        }
    }

    /** Paints the part of a control the value fills, which is the track on a slider and a bar. */
    private fun applyTrackColour(value: Any?, view: View) {
        val colour = VarnStyle.color(value) ?: return
        val tint = android.content.res.ColorStateList.valueOf(colour)

        (view as? SeekBar)?.progressTintList = tint
        (view as? ProgressBar)?.progressTintList = tint
        (view as? Switch)?.let { paintTrack(it, on = colour) }
    }

    /**
     * Says how the system draws the content of its own bars, which is the window's to answer.
     *
     * A status bar's clock and a navigation bar's gestures are drawn by the system over whatever the
     * application put behind them, and only the window may say whether they are drawn light or dark.
     */
    /**
     * Hides the system's own bars a screen no longer names, and brings back the ones it does.
     *
     * A bar that is hidden gives its room back to the window, so what the tree is avoiding changes with
     * it and a screen stays correct across the change without doing anything. What a reader swipes to
     * bring a hidden bar back is left as the platform's own, since taking that away is how an
     * application traps somebody in itself.
     */
    private fun applyBars(bars: JSONArray?, view: View) {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.R) {
            return
        }

        val window = (view.context as? android.app.Activity)?.window ?: return
        val controller = window.insetsController ?: return

        val shown = mutableSetOf<String>()

        for (index in 0 until (bars?.length() ?: 0)) {
            shown += bars?.optString(index) ?: continue
        }

        var hiding = 0

        if (!shown.contains("status")) {
            hiding = hiding or android.view.WindowInsets.Type.statusBars()
        }

        if (!shown.contains("navigation")) {
            hiding = hiding or android.view.WindowInsets.Type.navigationBars()
        }

        controller.systemBarsBehavior =
            android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE

        if (hiding != 0) {
            controller.hide(hiding)
        }

        val showing = (android.view.WindowInsets.Type.statusBars() or
            android.view.WindowInsets.Type.navigationBars()) and hiding.inv()

        if (showing != 0) {
            controller.show(showing)
        }
    }

    private fun applyBarContent(content: String?, view: View) {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.R) {
            return
        }

        val window = (view.context as? android.app.Activity)?.window ?: return
        val controller = window.insetsController ?: return

        val light = if (content == "dark") {
            android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
        } else {
            0
        }

        controller.setSystemBarsAppearance(
            light,
            android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
        )
    }

    /**
     * Paints the mark a control draws, which is what a colour on a control rather than on text means.
     *
     * A style's colour is the colour of a string. A control that draws a tick, a spinner or a bar draws
     * it in the colour the tree gave the control, and each of those was the platform's own.
     */
    private fun applyControlColour(value: Any?, view: View) {
        val colour = VarnStyle.color(value) ?: return
        val tint = android.content.res.ColorStateList.valueOf(colour)

        (view as? CompoundButton)?.buttonTintList = tint

        (view as? ProgressBar)?.let {
            it.indeterminateTintList = tint
            it.progressTintList = tint
        }
    }

    /** Paints the track a switch shows while it is off, which is a different state of the one tint list. */
    private fun applyOffColour(value: Any?, view: View) {
        val colour = VarnStyle.color(value) ?: return

        (view as? Switch)?.let { paintTrack(it, off = colour) }
    }

    /**
     * Paints a switch's track, which carries the colour for each of its two states in one list.
     *
     * A switch holds a single tint list, so setting one state from a plain colour would take the other
     * one away, and the two colours arrive as separate props in no order at all.
     */
    private fun paintTrack(view: Switch, on: Int? = null, off: Int? = null) {
        val held = view.trackTintList
        val states = arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf())

        val chosen = on ?: held?.getColorForState(states[0], 0) ?: 0
        val plain = off ?: held?.getColorForState(states[1], 0) ?: 0

        view.trackTintList = android.content.res.ColorStateList(states, intArrayOf(chosen, plain))
    }

    /**
     * Draws a bar at the thickness it was asked for, which is not the height of the box holding it.
     *
     * The engine gives a progress bar a frame with room to spare around it, the way a platform draws one,
     * so the bar itself is scaled inside that frame rather than stretched to fill it.
     */
    private fun applyThickness(thickness: Float, view: View, density: Float) {
        val bar = view as? ProgressBar ?: return
        val wanted = thickness * density

        bar.scaleY = if (bar.height > 0) wanted / bar.height else 1f
        bar.minimumHeight = wanted.toInt()
    }

    /** Says how coarsely a control counts, which a stepper and a slider both take. */
    private fun applyStep(step: Double?, view: View) {
        (view as? VarnStepperView)?.step = step ?: 1.0
        (view as? VarnSliderView)?.step = step
    }

    /** Says how far a control may be taken, which a stepper and a slider both take. */
    private fun applyBound(bound: Number?, view: View, least: Boolean) {
        val edge = bound?.toDouble()

        if (view is VarnSliderView) {
            if (least) {
                view.minimum = edge ?: 0.0
            } else {
                view.maximum = edge ?: 1.0
            }

            return
        }

        if (view is VarnStepperView) {
            if (least) {
                view.minimum = edge ?: Double.NEGATIVE_INFINITY
            } else {
                view.maximum = edge ?: Double.POSITIVE_INFINITY
            }
        }
    }

    private fun applyThumbColour(colour: Int, view: View) {
        val tint = android.content.res.ColorStateList.valueOf(colour)

        (view as? SeekBar)?.thumbTintList = tint
        (view as? Switch)?.thumbTintList = tint
    }

    /** Draws a picture in one colour, which is what an icon carried as an image is. */
    private fun applyTint(value: Any?, view: View) {
        (view as? VarnPictureView)?.tint = VarnStyle.color(value)
    }

    /**
     * Answers the colour matrix a filter arrived as, which the engine worked out rather than the caller.
     *
     * A matrix is twenty numbers read as four rows of five, which is the shape a `ColorMatrix` takes, so
     * what the browser and iOS are sent is what Android applies.
     */
    private fun matrix(value: JSONArray?): FloatArray? {
        if (value == null || value.length() != 20) {
            return null
        }

        // The last column of each row is added to a channel, and a channel here counts to 255 rather
        // than to one, which is the one thing this shape does not share with the other two.
        return FloatArray(20) {
            val number = value.optDouble(it, 0.0)

            if (it % 5 == 4) (number * 255).toFloat() else number.toFloat()
        }
    }

    private fun applyControls(showing: Boolean, view: View) {
        (view as? VarnVideoView)?.showControls(showing)
    }

    private fun applyPoster(path: String?, view: View) {
        (view as? VarnVideoView)?.showPoster(path)
    }

    private fun applySource(value: Any?, view: View) {
        val path = value as? String ?: return

        when (view) {
            is ImageView -> view.setImageURI(android.net.Uri.parse(path))
            is VarnVideoView -> view.setVideoURI(android.net.Uri.parse(path))
            is VarnAudioView -> view.setSource(path)
            is VarnNineSliceView -> view.setSource(path)
        }
    }

    /** Takes the artwork a frame draws each state with, which is what makes one a button that presses. */
    private fun applySources(value: JSONObject?, view: View) {
        val frame = view as? VarnNineSliceView ?: return
        val named = mutableMapOf<String, String>()

        for (state in value?.keys() ?: emptyList<String>().iterator()) {
            (value?.opt(state) as? String)?.let { named[state] = it }
        }

        frame.setSources(named)
    }

    /** Takes where a picture is cut, which the engine sends as four numbers of its own pixels. */
    private fun applySlice(value: Any?, view: View) {
        val frame = view as? VarnNineSliceView ?: return
        val cuts = value as? JSONObject ?: return

        frame.setSlice(
            cuts.optInt("top"),
            cuts.optInt("right"),
            cuts.optInt("bottom"),
            cuts.optInt("left")
        )
    }

    /** Refuses what does not fit as it is typed, since trimming it afterwards moves the caret. */
    private fun applyLimit(limit: Int?, view: View) {
        val field = view as? EditText ?: return

        field.filters = if (limit == null) {
            arrayOf()
        } else {
            arrayOf<android.text.InputFilter>(android.text.InputFilter.LengthFilter(limit))
        }
    }

    private fun applyCapitalisation(name: String?, view: View) {
        val field = view as? EditText ?: return
        val base = field.inputType and android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES.inv() and
            android.text.InputType.TYPE_TEXT_FLAG_CAP_WORDS.inv() and
            android.text.InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS.inv()

        field.inputType = base or when (name) {
            "none" -> 0
            "words" -> android.text.InputType.TYPE_TEXT_FLAG_CAP_WORDS
            "characters" -> android.text.InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            else -> android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        }
    }

    private fun applyCorrection(correcting: Boolean, view: View) {
        val field = view as? EditText ?: return

        field.inputType = if (correcting) {
            field.inputType or android.text.InputType.TYPE_TEXT_FLAG_AUTO_CORRECT
        } else {
            field.inputType and android.text.InputType.TYPE_TEXT_FLAG_AUTO_CORRECT.inv()
        }
    }

    private fun applySecure(secure: Boolean, view: View) {
        val field = view as? EditText ?: return

        field.inputType = if (secure) {
            android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD
        } else {
            android.text.InputType.TYPE_CLASS_TEXT
        }
    }

    /**
     * Draws a paragraph made of runs that each carry a style of their own.
     *
     * A span flows inline within the paragraph, which only a spanned string can do, so this is one of
     * the few places a renderer builds something rather than being handed it as nodes.
     */
    private fun applySpans(spans: JSONArray?, view: View, density: Float) {
        val label = view as? TextView ?: return
        val paragraph = android.text.SpannableStringBuilder()

        for (index in 0 until (spans?.length() ?: 0)) {
            val span = spans!!.optJSONObject(index) ?: continue
            val style = span.optJSONObject("style") ?: JSONObject()
            val from = paragraph.length

            paragraph.append(span.optString("text"))
            val to = paragraph.length
            val inclusive = android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE

            VarnStyle.color(style.opt("color"))?.let {
                paragraph.setSpan(android.text.style.ForegroundColorSpan(it), from, to, inclusive)
            }

            if (style.has("fontSize")) {
                val size = (style.optDouble("fontSize", 15.0) * density).toInt()
                paragraph.setSpan(android.text.style.AbsoluteSizeSpan(size), from, to, inclusive)
            }

            when (style.optString("textDecoration", "")) {
                "underline" -> paragraph.setSpan(android.text.style.UnderlineSpan(), from, to, inclusive)
                "line-through" -> paragraph.setSpan(android.text.style.StrikethroughSpan(), from, to, inclusive)
            }
        }

        label.text = paragraph
    }

    private fun applySegments(segments: JSONArray?, view: View) {
        val group = view as? VarnSegmentedView ?: return

        // The props of one node arrive in no particular order, so the chosen segment is carried across
        // the rebuild of the titles rather than lost whenever it happens to be applied first.
        val chosen = group.indexOfChild(group.findViewById(group.checkedRadioButtonId)) + 1
        group.removeAllViews()

        for (index in 0 until (segments?.length() ?: 0)) {
            val button = RadioButton(view.context)
            button.id = index + 1
            button.text = segments?.optString(index)
            group.addView(button)
        }

        group.choose(chosen)
    }

    private fun applySelectedSegment(index: Int, view: View) {
        (view as? VarnSegmentedView)?.choose(index)
    }

    /** Shows the choices a picker holds, which is what the platform's own chooser lists. */
    private fun applyOptions(options: JSONArray?, view: View) {
        val spinner = view as? VarnPickerView ?: return
        val labels = mutableListOf<String>()
        val values = mutableListOf<String>()

        for (index in 0 until (options?.length() ?: 0)) {
            val option = options!!.optJSONObject(index)
            val label = option?.optString("label") ?: ""

            labels.add(label)
            values.add(option?.optString("value")?.takeIf { it.isNotEmpty() } ?: label)
        }

        spinner.values = values
        spinner.adapter = ArrayAdapter(view.context, android.R.layout.simple_spinner_dropdown_item, labels)
    }

    /** Writes an instant the way every renderer reports one, which is what a handler parses. */
    /**
     * Answers a chosen date the way a calendar shows it, which is what every renderer reports.
     *
     * A picker chooses what a calendar shows rather than a moment on a timeline. Reporting it as an
     * instant gives it a zone nobody chose, and reading it back in another one moves the day.
     */
    private fun day(year: Int, month: Int, dayOfMonth: Int): String =
        String.format(java.util.Locale.ROOT, "%04d-%02d-%02d", year, month + 1, dayOfMonth)

    /** Answers a chosen time the way a clock shows it, which carries no day and no zone either. */
    private fun clock(hour: Int, minute: Int): String =
        String.format(java.util.Locale.ROOT, "%02d:%02d", hour, minute)

    /** Puts a calendar on the day it was given, in the same form it reports one in. */
    private fun chooseDay(text: String?, view: DatePicker) {
        val parts = text?.take(10)?.split("-")?.mapNotNull { it.toIntOrNull() } ?: return

        if (parts.size != 3) {
            return
        }

        view.updateDate(parts[0], parts[1] - 1, parts[2])
    }

    /** Puts a clock on the time it was given, in the same form it reports one in. */
    private fun chooseClock(text: String?, view: TimePicker) {
        val parts = text?.split(":")?.mapNotNull { it.toIntOrNull() } ?: return

        if (parts.size < 2) {
            return
        }

        view.hour = parts[0]
        view.minute = parts[1]
    }

    /** What the return key says it does, which is what the platform draws on it. */
    private fun imeAction(name: String?): Int = when (name) {
        "go" -> android.view.inputmethod.EditorInfo.IME_ACTION_GO
        "next" -> android.view.inputmethod.EditorInfo.IME_ACTION_NEXT
        "search" -> android.view.inputmethod.EditorInfo.IME_ACTION_SEARCH
        "send" -> android.view.inputmethod.EditorInfo.IME_ACTION_SEND
        else -> android.view.inputmethod.EditorInfo.IME_ACTION_DONE
    }

    private fun inputType(name: String?): Int = when (name) {
        "number" -> android.text.InputType.TYPE_CLASS_NUMBER
        "decimal" -> android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL
        "email" -> android.text.InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
        "phone" -> android.text.InputType.TYPE_CLASS_PHONE
        "url" -> android.text.InputType.TYPE_TEXT_VARIATION_URI
        else -> android.text.InputType.TYPE_CLASS_TEXT
    }

    private fun bind(
        event: String,
        view: View,
        id: Int,
        density: Float,
        emit: (Int, String, Any?) -> Unit,
    ) {
        when (event) {
            "onPress" -> {
                // A map answers a press with where on the world it landed, which a click listener has no
                // way of knowing.
                val map = view as? VarnMapView

                if (map != null) {
                    map.onPress = { at -> emit(id, event, at) }
                    return
                }

                view.setOnClickListener { emit(id, event, null) }

                // A box that answers a press is reached with a keyboard or a pad the way a button is,
                // which a view only is when it says so before Android 26 decides it from being clickable.
                view.isFocusable = true
                showPress(view)
            }

            // A box reports both edges through the one touch it already answers, since a view holds a
            // single touch listener and one per edge left whichever arrived last replacing the other.
            "onPressIn", "onPressOut" -> (view as? VarnBoxView)?.let { box ->
                box.isClickable = true

                if (event == "onPressIn") {
                    box.onPressIn = { emit(id, event, null) }
                    return
                }

                box.onPressOut = { emit(id, event, null) }
            }

            "onScroll" -> (view as? VarnCollectionView)?.let { surface ->
                surface.onScroll = { x, y ->
                    emit(id, event, JSONObject().put("x", x / density).put("y", y / density))
                }

                surface.reportOffset()
            }

            "onScrollEnd" -> (view as? VarnCollectionView)?.onScrollEnd = { x, y ->
                emit(id, event, JSONObject().put("x", x / density).put("y", y / density))
            }

            "onDoublePress" -> (view as? VarnBoxView)?.let { box ->
                box.isClickable = true
                box.onDoublePress = { emit(id, event, null) }
            }

            // A key reaches whatever has focus, which is what every platform delivers one to. The names
            // are the browser's published set, since that is the only one all three can be mapped onto.
            "onKeyDown", "onKeyUp" -> {
                view.isFocusableInTouchMode = true

                view.setOnKeyListener { _, code, key ->
                    val named = if (key.action == android.view.KeyEvent.ACTION_DOWN) "onKeyDown" else "onKeyUp"

                    emit(id, named, VarnKeys.payload(code, key))
                    false
                }
            }

            // A field and an editor both say where the caret is, and one branch answers for both of them,
            // since a second branch by the same name is one a `when` never reaches.
            "onSelectionChange" -> {
                (view as? VarnTextField)?.onSelection = { where -> emit(id, event, where) }
                (view as? VarnRichEditor)?.onSelection = { where -> emit(id, event, where) }
            }

            "onSwipe" -> (view as? VarnBoxView)?.let { box ->
                box.isClickable = true
                box.onSwipe = { direction -> emit(id, event, JSONObject().put("direction", direction)) }
            }

            // A finger following a path, which is what a slider is. One listener reports all three and
            // the name reported is the phase the drag is in.
            "onPanStart", "onPanMove", "onPanEnd" -> (view as? VarnBoxView)?.let { box ->
                box.isClickable = true
                box.onPan = { phase, x, y, dx, dy ->
                    emit(
                        id,
                        phase,
                        JSONObject()
                            .put("x", x / density)
                            .put("y", y / density)
                            .put("dx", dx / density)
                            .put("dy", dy / density),
                    )
                }
            }

            // The second button on a pointer, and the finger held that means the same thing. A view
            // reports both through one listener, so where it happened is read off the last touch.
            "onContextPress" -> {
                view.isClickable = true

                val where = {
                    val at = (view as? VarnBoxView)?.touchedAt ?: Pair(0f, 0f)
                    JSONObject().put("x", at.first / density).put("y", at.second / density)
                }

                view.setOnLongClickListener {
                    emit(id, event, where())
                    true
                }

                view.setOnContextClickListener {
                    emit(id, event, where())
                    true
                }
            }

            "onLongPress" -> view.setOnLongClickListener {
                emit(id, event, null)
                true
            }

            // One listener reports both, so the name reported is the phase the pointer is in rather than
            // the event this binding was made for. The engine drops what the node has no handler for.
            "onHoverIn", "onHoverOut" -> view.setOnHoverListener { _, motion ->
                when (motion.actionMasked) {
                    MotionEvent.ACTION_HOVER_ENTER -> emit(id, "onHoverIn", null)
                    MotionEvent.ACTION_HOVER_EXIT -> emit(id, "onHoverOut", null)
                }

                false
            }

            // What a control was changed to and which of a set was chosen are the same reading, and a
            // radio only ever reports the second of them.
            "onChange", "onSelect" -> bindChange(view, id, event, emit)

            "onCommit" -> (view as? VarnSliderView)?.onValueCommit = { emit(id, event, it) }

            "onPick" -> (view as? VarnFilePicker)?.onPick = { file -> emit(id, event, file) }

            "onRegionChange" -> (view as? VarnMapView)?.onRegionChange = { region -> emit(id, event, region) }

            "onMarkerPress" -> (view as? VarnMapView)?.onMarkerPress = { marker -> emit(id, event, marker) }

            "onError" -> {
                (view as? VarnLocationView)?.onError = { problem -> emit(id, event, problem) }
                (view as? VarnAudioView)?.onError = { message ->
                    emit(id, event, JSONObject().put("message", message))
                }
                (view as? VarnVideoView)?.onError = { message ->
                    emit(id, event, JSONObject().put("message", message))
                }
                (view as? VarnWebView)?.onError = { message ->
                    emit(id, event, JSONObject().put("message", message))
                }
            }

            "onWillLoad" -> (view as? VarnWebView)?.onWillLoad = { url ->
                emit(id, event, JSONObject().put("url", url))
            }

            "onLoad" -> (view as? VarnWebView)?.onLoad = { url ->
                emit(id, event, JSONObject().put("url", url))
            }

            "onProgress" -> (view as? VarnAudioView)?.onProgress = { at -> emit(id, event, at) }

            "onReady" -> (view as? VarnAudioView)?.onReady = { about -> emit(id, event, about) }

            "onEnd" -> {
                (view as? VarnVideoView)?.onEnd = { emit(id, event, null) }
                (view as? VarnAudioView)?.onEnd = { emit(id, event, null) }
            }

            "onFocus", "onBlur" -> bindFocus(view, id, emit)

            "onSubmit" -> (view as? EditText)?.setOnEditorActionListener { field, action, _ ->
                if (action == android.view.inputmethod.EditorInfo.IME_ACTION_NEXT) {
                    emit(id, event, null)
                    return@setOnEditorActionListener false
                }

                emit(id, event, null)
                VarnActions.hideKeyboard(field)
                true
            }

            "onRefresh" -> (view as? VarnCollectionView)?.onRefresh = { emit(id, event, null) }
        }
    }

    /**
     * Reports both edges of focus through the one listener a view holds.
     *
     * A view keeps a single `OnFocusChangeListener`, so binding `onFocus` and `onBlur` to one each left
     * whichever was applied last replacing the other, and props arrive in no order at all.
     */
    /**
     * Lets a finger through whatever it was applied to, box or not.
     *
     * A box refuses to dispatch, which is what carries the finger on to the next sibling, and anything
     * else stops answering one at all, which is what a picture drawn over a control needs.
     */
    private fun applyPointerEvents(value: String?, view: View) {
        val through = value == "none"
        val box = view as? VarnBoxView

        if (box != null) {
            box.passesThrough = through
            return
        }

        view.isClickable = !through
        view.isFocusable = !through
        view.isEnabled = !through || view !is Button
    }

    /** Holds a box against the leading edge of the surface it scrolls inside, over the range it names. */
    private fun applyPinned(range: JSONObject?, view: View, density: Float) {
        val box = view as? VarnBoxView ?: return

        box.pinned = if (range == null) null
            else (range.optDouble("from").toFloat() * density) to (range.optDouble("to").toFloat() * density)

        ((view.parent as? View)?.parent as? VarnCollectionView)?.hold()
    }

    /** Answers a list of strings a prop carries, which arrives as json like every other list. */
    private fun strings(value: JSONArray?): List<String> {
        if (value == null) {
            return emptyList()
        }

        return (0 until value.length()).mapNotNull { at -> value.optString(at).takeIf { it.isNotEmpty() } }
    }

    private fun bindFocus(view: View, id: Int, emit: (Int, String, Any?) -> Unit) {
        view.setOnFocusChangeListener { _, focused ->
            emit(id, if (focused) "onFocus" else "onBlur", null)
        }
    }

    /**
     * Answers a finger the way the platform does, so a box that is listening does not read as one that is not.
     *
     * A box does this itself, since it also reports the edges of a press and a view holds one listener.
     */
    @Suppress("ClickableViewAccessibility")
    private fun showPress(view: View) {
        if (view is VarnBoxView) {
            return
        }

        view.setOnTouchListener { pressed, motion ->
            when (motion.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN -> pressed.alpha = 0.55f
                android.view.MotionEvent.ACTION_UP,
                android.view.MotionEvent.ACTION_CANCEL -> pressed.animate().alpha(1f).setDuration(220).start()
            }

            false
        }
    }

    private fun bindChange(view: View, id: Int, event: String, emit: (Int, String, Any?) -> Unit) {
        when (view) {
            is VarnRichEditor -> view.onDocument = { runs -> emit(id, event, runs) }

            is CompoundButton -> view.setOnCheckedChangeListener { _, checked ->
                emit(id, event, checked)
            }

            is VarnSliderView -> view.onValueChange = { emit(id, event, it) }

            is VarnStepperView -> view.onValueChange = { emit(id, event, it) }

            is VarnPickerView -> view.onChoose = { emit(id, event, it) }

            is VarnLocationView -> view.onChange = { fix -> emit(id, event, fix) }

            is RatingBar -> view.setOnRatingBarChangeListener { _, rating, fromUser ->
                if (fromUser) {
                    emit(id, event, rating.toDouble())
                }
            }

            is VarnSegmentedView -> view.onChoose = { emit(id, event, it) }

            is VarnColorView -> view.onChoose = { emit(id, event, it) }

            is DatePicker -> view.init(view.year, view.month, view.dayOfMonth) { _, year, month, chosen ->
                emit(id, event, day(year, month, chosen))
            }

            is TimePicker -> view.setOnTimeChangedListener { _, hour, minute ->
                emit(id, event, clock(hour, minute))
            }

            is VarnTextField -> view.onTyped = { typed -> emit(id, event, typed) }
        }
    }
}
