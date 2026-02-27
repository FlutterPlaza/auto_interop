package com.example.overloads

/** First overload - takes a String. */
fun process(input: String): String {
    return input
}

/** Second overload - takes an Int (should be deduplicated). */
fun process(input: Int): Int {
    return input
}

fun uniqueFunction(data: String): Boolean {
    return true
}

/** Another overloaded function. */
fun convert(value: String): Int {
    return 0
}

fun convert(value: Double): String {
    return ""
}
