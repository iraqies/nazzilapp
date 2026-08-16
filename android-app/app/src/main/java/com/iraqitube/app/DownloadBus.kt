package com.iraqitube.app

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

object DownloadBus {
    private val _busy = MutableStateFlow(false)
    private val _progress = MutableStateFlow(0f)
    private val _error = MutableStateFlow("")
    private val _saved = MutableStateFlow<SavedVideo?>(null)
    private val _title = MutableStateFlow("")

    val busy: StateFlow<Boolean> = _busy
    val progress: StateFlow<Float> = _progress
    val error: StateFlow<String> = _error
    val saved: StateFlow<SavedVideo?> = _saved
    val title: StateFlow<String> = _title

    fun begin(title: String) {
        _title.value = title
        _error.value = ""
        _saved.value = null
        _progress.value = 0.02f
        _busy.value = true
    }

    fun progress(value: Float) {
        _progress.value = value.coerceIn(0f, 1f)
    }

    fun finish(item: SavedVideo) {
        _saved.value = item
        _progress.value = 1f
        _busy.value = false
        _error.value = ""
    }

    fun fail(message: String) {
        _error.value = message
        _busy.value = false
    }
}
