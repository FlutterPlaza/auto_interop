package com.example.result

/**
 * Represents the result of an operation.
 */
sealed class Result {
    data class Success(val data: String) : Result()
    data class Failure(val error: String, val code: Int) : Result()
    object Loading : Result()
}
