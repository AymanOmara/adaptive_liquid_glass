package com.aymanomara.adaptive_liquid_glass

import android.content.Context
import org.json.JSONArray

/** App-private saved colour palette; an empty list means all colours were deleted. */
internal class GlassSavedColors(context: Context) {
    private val preferences = context.getSharedPreferences("adaptive_liquid_glass", Context.MODE_PRIVATE)

    fun load(): List<Long>? {
        val encoded = preferences.getString("saved_colors", null) ?: return null
        val colors = JSONArray(encoded)
        return List(colors.length()) { colors.getLong(it) }
    }

    fun save(colors: List<Long>) {
        // A failed synchronous commit is reported through the channel. The caller
        // dispatches storage work off the platform thread.
        check(preferences.edit().putString("saved_colors", JSONArray(colors).toString()).commit()) {
            "Unable to save the colour palette."
        }
    }
}
