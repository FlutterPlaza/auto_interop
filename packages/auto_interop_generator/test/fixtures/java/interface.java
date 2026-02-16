package com.google.gson;

/**
 * Represents a JSON element.
 */
public interface JsonElement {
    /**
     * Checks if this element is a JSON array.
     */
    boolean isJsonArray();

    /**
     * Checks if this element is a JSON object.
     */
    boolean isJsonObject();

    /**
     * Returns this element as a string.
     */
    String getAsString();

    /**
     * Returns this element as an integer.
     */
    int getAsInt();

    /**
     * Returns this element as a double.
     */
    double getAsDouble();
}
