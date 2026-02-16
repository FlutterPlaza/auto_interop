package com.example;

/**
 * Builder for configuring Gson instances.
 */
public class GsonBuilder {
    /**
     * Enables pretty printing for JSON output.
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
     * Sets whether to serialize null values.
     */
    public GsonBuilder serializeNulls(boolean serialize) {
        return this;
    }

    /**
     * Builds the Gson instance.
     */
    public Gson create() {
        return null;
    }
}
