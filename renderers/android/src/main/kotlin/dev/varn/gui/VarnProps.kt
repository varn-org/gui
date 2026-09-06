package dev.varn.gui

import android.text.Editable
import android.text.TextWatcher
import android.view.View
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
            "text", "title", "label", "initials" -> (view as? TextView)?.text = value?.toString() ?: ""
            "placeholder" -> (view as? EditText)?.hint = value as? String
            "value" -> applyValue(value, view)
            "selected" -> (view as? RadioButton)?.isChecked = value as? Boolean ?: false
            "count" -> (view as? RatingBar)?.numStars = (value as? Number)?.toInt() ?: 5
            "options" -> applyOptions(value as? JSONArray, view)
            "spans" -> applySpans(value as? JSONArray, view, density)
            "source" -> applySource(value, view)
            "pointerEvents" -> view.isClickable = value as? String != "none"
            "tint" -> applyTint(value, view)
            "onColor", "trackColor" -> applyTrackColour(value, view)
            "thumbColor" -> VarnStyle.color(value)?.let { applyThumbColour(it, view) }
            "step" -> applyStep((value as? Number)?.toDouble(), view)
            "continuous" -> (view as? VarnSliderView)?.continuous = value as? Boolean ?: true
            "poster" -> applyPoster(value as? String, view)
            "loop" -> (view as? VideoView)?.setOnPreparedListener { it.isLooping = value as? Boolean ?: false }
            "autoplay" -> if (value as? Boolean == true) (view as? VideoView)?.start()
            "controls" -> applyControls(value as? Boolean ?: true, view)
            "javaScriptEnabled" -> (view as? WebView)?.settings?.javaScriptEnabled = value as? Boolean ?: true
            "resizeMode" -> applyResizeMode(value as? String, view)
            "disabled" -> view.isEnabled = !(value as? Boolean ?: false)
            "editable" -> view.isEnabled = value as? Boolean ?: true
            "secure" -> applySecure(value as? Boolean ?: false, view)
            "maxLength" -> applyLimit((value as? Number)?.toInt(), view)
            "autoCapitalize" -> applyCapitalisation(value as? String, view)
            "autoCorrect" -> applyCorrection(value as? Boolean ?: true, view)
            "placeholderColor" -> VarnStyle.color(value)?.let { (view as? EditText)?.setHintTextColor(it) }
            "keyboard" -> (view as? EditText)?.inputType = inputType(value as? String)
            "numberOfLines" -> (view as? TextView)?.maxLines = (value as? Int) ?: Int.MAX_VALUE
            "minimum" -> applyBound(value as? Number, view, least = true)
            "maximum" -> applyBound(value as? Number, view, least = false)
            "animating" -> view.visibility = if (value as? Boolean != false) View.VISIBLE else View.GONE
            "visible", "open" -> view.visibility = if (value as? Boolean == true) View.VISIBLE else View.GONE
            "url" -> (view as? WebView)?.loadUrl(value as? String ?: "")
            "html" -> (view as? WebView)?.loadDataWithBaseURL(null, value as? String ?: "", "text/html", "utf-8", null)
            "commands" -> (view as? VarnCanvasView)?.commands = value as? JSONArray ?: JSONArray()
            "segments" -> applySegments(value as? JSONArray, view)
            "selectedIndex" -> applySelectedSegment((value as? Number)?.toInt() ?: 1, view)
            "accessibilityLabel" -> view.contentDescription = value as? String
            "testID" -> view.tag = value as? String
            "contentExtent" -> (view as? VarnCollectionView)?.setContentExtent(((value as? Number)?.toFloat() ?: 0f) * density)
            "horizontal" -> (view as? VarnCollectionView)?.setHorizontal(value as? Boolean ?: false)
            "scrollEnabled" -> (view as? VarnCollectionView)?.setScrollEnabled(value as? Boolean ?: true)
        }
    }

    private fun applyValue(value: Any?, view: View) {
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
                // reader typing into a controlled field would lose their place on every keystroke.
                val text = value as? String ?: ""
                if (view.text.toString() != text) {
                    view.setText(text)
                    view.setSelection(text.length)
                }
            }
        }
    }

    /** Says how a picture fills the frame the engine gave it, which is never the frame's own shape. */
    private fun applyResizeMode(mode: String?, view: View) {
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
        (view as? Switch)?.trackTintList = tint
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
        val image = view as? ImageView ?: return
        val colour = VarnStyle.color(value)

        if (colour == null) {
            image.clearColorFilter()
            return
        }

        image.setColorFilter(colour)
    }

    private fun applyControls(showing: Boolean, view: View) {
        val video = view as? VideoView ?: return

        if (!showing) {
            video.setMediaController(null)
            return
        }

        val controller = android.widget.MediaController(view.context)
        controller.setAnchorView(video)
        video.setMediaController(controller)
    }

    private fun applyPoster(path: String?, view: View) {
        val video = view as? VideoView ?: return
        video.background = path?.let { android.graphics.drawable.Drawable.createFromPath(it) }
    }

    private fun applySource(value: Any?, view: View) {
        val path = value as? String ?: return

        when (view) {
            is ImageView -> view.setImageURI(android.net.Uri.parse(path))
            is VideoView -> view.setVideoURI(android.net.Uri.parse(path))
        }
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
                val size = (style.optDouble("fontSize", 16.0) * density).toInt()
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
    private fun moment(year: Int, month: Int, day: Int, hour: Int, minute: Int): String =
        String.format(java.util.Locale.ROOT, "%04d-%02d-%02dT%02d:%02d:00Z", year, month + 1, day, hour, minute)

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
                view.setOnClickListener { emit(id, event, null) }
                showPress(view)
            }

            "onScroll" -> (view as? VarnCollectionView)?.onScroll = { x, y ->
                emit(id, event, JSONObject().put("x", x / density).put("y", y / density))
            }

            "onLongPress" -> view.setOnLongClickListener {
                emit(id, event, null)
                true
            }

            "onChange" -> bindChange(view, id, event, emit)

            "onCommit" -> (view as? VarnSliderView)?.onValueCommit = { emit(id, event, it) }

            "onEnd" -> (view as? VideoView)?.setOnCompletionListener { emit(id, event, null) }

            "onFocus", "onBlur" -> view.setOnFocusChangeListener { _, focused ->
                val name = if (focused) "onFocus" else "onBlur"
                if (name == event) {
                    emit(id, event, null)
                }
            }
        }
    }

    /**
     * Answers a finger the way the platform answers one, which a control that does not read as unlistening.
     *
     * The listener says it did not handle the touch, so the click the view already knows how to report
     * still reaches it.
     */
    @Suppress("ClickableViewAccessibility")
    private fun showPress(view: View) {
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
            is CompoundButton -> view.setOnCheckedChangeListener { _, checked ->
                emit(id, event, checked)
            }

            is VarnSliderView -> view.onValueChange = { emit(id, event, it) }

            is VarnStepperView -> view.onValueChange = { emit(id, event, it) }

            is VarnPickerView -> view.onChoose = { emit(id, event, it) }

            is RatingBar -> view.setOnRatingBarChangeListener { _, rating, fromUser ->
                if (fromUser) {
                    emit(id, event, rating.toDouble())
                }
            }

            is VarnSegmentedView -> view.onChoose = { emit(id, event, it) }

            is DatePicker -> view.init(view.year, view.month, view.dayOfMonth) { _, year, month, day ->
                emit(id, event, moment(year, month, day, 0, 0))
            }

            is TimePicker -> view.setOnTimeChangedListener { _, hour, minute ->
                emit(id, event, moment(1970, 0, 1, hour, minute))
            }

            is EditText -> view.addTextChangedListener(object : TextWatcher {
                override fun afterTextChanged(text: Editable) {
                    emit(id, event, text.toString())
                }

                override fun beforeTextChanged(text: CharSequence, start: Int, count: Int, after: Int) = Unit
                override fun onTextChanged(text: CharSequence, start: Int, before: Int, count: Int) = Unit
            })
        }
    }
}
