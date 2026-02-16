export declare function identity<T>(value: T): T;

export declare function mapValues<K extends string, V, R>(obj: Record<K, V>, fn: (value: V) => R): Record<K, R>;

export declare function toArray<T>(value: T | T[]): T[];

export declare function groupBy<T>(arr: T[], key: string): Record<string, T[]>;

export interface Collection<T> {
    items: T[];
    count: number;
    add(item: T): void;
    get(index: number): T | null;
    toArray(): T[];
}
