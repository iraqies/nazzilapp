package com.iraqitube.app

import android.text.Html

object HtmlText {
    private val igSuffix = Regex("""\s*[•·]\s*Instagram.*$""", RegexOption.IGNORE_CASE)
    private val igHandle = Regex("""@([A-Za-z0-9._]+)""")
    private val igParenHandle = Regex("""\s*\(@[A-Za-z0-9._]+\)\s*""")

    fun decode(raw: String?): String {
        val value = raw.orEmpty()
            .replace("\\u0026", "&")
            .replace("\\/", "/")
            .replace("\\\"", "\"")
            .trim()
        if (value.isEmpty()) return ""
        return Html.fromHtml(value, Html.FROM_HTML_MODE_LEGACY)
            .toString()
            .replace('\u00A0', ' ')
            .trim()
    }

    fun instagram(raw: String?): Pair<String, String?> {
        val text = decode(raw)
        val author = igHandle.find(text)?.groupValues?.get(1)
        val title = text
            .replace(igSuffix, "")
            .replace(igParenHandle, " ")
            .replace(Regex("""\s+"""), " ")
            .trim()
            .ifBlank { "Instagram video" }
        return title to author
    }
}
