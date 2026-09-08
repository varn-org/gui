package dev.varn.gui

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Base64
import android.widget.Button
import org.json.JSONObject

/**
 * The button that opens the chooser the system ships and reports what came back.
 *
 * A chooser is an activity, and an activity's result belongs to the activity that started it, so the
 * button does not start one itself: it asks the host, the host asks the application, and the
 * application hands the result back the same way it hands over the back press. Nothing here holds an
 * activity, which is what would leak one on a rotation.
 */
class VarnFilePicker(context: Context) : Button(context) {
    private var kind = "file"
    private var accept: List<String> = emptyList()
    private var multiple = false
    private var limit = 8 * 1024 * 1024

    /** Asked with the intent to start, and answered later through [chosen]. */
    var onOpen: ((VarnFilePicker, Intent) -> Unit)? = null

    var onPick: ((JSONObject) -> Unit)? = null

    init {
        setOnClickListener { open() }
    }

    fun setKind(value: String?) {
        kind = value ?: "file"
    }

    fun setAccept(value: List<String>) {
        accept = value
    }

    fun setMultiple(value: Boolean) {
        multiple = value
    }

    fun setMaxBytes(value: Int) {
        limit = value
    }

    /**
     * Answers the types the chooser offers, which is everything when the tree named none.
     *
     * An entry with a slash in it is a mime type and anything else is an extension, since those are the
     * two ways a caller writes one and neither is worth a prop of its own.
     */
    private fun types(): Array<String> {
        val named = accept.map { entry ->
            if (entry.contains("/")) entry else "application/${entry.trimStart('.')}"
        }

        if (named.isNotEmpty()) {
            return named.toTypedArray()
        }

        return if (kind == "image") arrayOf("image/*") else arrayOf("*/*")
    }

    private fun open() {
        val offered = types()
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)

        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.type = offered.first()
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)

        if (offered.size > 1) {
            intent.putExtra(Intent.EXTRA_MIME_TYPES, offered)
        }

        onOpen?.invoke(this, intent)
    }

    /**
     * Reads what was chosen and reports each one as it is ready.
     *
     * Gathering the whole set first put the bytes of every photograph into one message, which is decoded
     * and written in a single turn of the loop: nothing moved until the last one landed.
     */
    fun chosen(uris: List<Uri>) {
        for (uri in uris) {
            onPick?.invoke(entry(uri))
        }
    }

    private fun entry(uri: Uri): JSONObject {
        val resolver = context.contentResolver
        var name = uri.lastPathSegment ?: "file"
        var size = 0L

        resolver.query(uri, null, null, null, null)?.use { row ->
            val named = row.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            val measured = row.getColumnIndex(OpenableColumns.SIZE)

            if (row.moveToFirst()) {
                if (named >= 0) {
                    name = row.getString(named)
                }

                if (measured >= 0 && !row.isNull(measured)) {
                    size = row.getLong(measured)
                }
            }
        }

        val entry = JSONObject()
            .put("name", name)
            .put("size", size)
            .put("type", resolver.getType(uri) ?: "application/octet-stream")

        if (size > limit) {
            return entry.put("bytes", JSONObject.NULL)
        }

        val bytes = runCatching { resolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()

        if (bytes == null || bytes.size > limit) {
            return entry.put("size", bytes?.size ?: size).put("bytes", JSONObject.NULL)
        }

        return entry.put("size", bytes.size).put("bytes", Base64.encodeToString(bytes, Base64.NO_WRAP))
    }
}
