/** The main processor. */
export default class Processor {
    /** Runs the processor. */
    run(input: string): string;
}

/** A default exported helper function. */
export default function createProcessor(config: string): Processor;
