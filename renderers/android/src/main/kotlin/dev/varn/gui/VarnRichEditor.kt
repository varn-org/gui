package dev.varn.gui

import android.content.ClipboardManager
import android.content.Context
import android.graphics.Typeface
import android.text.Editable
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.TextWatcher
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import android.text.style.StyleSpan
import android.text.style.TypefaceSpan
import android.text.style.URLSpan
import android.text.style.UnderlineSpan
import android.widget.EditText
import org.json.JSONArray
import org.json.JSONObject

/**
 * An editor over styled text, which is one box a reader types into rather than two that mirror.
 *
 * The platform holds a document as a spanned editable, which is what this is: the marks the tree carries
 * are turned into spans going in and read back out of them coming out. Every mark is drawn with what the
 * platform draws its own with — its bold face, its italic, its monospace — so what a reader sees is the
 * system's typography rather than a weight the tree named.
 */
class VarnRichEditor(context: Context) : EditText(context) {
    var onDocument: ((JSONArray) -> Unit)? = null
    var onSelection: ((JSONObject) -> Unit)? = null

    var limit: Int? = null

    /** The colour a link is drawn in, which is the look's rather than the platform's own. */
    var linkColor: Int? = null
        set(value) {
            field = value
            write(runs)
        }

    private var runs: JSONArray = JSONArray()
    private val said = LinkedHashSet<String>()
    private var writing = false

