package com.example.visibility

class PublicService {
    fun publicMethod(input: String): String {
        return _transform(input)
    }

    private fun _transform(input: String): String {
        return input.uppercase()
    }

    internal fun internalHelper(): Unit {
    }
}

private class PrivateHelper {
    fun doWork(): String {
        return ""
    }
}

fun publicFunction(name: String): String {
    return name
}

private fun privateFunction(): Unit {
}
