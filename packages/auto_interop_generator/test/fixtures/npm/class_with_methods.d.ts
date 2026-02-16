/**
 * HTTP client for making requests.
 */
export declare class HttpClient {
    /**
     * Creates a new HttpClient with the given base URL.
     */
    constructor(baseUrl: string);

    /**
     * Sends a GET request.
     */
    get(url: string): Promise<Response>;

    /**
     * Sends a POST request.
     */
    post(url: string, body: string): Promise<Response>;

    /**
     * Closes the client.
     */
    close(): void;
}

export interface Response {
    status: number;
    body: string;
    headers: Record<string, string>;
}
