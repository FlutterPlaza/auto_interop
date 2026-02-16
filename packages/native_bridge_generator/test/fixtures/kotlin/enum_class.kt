package com.example.enums

/**
 * HTTP request methods.
 */
enum class HttpMethod {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH
}

/**
 * Log severity levels.
 */
enum class LogLevel {
    /** Debug level logging. */
    DEBUG,
    /** Informational logging. */
    INFO,
    /** Warning level logging. */
    WARN,
    /** Error level logging. */
    ERROR
}
