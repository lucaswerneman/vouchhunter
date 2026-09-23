package se.vouchhunter.app

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.widget.Button
import android.widget.TextView

/** Shared visual roles for the player app, including AR and error states. */
object HuntStyle {
    val canvas = Color.rgb(245, 245, 245)
    val surface = Color.WHITE
    val ink = Color.rgb(22, 22, 22)
    val muted = Color.rgb(104, 104, 104)
    val line = Color.rgb(222, 222, 222)
    val accent = Color.rgb(36, 36, 36)
    fun text(view: TextView, secondary: Boolean = false) {
        view.typeface = Typeface.DEFAULT
        view.setTextColor(if (secondary) muted else ink)
    }
    fun button(view: Button) {
        val density = view.resources.displayMetrics.density
        text(view)
        view.isAllCaps = false
        view.minHeight = (52 * density).toInt()
        view.backgroundTintList = null
        view.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 28 * density
            color = ColorStateList(arrayOf(intArrayOf(-android.R.attr.state_enabled), intArrayOf()), intArrayOf(surface, accent))
        }
        view.setTextColor(ColorStateList(arrayOf(intArrayOf(-android.R.attr.state_enabled), intArrayOf()), intArrayOf(muted, Color.WHITE)))
        view.setPadding((20*density).toInt(), (12*density).toInt(), (20*density).toInt(), (12*density).toInt())
    }
}
