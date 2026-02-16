/**
 * Creates an array of elements split into groups the length of size.
 */
export declare function chunk(array: any[], size?: number): any[][];

/**
 * Creates a duplicate-free version of an array.
 */
export declare function uniq(array: any[]): any[];

/**
 * Gets the value at path of object.
 */
export declare function get(object: any, path: string, defaultValue?: any): any;

/**
 * Checks if value is empty.
 */
export declare function isEmpty(value: any): boolean;

/**
 * Clamps number within the inclusive lower and upper bounds.
 */
export declare function clamp(number: number, lower: number, upper: number): number;
