package com.example.singleton

/** A singleton logger utility. */
object Logger {
    val tag: String = "APP"

    fun info(message: String): Unit {
    }

    fun error(message: String, code: Int): Unit {
    }

    private fun formatMessage(msg: String): String {
        return msg
    }
}

object Constants {
    val baseUrl: String = "https://api.example.com"
    val timeout: Int = 30
    val debug: Boolean = false
}
