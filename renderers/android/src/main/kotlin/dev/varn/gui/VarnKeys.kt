package dev.varn.gui

import android.view.KeyEvent
import org.json.JSONObject

/**
 * The name each key is reported under, which is the one published set of names for them.
 *
 * A browser names a key in `KeyboardEvent.key`, iOS gives a HID usage and Android a key code, and the
 * three agree about nothing. The browser's names are what the tree reads, so the other two are mapped
 * onto them rather than each reporting whatever its own platform calls a key.
 */
object VarnKeys {
    private val NAMED = mapOf(
        KeyEvent.KEYCODE_ENTER to "Enter",
        KeyEvent.KEYCODE_NUMPAD_ENTER to "Enter",
        KeyEvent.KEYCODE_ESCAPE to "Escape",
        KeyEvent.KEYCODE_TAB to "Tab",
        KeyEvent.KEYCODE_DEL to "Backspace",
        KeyEvent.KEYCODE_FORWARD_DEL to "Delete",
        KeyEvent.KEYCODE_SPACE to " ",
        KeyEvent.KEYCODE_DPAD_UP to "ArrowUp",
        KeyEvent.KEYCODE_DPAD_DOWN to "ArrowDown",
        KeyEvent.KEYCODE_DPAD_LEFT to "ArrowLeft",
        KeyEvent.KEYCODE_DPAD_RIGHT to "ArrowRight",
        KeyEvent.KEYCODE_MOVE_HOME to "Home",
        KeyEvent.KEYCODE_MOVE_END to "End",
        KeyEvent.KEYCODE_PAGE_UP to "PageUp",
        KeyEvent.KEYCODE_PAGE_DOWN to "PageDown",
    )

    /** Answers what one key is called and what was held down with it. */
    fun payload(code: Int, key: KeyEvent): JSONObject {
        val named = NAMED[code] ?: written(key)

        return JSONObject()
            .put("key", named)
            .put("shift", key.isShiftPressed)
            .put("ctrl", key.isCtrlPressed)
            .put("alt", key.isAltPressed)
            .put("meta", key.isMetaPressed)
            .put("repeat", key.repeatCount > 0)
    }

    /** Answers the character a key stands for, or that nothing here knows what it is. */
    private fun written(key: KeyEvent): String {
        val character = key.getUnicodeChar(key.metaState)

        if (character == 0) {
            return "Unidentified"
        }

        return character.toChar().toString()
    }
}
