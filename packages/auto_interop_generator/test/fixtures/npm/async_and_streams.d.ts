export declare function fetchData(url: string): Promise<string>;

export declare function fetchJson<T>(url: string): Promise<T>;

export declare function downloadFile(url: string): Promise<Buffer>;

export declare function watchChanges(path: string): ReadableStream<string>;

export declare function streamEvents(channel: string): ReadableStream<Event>;

export interface Event {
    type: string;
    data: any;
    timestamp: Date;
}
