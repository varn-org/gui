package dev.varn.gui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.view.View
import org.json.JSONArray

/** Draws the commands a canvas node carries, which is the one place Lua describes pixels rather than widgets. */
class VarnCanvasView(context: Context) : View(context) {
    private val density = context.resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    var commands: JSONArray = JSONArray()
        set(value) {
            field = value
            invalidate()
        }

    override fun onDraw(canvas: Canvas) {
        for (index in 0 until commands.length()) {
            val command = commands.optJSONObject(index) ?: continue

            when (command.optString("op")) {
                "fill", "stroke" -> drawPath(canvas, command)
                "text" -> drawText(canvas, command)
            }
        }
    }

    private fun drawPath(canvas: Canvas, command: org.json.JSONObject) {
        val points = command.optJSONArray("path") ?: return
        if (points.length() < 2) {
            return
        }

        val path = Path()
        for (index in 0 until points.length()) {
            val point = points.optJSONArray(index) ?: continue
            val x = (point.optDouble(0) * density).toFloat()
            val y = (point.optDouble(1) * density).toFloat()

            if (index == 0) {
                path.moveTo(x, y)
            } else {
                path.lineTo(x, y)
            }
        }

        paint.color = VarnStyle.color(command.opt("color")) ?: android.graphics.Color.BLACK

        if (command.optString("op") == "fill") {
            path.close()
            paint.style = Paint.Style.FILL
        } else {
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = (command.optDouble("width", 1.0) * density).toFloat()
        }

        canvas.drawPath(path, paint)
    }

    private fun drawText(canvas: Canvas, command: org.json.JSONObject) {
        paint.style = Paint.Style.FILL
        paint.color = VarnStyle.color(command.opt("color")) ?: android.graphics.Color.BLACK
        paint.textSize = (command.optDouble("size", 15.0) * density).toFloat()

        canvas.drawText(
            command.optString("text"),
            (command.optDouble("x") * density).toFloat(),
            (command.optDouble("y") * density).toFloat(),
            paint,
        )
    }
}
