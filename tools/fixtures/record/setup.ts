// Vitest's globals (`test.globals`) give afterAll without importing vitest, which does not resolve from this folder.
import { flushRecording } from "./recorder.ts";

declare const afterAll: (fn: () => void) => void;
afterAll(() => flushRecording());
