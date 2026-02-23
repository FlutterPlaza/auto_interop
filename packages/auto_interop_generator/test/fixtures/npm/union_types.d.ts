/**
 * Functions with union types.
 */

/** Parses input that can be string or number. */
export declare function parseInput(value: string | number): string;

/** Returns nullable result. */
export declare function findItem(id: string): string | null;

/** Returns a complex union. */
export declare function convert(data: Buffer | string | null): string;
