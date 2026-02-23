/** A class with callback parameters in methods. */
export declare class EventEmitter {
    /** Registers an event handler. */
    on(event: string, handler: (data: string) => void): void;
    /** Transforms with a mapper callback. */
    map(fn: (item: number, index: number) => string): string[];
}
