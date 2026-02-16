/**
 * Generates a v4 (random) UUID.
 */
export declare function v4(): string;

/**
 * Generates a v5 (namespace) UUID.
 */
export declare function v5(name: string, namespace: string): string;

/**
 * Validates a UUID string.
 */
export declare function validate(uuid: string): boolean;

/**
 * Detects the version of a UUID.
 */
export declare function version(uuid: string): number;
