package com.example.extensions

class StringUtils {
    fun isEmpty(value: String): Boolean {
        return value.isEmpty()
    }
}

/** Trims whitespace from both ends. */
fun String.trimWhitespace(): String {
    return this.trim()
}

/** Repeats the string n times. */
fun String.repeat(count: Int): String {
    return this.repeat(count)
}

fun Int.isEven(): Boolean {
    return this % 2 == 0
}

/** Extension on a class defined in this file. */
fun StringUtils.reverse(input: String): String {
    return input.reversed()
}

suspend fun String.fetchRemote(url: String): String {
    return ""
}
