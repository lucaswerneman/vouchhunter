package se.vouchhunter.app

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.widget.Button
import android.widget.TextView

/** Shared visual roles for the player app, including AR and error states. */
object HuntStyle {
    val canvas = Color.BLACK
    val surface = Color.rgb(31, 31, 31)
    val ink = Color.rgb(245, 245, 245)
    val muted = Color.rgb(185, 185, 185)
    val line = Color.rgb(120, 120, 120)
    val accent = Color.rgb(46, 242, 107)
    fun text(view: TextView, secondary: Boolean = false) {
        view.typeface = Typeface.MONOSPACE
        view.setTextColor(if (secondary) muted else ink)
    }
    fun button(view: Button) {
        val density = view.resources.displayMetrics.density
        text(view)
        view.isAllCaps = true
        view.minHeight = (52 * density).toInt()
        view.backgroundTintList = null
        view.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 28 * density
            color = ColorStateList(arrayOf(intArrayOf(-android.R.attr.state_enabled), intArrayOf()), intArrayOf(surface, accent))
        }
        view.setTextColor(ColorStateList(arrayOf(intArrayOf(-android.R.attr.state_enabled), intArrayOf()), intArrayOf(muted, Color.BLACK)))
        view.setPadding((20*density).toInt(), (12*density).toInt(), (20*density).toInt(), (12*density).toInt())
    }
}
