package com.example.annotations

class AnnotatedService {
    @JvmStatic
    fun staticMethod(): String {
        return ""
    }

    @Throws(IOException::class)
    suspend fun riskyOperation(input: String): Boolean {
        return true
    }

    @Deprecated("Use newMethod instead")
    fun oldMethod(): Unit {
    }

    fun normalMethod(data: String): Int {
        return 0
    }

    private fun secretMethod(): Unit {
    }

    internal fun internalMethod(): Unit {
    }

    protected fun protectedMethod(): Unit {
    }
}

/** An annotated top-level function. */
@JvmStatic
fun annotatedTopLevel(name: String): String {
    return name
}

internal fun internalTopLevel(): Unit {
}

protected fun protectedTopLevel(): Unit {
}

/** A function with complex annotation. */
@Suppress("UNCHECKED_CAST")
fun suppressedFunction(value: Int): Boolean {
    return true
}
