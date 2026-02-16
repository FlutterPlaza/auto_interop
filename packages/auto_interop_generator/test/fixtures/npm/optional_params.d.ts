export declare function greet(name: string, greeting?: string): string;

export declare function configure(options?: {
    timeout?: number;
    retries?: number;
    verbose?: boolean;
}): void;

export declare function fetch(url: string, options?: RequestOptions): Promise<string>;

export interface RequestOptions {
    method?: string;
    headers?: Record<string, string>;
    body?: string;
    timeout?: number;
}
