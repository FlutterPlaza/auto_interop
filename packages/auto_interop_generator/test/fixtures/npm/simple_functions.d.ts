/**
 * Formats a date according to the given format string.
 */
export declare function format(date: Date, formatStr: string): string;

/**
 * Adds the specified number of days to the given date.
 */
export declare function addDays(date: Date, amount: number): Date;

/**
 * Returns the number of calendar days between two dates.
 */
export declare function differenceInDays(dateLeft: Date, dateRight: Date): number;
