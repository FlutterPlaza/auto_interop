package com.example.multiline

/** A top-level function with params spanning multiple lines. */
fun createRequest(
    url: String,
    method: String,
    headers: Map<String, String>
): Request {
    return Request(url, method, headers)
}

/** Suspend function with multi-line params. */
suspend fun fetchData(
    url: String,
    timeout: Int = 30
): String {
    return ""
}

class ApiClient {
    /** Method with multi-line params. */
    fun sendRequest(
        url: String,
        body: ByteArray?,
        headers: Map<String, String>
    ): Response {
        return Response()
    }

    companion object {
        /** Companion method with multi-line params. */
        fun create(
            baseUrl: String,
            timeout: Int
        ): ApiClient {
            return ApiClient()
        }
    }
}

interface RequestHandler {
    /** Interface method with multi-line params. */
    fun handle(
        request: Request,
        callback: String
    ): Response
}
