/** A class with function-type parameters. */
class EventBus {
    fun subscribe(event: String, handler: (String) -> Unit) {
    }

    fun transform(data: String, mapper: (String) -> Int): Int {
        return mapper(data)
    }
}
