package com.squareup.okhttp3

/**
 * HTTP client for making network requests.
 */
class OkHttpClient {
    /**
     * Creates a new call for the given request.
     */
    fun newCall(request: Request): Call {
        TODO()
    }

    /**
     * Closes the client and releases resources.
     */
    fun close() {
    }
}

/**
 * Represents an HTTP request.
 */
data class Request(
    val url: String,
    val method: String,
    val headers: Map<String, String>,
    val body: String?
)

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
 * HTTP request methods.
 */
enum class HttpMethod {
    GET,
    POST,
    PUT,
    DELETE
}

/**
 * Represents an in-progress HTTP call.
 */
interface Call {
    /**
     * Executes the request synchronously.
     */
    suspend fun execute(): Response

    /**
     * Cancels the request.
     */
    fun cancel()
}
