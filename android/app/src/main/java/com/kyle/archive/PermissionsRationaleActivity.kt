package com.kyle.archive

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val scrollView = ScrollView(this)
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.START
            setPadding(dp(24), dp(32), dp(24), dp(32))
            setBackgroundColor(Color.WHITE)
        }

        container.addView(
            TextView(this).apply {
                text = "Archive health data access"
                textSize = 26f
                setTextColor(Color.rgb(18, 18, 18))
                typeface = Typeface.DEFAULT_BOLD
                includeFontPadding = false
            },
        )

        container.addView(
            bodyText(
                "Archive asks Health Connect for read-only access to steps, sleep, workouts, distance, active calories, heart rate, HRV, and floors climbed so your Samsung watch data can fill the app automatically.",
                topMargin = 18,
            ),
        )
        container.addView(
            bodyText(
                "This data is stored inside Archive's local app storage for your personal tracking, scoring, and coaching views. Archive does not hard-code API keys and does not send Health Connect records to a server as part of this local import flow.",
                topMargin = 14,
            ),
        )
        container.addView(
            bodyText(
                "You can grant or remove these permissions from Health Connect at any time. If you deny access, Archive still works normally; the watch-data layers will simply stay empty until permission is granted.",
                topMargin = 14,
            ),
        )

        scrollView.addView(container)
        setContentView(scrollView)
    }

    private fun bodyText(textValue: String, topMargin: Int): TextView {
        return TextView(this).apply {
            text = textValue
            textSize = 17f
            setLineSpacing(4f, 1.0f)
            setTextColor(Color.rgb(82, 82, 82))
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            params.setMargins(0, dp(topMargin), 0, 0)
            layoutParams = params
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
