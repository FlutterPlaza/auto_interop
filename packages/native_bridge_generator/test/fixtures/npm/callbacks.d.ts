export declare function forEach<T>(arr: T[], callback: (item: T, index: number) => void): void;

export declare function map<T, R>(arr: T[], fn: (item: T) => R): R[];

export declare function addEventListener(event: string, handler: (data: any) => void): void;

export declare function createTimer(ms: number, callback: () => void): number;

export interface EventEmitter {
    on(event: string, listener: (...args: any[]) => void): void;
    off(event: string, listener: (...args: any[]) => void): void;
    emit(event: string, ...args: any[]): void;
}
