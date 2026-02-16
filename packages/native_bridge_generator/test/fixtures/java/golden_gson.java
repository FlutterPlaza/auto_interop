package com.google.gson;

/**
 * Main class for JSON serialization and deserialization.
 */
public class Gson {
    /**
     * Deserializes a JSON string into an object.
     */
    public String fromJson(String json) {
        return null;
    }

    /**
     * Serializes an object to a JSON string.
     */
    public String toJson(String src) {
        return null;
    }
}

/**
 * Builder for configuring Gson instances.
 */
public class GsonBuilder {
    /**
     * Enables pretty printing.
     */
    public GsonBuilder setPrettyPrinting() {
        return this;
    }

    /**
     * Sets the date format pattern.
     */
    public GsonBuilder setDateFormat(String pattern) {
        return this;
    }

    /**
     * Builds the Gson instance.
     */
    public Gson create() {
        return null;
    }
}

/**
 * Represents a JSON element.
 */
public interface JsonElement {
    /**
     * Returns this element as a string.
     */
    String getAsString();

    /**
     * Returns this element as an integer.
     */
    int getAsInt();

    /**
     * Checks if this element is a JSON object.
     */
    boolean isJsonObject();
}
