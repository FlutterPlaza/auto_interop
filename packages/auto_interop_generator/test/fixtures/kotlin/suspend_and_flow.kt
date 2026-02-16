package com.example.async

import kotlinx.coroutines.flow.Flow

/**
 * Fetches data from the given URL.
 */
suspend fun fetchData(url: String): String {
    TODO()
}

/**
 * Downloads a file and returns the bytes.
 */
suspend fun downloadFile(url: String): ByteArray {
    TODO()
}

/**
 * Watches for changes and emits updates.
 */
fun watchChanges(path: String): Flow<String> {
    TODO()
}

/**
 * Returns a stream of log entries.
 */
fun streamLogs(): Flow<LogEntry> {
    TODO()
}

data class LogEntry(
    val timestamp: Long,
    val message: String,
    val level: String
)
