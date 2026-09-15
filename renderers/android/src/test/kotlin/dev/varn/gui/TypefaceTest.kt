package dev.varn.gui

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File

/**
 * Which face of a family draws a run of text.
 *
 * A family was kept as one typeface, so registering the three faces the framework ships left only the
 * last of them: every weight in the application was drawn in whichever file happened to register last,
 * and the system was then asked to thicken that one again.
 */
@RunWith(RobolectricTestRunner::class)
class TypefaceTest {
    private fun register(family: String, weight: Int, name: String) {
        val file = File.createTempFile(name, ".ttf")

        file.deleteOnExit()
        VarnStyle.registerFont(family, weight, file.path)
    }

    private fun typeface(family: String, weight: String) =
        VarnStyle.typeface(JSONObject().put("fontFamily", family).put("fontWeight", weight))

    @Test
    fun `each weight of a family is drawn in its own face`() {
        register("Ledger", 400, "ledger-regular")
        register("Ledger", 700, "ledger-bold")

        assertNotEquals(
            "a family keeps every face it was given",
            typeface("Ledger", "400"),
            typeface("Ledger", "700"),
        )
    }

    @Test
    fun `a weight no face carries is drawn in the nearest one`() {
        register("Almanac", 400, "almanac-regular")
        register("Almanac", 700, "almanac-bold")

        assertEquals(
            "a semibold is nearer the bold than the regular",
            typeface("Almanac", "700"),
            typeface("Almanac", "600"),
        )

        assertEquals(
            "and a light is nearer the regular",
            typeface("Almanac", "400"),
            typeface("Almanac", "300"),
        )
    }

    @Test
    fun `a family nobody registered is drawn in the system font`() {
        assertEquals(
            "a name that reached no file is not a family",
            VarnStyle.typeface(JSONObject().put("fontWeight", "400")),
            typeface("NothingWasRegisteredUnderThis", "400"),
        )
    }
}
