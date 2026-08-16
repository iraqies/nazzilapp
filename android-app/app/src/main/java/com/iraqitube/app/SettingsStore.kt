package com.iraqitube.app

import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import android.os.LocaleList
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import java.util.Locale

class SettingsStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var language: String
        get() = prefs.getString(KEY_LANG, LANG_SYSTEM) ?: LANG_SYSTEM
        set(value) {
            prefs.edit().putString(KEY_LANG, value).apply()
            applyLocale()
        }

    var stayInSettings: Boolean
        get() = prefs.getBoolean(KEY_STAY_SETTINGS, false)
        set(value) {
            prefs.edit().putBoolean(KEY_STAY_SETTINGS, value).apply()
        }

    fun consumeStayInSettings(): Boolean {
        val open = stayInSettings
        if (open) stayInSettings = false
        return open
    }

    fun applyLocale() {
        val locales = when (language) {
            LANG_EN -> LocaleListCompat.forLanguageTags("en")
            LANG_AR -> LocaleListCompat.forLanguageTags("ar")
            else -> LocaleListCompat.getEmptyLocaleList()
        }
        AppCompatDelegate.setApplicationLocales(locales)
    }

    companion object {
        const val LANG_SYSTEM = "system"
        const val LANG_EN = "en"
        const val LANG_AR = "ar"
        private const val PREFS = "nazzil"
        private const val KEY_LANG = "language"
        private const val KEY_STAY_SETTINGS = "stay_in_settings"

        fun languageOf(context: Context): String {
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_LANG, LANG_SYSTEM) ?: LANG_SYSTEM
        }

        fun localeFor(tag: String): Locale {
            return when (tag) {
                LANG_AR -> Locale("ar")
                LANG_EN -> Locale.ENGLISH
                else -> systemLocale()
            }
        }

        fun wrap(base: Context): Context {
            return base.withLocale(localeFor(languageOf(base)))
        }

        fun systemLocale(): Locale {
            val list = Resources.getSystem().configuration.locales
            return if (list.isEmpty) Locale.getDefault() else list[0]
        }
    }
}

fun Context.withLocale(locale: Locale): Context {
    val config = Configuration(resources.configuration)
    config.setLocales(LocaleList(locale))
    config.setLayoutDirection(locale)
    return createConfigurationContext(config)
}
