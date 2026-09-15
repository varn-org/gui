package dev.varn.gui

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Puts a file where the system keeps pictures and films, which is what a phone means by kept.
 *
 * It is written through the store the gallery reads rather than into a directory of the application's,
 * so what a reader kept is there for every other application too and outlives this one being removed.
 * The store is also what gives a file an address anything else may open, which is what sharing needs.
 */
object VarnLibrary {
    /// Where the store keeps each kind, since a sound is neither a picture nor a film.
    private data class Shelf(val collection: Uri, val folder: String)

    private fun shelf(file: File): Shelf = when (file.extension.lowercase()) {
        "mp4", "mov", "m4v", "webm" ->
            Shelf(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, Environment.DIRECTORY_MOVIES)

        "m4a", "mp3", "wav", "ogg", "aac" ->
            Shelf(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, Environment.DIRECTORY_MUSIC)

        else ->
            Shelf(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, Environment.DIRECTORY_PICTURES)
    }

    fun keep(context: Context, file: File): Uri {
        val shelf = shelf(file)
        val values = ContentValues()

        values.put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
        values.put(MediaStore.MediaColumns.MIME_TYPE, type(file))

        // A store older than the one that owns its own folders is told where to put it instead, since
        // the relative path it takes is not a column it has.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.MediaColumns.RELATIVE_PATH, shelf.folder)
        }

        val into = shelf.collection

        val kept = context.contentResolver.insert(into, values)
            ?: throw VarnRendererException("the store would not take the file")

        context.contentResolver.openOutputStream(kept).use { out ->
            if (out == null) {
                throw VarnRendererException("the store gave nowhere to write")
            }

            file.inputStream().use { source -> source.copyTo(out) }
        }

        return kept
    }

    /** Hands what was kept to whatever the reader chooses to send it with. */
    fun share(context: Context, kept: Uri, file: File, title: String?): Intent {
        val send = Intent(Intent.ACTION_SEND)

        send.type = type(file)
        send.putExtra(Intent.EXTRA_STREAM, kept)
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        return Intent.createChooser(send, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    private fun type(file: File): String = when (file.extension.lowercase()) {
        "png" -> "image/png"
        "jpg", "jpeg" -> "image/jpeg"
        "mp4", "m4v" -> "video/mp4"
        "mov" -> "video/quicktime"
        "webm" -> "video/webm"
        "m4a" -> "audio/mp4"
        else -> "application/octet-stream"
    }
}
