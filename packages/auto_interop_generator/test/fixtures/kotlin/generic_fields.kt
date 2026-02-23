/** A class with complex generic field types. */
class ConfigStore {
    val headers: Map<String, String> = emptyMap()
    val settings: Map<String, List<String>> = emptyMap()
    var timeout: Long = 30000

    fun getHeader(key: String): String? {
        return headers[key]
    }
}
