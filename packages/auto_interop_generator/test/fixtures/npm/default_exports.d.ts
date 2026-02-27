export default interface Config {
    host: string;
    port: number;
    debug?: boolean;
}

export declare interface Logger {
    log(message: string): void;
    error(message: string, code: number): void;
}

export type Options = {
    timeout: number;
    retries: number;
};

export enum Status {
    Active = "active",
    Inactive = "inactive",
    Pending = "pending",
}
