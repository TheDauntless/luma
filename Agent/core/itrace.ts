import {
    TraceBuffer,
    TraceBufferReader,
    TraceSession,
    type TraceStrategy,
} from "frida-itrace";

export type Origin =
    | { kind: "functionCall"; hookId: string; callIndex: number }
    | { kind: "thread"; threadId: number; threadName: string | null };

interface ActiveSession {
    sessionId: string;
    buffer: TraceBuffer;
    reader: TraceBufferReader;
    session: TraceSession;
}

const active = new Map<string, ActiveSession>();

export interface StartOptions {
    sessionId: string;
    origin: Origin;
    target: TraceStrategy;
    hookTarget?: string | null;
    prologueBytes?: ArrayBuffer | null;
}

export function startSession(opts: StartOptions): void {
    const buffer = TraceBuffer.create();
    const session = new TraceSession(opts.target, buffer);
    const reader = new TraceBufferReader(buffer);

    active.set(opts.sessionId, {
        sessionId: opts.sessionId,
        buffer,
        reader,
        session,
    });

    send({
        type: "itrace:start",
        sessionId: opts.sessionId,
        origin: opts.origin,
        bufferLocation: buffer.location,
        hookTarget: opts.hookTarget ?? null,
        prologueBytes: opts.prologueBytes !== undefined && opts.prologueBytes !== null
            ? bufferToHex(opts.prologueBytes)
            : null,
    });

    session.open();
}

export function stopSession(sessionId: string): void {
    const a = active.get(sessionId);
    if (a === undefined) {
        return;
    }
    active.delete(sessionId);

    a.session.close();
    const chunk = a.reader.read();

    send({
        type: "itrace:stop",
        sessionId,
        lost: a.reader.lost,
    }, chunk.byteLength > 0 ? chunk : null);
}

export function drainLocally(sessionId: string): void {
    const a = active.get(sessionId);
    if (a === undefined) {
        return;
    }
    const chunk = a.reader.read();
    if (chunk.byteLength > 0) {
        send({
            type: "itrace:chunk",
            sessionId,
            lost: a.reader.lost,
        }, chunk);
    }
}

export function startThreadTrace(opts: { sessionId: string; threadId: number; threadName: string | null }): void {
    startSession({
        sessionId: opts.sessionId,
        origin: { kind: "thread", threadId: opts.threadId, threadName: opts.threadName },
        target: { type: "thread", threadId: opts.threadId },
    });
}

export function stopThreadTrace(opts: { sessionId: string }): void {
    stopSession(opts.sessionId);
}

function bufferToHex(buf: ArrayBuffer): string {
    return Array.from(new Uint8Array(buf))
        .map(b => b.toString(16).padStart(2, "0"))
        .join("");
}
