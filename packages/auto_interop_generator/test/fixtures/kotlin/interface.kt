package com.example.contracts

/**
 * Callback interface for asynchronous operations.
 */
interface Callback {
    fun onSuccess(data: String)
    fun onError(error: String, code: Int)
}

/**
 * Repository for data access.
 */
interface Repository {
    suspend fun findById(id: String): String?
    suspend fun save(data: String): Boolean
    fun getAll(): List<String>
}