    init {
        background = null
        setPadding(0, 0, 0, 0)

        addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(text: Editable) {
                if (writing) {
                    return
                }

                runs = document()
                said += text.toString()

                while (said.size > SAID) {
                    said.remove(said.first())
                }

                onDocument?.invoke(runs)
                report()
            }

            override fun beforeTextChanged(text: CharSequence, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(text: CharSequence, start: Int, before: Int, count: Int) = Unit
        })
    }

    override fun onSelectionChanged(start: Int, end: Int) {
        super.onSelectionChanged(start, end)
        report()
    }

    /** Takes the document the tree holds, unless it is one this editor said itself. */
    fun setValue(given: JSONArray) {
        runs = given

        if (said.contains(plain(given))) {
            said.clear()
            return
        }

        said.clear()
        write(given)
    }

    /** Draws the document again, keeping the caret where the reader left it. */
    private fun write(given: JSONArray) {
        val at = selectionStart
        val built = SpannableStringBuilder()

        for (index in 0 until given.length()) {
            val run = given.optJSONObject(index) ?: continue
            val text = run.optString("text", "")
            val marks = run.optJSONObject("marks") ?: JSONObject()
            val from = built.length

            built.append(text)
            mark(built, marks, from, built.length)
        }

        writing = true
        setText(built, BufferType.SPANNABLE)
        writing = false

        setSelection(at.coerceIn(0, built.length))
    }

    /** Puts the spans one set of marks stands for over a stretch of the document. */
    private fun mark(held: SpannableStringBuilder, marks: JSONObject, from: Int, to: Int) {
        if (from >= to) {
            return
        }

        val flag = Spannable.SPAN_EXCLUSIVE_EXCLUSIVE

        if (marks.optBoolean("bold")) {
            held.setSpan(StyleSpan(Typeface.BOLD), from, to, flag)
        }

        if (marks.optBoolean("italic")) {
            held.setSpan(StyleSpan(Typeface.ITALIC), from, to, flag)
        }

        if (marks.optBoolean("underline")) {
            held.setSpan(UnderlineSpan(), from, to, flag)
        }

        if (marks.optBoolean("strikethrough")) {
            held.setSpan(StrikethroughSpan(), from, to, flag)
        }

        if (marks.optBoolean("code")) {
            held.setSpan(TypefaceSpan("monospace"), from, to, flag)
        }

        val where = marks.opt("link") as? String

        if (where != null) {
            held.setSpan(URLSpan(where), from, to, flag)
            held.setSpan(UnderlineSpan(), from, to, flag)

            linkColor?.let { held.setSpan(ForegroundColorSpan(it), from, to, flag) }
        }
    }

    /** Answers the document as runs, which is what the tree holds and what a screen draws from. */
    fun document(): JSONArray {
        val held = text as? Spannable ?: return JSONArray()
        val found = JSONArray()
        var at = 0

        while (at < held.length) {
            val next = held.nextSpanTransition(at, held.length, Any::class.java)
            val marks = marksAt(held, at, next)
            val last = if (found.length() == 0) null else found.optJSONObject(found.length() - 1)

            if (last != null && same(last.optJSONObject("marks") ?: JSONObject(), marks)) {
                last.put("text", last.optString("text", "") + held.subSequence(at, next).toString())
            } else {
                found.put(
                    JSONObject()
                        .put("text", held.subSequence(at, next).toString())
                        .put("marks", marks),
                )
            }

            at = next
        }

        return found
    }

    /** Answers the marks the spans over a stretch stand for, which is the other half of what draws them. */
    private fun marksAt(held: Spannable, from: Int, to: Int): JSONObject {
        val marks = JSONObject()

        for (span in held.getSpans(from, to, Any::class.java)) {
            when (span) {
                is StyleSpan -> when (span.style) {
                    Typeface.BOLD -> marks.put("bold", true)
                    Typeface.ITALIC -> marks.put("italic", true)
                    Typeface.BOLD_ITALIC -> marks.put("bold", true).put("italic", true)
                }

                is UnderlineSpan -> marks.put("underline", true)
                is StrikethroughSpan -> marks.put("strikethrough", true)
                is TypefaceSpan -> if (span.family == "monospace") marks.put("code", true)
                is URLSpan -> marks.put("link", span.url)
            }
        }

        // A link draws its own underline, so the mark under it is the link rather than two marks.
        if (marks.has("link")) {
            marks.remove("underline")
        }

        return marks
    }

    private fun same(one: JSONObject, other: JSONObject): Boolean {
        if (one.length() != other.length()) {
            return false
        }

        for (name in one.keys()) {
            if (one.opt(name)?.toString() != other.opt(name)?.toString()) {
                return false
            }
        }

        return true
    }

    /** Turns a mark on or off over what is selected, which is what a toolbar asks for. */
    fun toggle(mark: String) {
        val from = selectionStart.coerceAtMost(selectionEnd)
        val to = selectionStart.coerceAtLeast(selectionEnd)
        val held = text as? Spannable ?: return

        if (from >= to) {
            return
        }

        val on = !marksAt(held, from, to).optBoolean(mark)
        val built = SpannableStringBuilder(held)

        strip(built, mark, from, to)

        if (on) {
            mark(built, JSONObject().put(mark, true), from, to)
        }

        replace(built, from, to)
    }

    /** Points what is selected at an address, or takes the address off it. */
    fun link(where: String?) {
        val from = selectionStart.coerceAtMost(selectionEnd)
        val to = selectionStart.coerceAtLeast(selectionEnd)
        val held = text as? Spannable ?: return

        if (from >= to) {
            return
        }

        val built = SpannableStringBuilder(held)

        strip(built, "link", from, to)

        if (where != null) {
            mark(built, JSONObject().put("link", where), from, to)
        }

        replace(built, from, to)
    }

    private fun strip(held: SpannableStringBuilder, mark: String, from: Int, to: Int) {
        for (span in held.getSpans(from, to, Any::class.java)) {
            val named = when (span) {
                is StyleSpan -> if (span.style == Typeface.BOLD) "bold" else "italic"
                is UnderlineSpan -> if (mark == "link") "link" else "underline"
                is StrikethroughSpan -> "strikethrough"
                is TypefaceSpan -> "code"
                is URLSpan -> "link"
                is ForegroundColorSpan -> "link"
                else -> null
            }

            if (named == mark) {
                held.removeSpan(span)
            }
        }
    }

    private fun replace(built: SpannableStringBuilder, from: Int, to: Int) {
        writing = true
        setText(built, BufferType.SPANNABLE)
        writing = false

        setSelection(from.coerceIn(0, built.length), to.coerceIn(0, built.length))

        runs = document()
        onDocument?.invoke(runs)
        report()
    }

    /** Says where the caret is and what is on there, which is what a toolbar draws itself from. */
    fun report() {
        val held = text as? Spannable ?: return
        val from = selectionStart.coerceAtMost(selectionEnd)
        val to = selectionStart.coerceAtLeast(selectionEnd)

        onSelection?.invoke(
            JSONObject()
                .put("start", from)
                .put("end", to)
                .put("marks", marksAt(held, from, to.coerceAtLeast(from + 1).coerceAtMost(held.length))),
        )
    }

    /** Hands what is selected to the system's own clipboard, or takes from it. */
    fun clipboard(method: String) {
        val chosen = when (method) {
            "copy" -> android.R.id.copy
            "cut" -> android.R.id.cut
            "selectAll" -> android.R.id.selectAll
            else -> android.R.id.paste
        }

        onTextContextMenuItem(chosen)
    }

    /** Answers whether the system holds anything that could be pasted, which a toolbar may ask. */
    fun holdsText(): Boolean {
        val manager = context.getSystemService(ClipboardManager::class.java) ?: return false

        return manager.hasPrimaryClip()
    }

    private fun plain(given: JSONArray): String {
        val built = StringBuilder()

        for (index in 0 until given.length()) {
            built.append(given.optJSONObject(index)?.optString("text", "") ?: "")
        }

        return built.toString()
    }

    private companion object {
        const val SAID = 64
    }
}
