package com.example.model

/**
 * Represents an HTTP response.
 */
data class Response(
    val code: Int,
    val message: String,
    val body: String?,
    val headers: Map<String, String>
)

/**
 * Represents an HTTP request.
 */
data class Request(
    val url: String,
    val method: String = "GET",
    val headers: Map<String, String> = emptyMap(),
    val body: ByteArray? = null
)
