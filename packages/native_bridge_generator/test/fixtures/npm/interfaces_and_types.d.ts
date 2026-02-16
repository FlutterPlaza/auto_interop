export interface FormatOptions {
    locale?: string;
    weekStartsOn?: number;
    useAdditionalWeekYearTokens?: boolean;
}

export interface DateRange {
    start: Date;
    end: Date;
}

export type Locale = {
    code: string;
    formatDistance: (token: string, count: number) => string;
};
