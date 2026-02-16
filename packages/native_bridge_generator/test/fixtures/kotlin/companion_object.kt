package com.example.factory

/**
 * Represents a request body.
 */
class RequestBody private constructor(val content: String) {
    companion object {
        /**
         * Creates a request body from a string.
         */
        fun fromString(content: String): RequestBody {
            TODO()
        }

        /**
         * Creates a request body from bytes.
         */
        fun fromBytes(content: ByteArray): RequestBody {
            TODO()
        }

        /**
         * Creates an empty request body.
         */
        fun empty(): RequestBody {
            TODO()
        }
    }
}
