/** A class with method overloads. */
class OverloadedService {
    /** Fetches data by ID. */
    fun fetch(id: String): String {
        return ""
    }

    /** Fetches data by ID with timeout. */
    fun fetch(id: String, timeout: Int): String {
        return ""
    }

    fun transform(data: String): String {
        return ""
    }
}
