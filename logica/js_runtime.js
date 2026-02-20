// ============================================================================
// Logica JS Runtime — Mary Kernel for JavaScript
// ============================================================================
// Generated code depends on this runtime.
// Every operation has a speaker. Every state change has a receipt.
// ============================================================================
"use strict";

// ── Status Constants ──
const Status = { ACTIVE: "active", INACTIVE: "inactive", BROKEN: "broken" };
const SpeakerStatus = { ALIVE: "alive", SUSPENDED: "suspended" };
const RequestStatus = { PENDING: "pending", ACCEPTED: "accepted", REFUSED: "refused" };

// ── Hash (FNV-1a, no dependencies) ──
function computeHash(data) {
    let hash = 0x811c9dc5;
    for (let i = 0; i < data.length; i++) {
        hash ^= data.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193);
    }
    return (hash >>> 0).toString(16).padStart(8, '0');
}

// ── Ledger (append-only, hash-chained) ──
class Ledger {
    constructor() {
        this._entries = [];
        this._lastHash = "genesis";
    }

    append(speakerId, operation, action, opts = {}) {
        const entry = {
            entryId: this._entries.length,
            speakerId,
            operation,
            action,
            condition: opts.condition || null,
            conditionResult: opts.conditionResult != null ? opts.conditionResult : null,
            status: opts.status || null,
            stateBefore: opts.stateBefore || null,
            stateAfter: opts.stateAfter || null,
            timestamp: Date.now() / 1000,
            prevHash: this._lastHash,
            entryHash: "",
            breakReason: opts.breakReason || null,
        };
        const hashData = `${entry.entryId}:${entry.speakerId}:${entry.operation}:${entry.action}:${entry.timestamp}:${entry.prevHash}`;
        entry.entryHash = computeHash(hashData);
        this._lastHash = entry.entryHash;
        this._entries.push(entry);
        return entry;
    }

    read(fromId = 0, toId = null) {
        if (toId === null) toId = this._entries.length;
        return this._entries.slice(fromId, toId);
    }

    verifyIntegrity() {
        if (this._entries.length === 0) return true;
        let expectedPrev = "genesis";
        for (const entry of this._entries) {
            if (entry.prevHash !== expectedPrev) return false;
            const hashData = `${entry.entryId}:${entry.speakerId}:${entry.operation}:${entry.action}:${entry.timestamp}:${entry.prevHash}`;
            if (entry.entryHash !== computeHash(hashData)) return false;
            expectedPrev = entry.entryHash;
        }
        return true;
    }

    count() { return this._entries.length; }
}

// ── Memory (speaker-partitioned) ──
class Memory {
    constructor() {
        this._partitions = {};
    }

    createPartition(speakerId) {
        if (!(speakerId in this._partitions)) {
            this._partitions[speakerId] = {};
        }
    }

    read(ownerId, varName) {
        const partition = this._partitions[ownerId] || {};
        return varName in partition ? partition[varName] : null;
    }

    write(callerId, varName, value) {
        if (!(callerId in this._partitions)) return [false, null];
        const oldValue = callerId in this._partitions && varName in this._partitions[callerId]
            ? this._partitions[callerId][varName] : null;
        this._partitions[callerId][varName] = value;
        return [true, oldValue];
    }

    listVars(ownerId) {
        return Object.keys(this._partitions[ownerId] || {});
    }
}

// ── Speaker Registry ──
class SpeakerRegistry {
    constructor() {
        this._speakers = {};
        this._nextId = 0;
    }

    create(name) {
        const speaker = {
            id: this._nextId,
            name,
            createdAt: Date.now() / 1000,
            status: SpeakerStatus.ALIVE,
        };
        this._speakers[speaker.id] = speaker;
        this._nextId++;
        return speaker;
    }

    get(id) { return this._speakers[id] || null; }

    authenticate(id) {
        const s = this._speakers[id];
        return s !== undefined && s.status === SpeakerStatus.ALIVE;
    }

    listAll() { return Object.values(this._speakers); }
}

// ── Request Bus ──
class RequestBus {
    constructor() {
        this._pending = [];
        this._resolved = [];
        this._nextId = 0;
    }

    createRequest(fromSpeaker, toSpeaker, action, data = null) {
        const req = {
            requestId: this._nextId++,
            fromSpeaker, toSpeaker, action, data,
            status: RequestStatus.PENDING,
            createdAt: Date.now() / 1000,
            responseData: null,
        };
        this._pending.push(req);
        return req;
    }

    respond(requestId, responderId, accept, responseData = null) {
        const idx = this._pending.findIndex(r => r.requestId === requestId);
        if (idx === -1) return null;
        const req = this._pending[idx];
        if (req.toSpeaker !== responderId) return null;
        req.status = accept ? RequestStatus.ACCEPTED : RequestStatus.REFUSED;
        req.responseData = responseData;
        this._pending.splice(idx, 1);
        this._resolved.push(req);
        return req;
    }

    getPendingFor(speakerId) {
        return this._pending.filter(r => r.toSpeaker === speakerId);
    }
}

// ── Mary (The Kernel) ──
class Mary {
    constructor() {
        this.registry = new SpeakerRegistry();
        this.memory = new Memory();
        this.ledger = new Ledger();
        this.bus = new RequestBus();

        // Boot: create root speaker
        this.root = this.registry.create("root");
        this.memory.createPartition(this.root.id);
        this.ledger.append(this.root.id, "boot", "mary_initialized", { status: Status.ACTIVE });
    }

    createSpeaker(callerId, name) {
        const speaker = this.registry.create(name);
        this.memory.createPartition(speaker.id);
        this.ledger.append(callerId, "create_speaker", `create:${name}`, {
            status: Status.ACTIVE,
            stateAfter: { newSpeakerId: speaker.id, name },
        });
        return speaker;
    }

    read(callerId, ownerId, varName) {
        const value = this.memory.read(ownerId, varName);
        this.ledger.append(callerId, "read", `read:${ownerId}.${varName}`, {
            status: Status.ACTIVE,
            stateAfter: { value: String(value) },
        });
        return value;
    }

    write(callerId, varName, value) {
        const [success, oldValue] = this.memory.write(callerId, varName, value);
        this.ledger.append(callerId, "write", `write:${varName}`, {
            status: success ? Status.ACTIVE : Status.BROKEN,
            stateBefore: { var: varName, oldValue: String(oldValue) },
            stateAfter: { var: varName, newValue: String(value) },
            breakReason: success ? null : "write_failed",
        });
        return success;
    }

    submit(speakerId, conditionLabel, action) {
        this.ledger.append(speakerId, "evaluate", action, {
            condition: conditionLabel,
            conditionResult: true,
            status: Status.ACTIVE,
        });
    }

    request(callerId, targetId, action) {
        const req = this.bus.createRequest(callerId, targetId, action);
        this.ledger.append(callerId, "request", `request:${targetId}:${action}`, {
            status: Status.ACTIVE,
            stateAfter: { requestId: req.requestId },
        });
        return req;
    }

    respond(callerId, requestId, accept) {
        const result = this.bus.respond(requestId, callerId, accept);
        this.ledger.append(callerId, "respond", `respond:${requestId}:${accept ? "accept" : "refuse"}`, {
            status: Status.ACTIVE,
            stateAfter: { requestId, accepted: accept },
        });
        return result !== null;
    }

    pendingRequests(callerId) {
        return this.bus.getPendingFor(callerId);
    }

    inspectSpeaker(callerId, targetId) {
        const speaker = this.registry.get(targetId);
        if (!speaker) return null;
        return {
            speaker: { id: speaker.id, name: speaker.name, status: speaker.status },
            variables: this.memory.listVars(targetId),
        };
    }

    inspectVariable(callerId, ownerId, varName) {
        const current = this.memory.read(ownerId, varName);
        const history = this.ledger.read().filter(
            e => e.speakerId === ownerId && e.action === `write:${varName}`
        );
        return { currentValue: current, history };
    }

    ledgerCount(callerId) { return this.ledger.count(); }
    ledgerRead(callerId, fromId, toId) { return this.ledger.read(fromId, toId); }
    ledgerVerify() { return this.ledger.verifyIntegrity(); }
}

// ── Context (Transpiler Runtime Helper) ──
class Context {
    constructor(mary) {
        this.mary = mary;
        this.speakers = {};
        this.currentSpeaker = null;
        this.currentSid = null;
        this.localScopes = [];
        this.functions = {};
        this.sealed = new Set();
        this.output = [];
    }

    createSpeaker(name) {
        this.speakers[name] = this.mary.createSpeaker(0, name);
    }

    setSpeaker(name) {
        this.currentSpeaker = name;
        this.currentSid = name ? this.speakers[name].id : null;
    }

    write(name, value) {
        const sealKey = `${this.currentSpeaker}.${name}`;
        if (this.sealed.has(sealKey)) {
            throw new Error(`variable '${name}' is sealed and cannot be modified`);
        }
        if (this.localScopes.length > 0) {
            this.localScopes[this.localScopes.length - 1][name] = value;
        }
        this.mary.write(this.currentSid, name, value);
    }

    resolve(name) {
        // Check local scopes first (innermost to outermost)
        for (let i = this.localScopes.length - 1; i >= 0; i--) {
            if (name in this.localScopes[i]) return this.localScopes[i][name];
        }
        // Check Mary memory (current speaker's partition)
        if (this.currentSid !== null) {
            const v = this.mary.memory.read(this.currentSid, name);
            if (v !== null) return v;
        }
        // Check if it's a speaker name
        if (name in this.speakers) return name;
        return null;
    }

    readFrom(speakerName, varName) {
        const ownerId = this.speakers[speakerName].id;
        return this.mary.read(this.currentSid, ownerId, varName);
    }

    speak(value) {
        const line = `  [${this.currentSpeaker}] ${value}`;
        this.output.push(line);
        console.log(line);
        this.mary.submit(this.currentSid, "speak", `speak:${JSON.stringify(value)}`);
    }

    defineFunction(speaker, name, fn) {
        this.functions[`${speaker}.${name}`] = fn;
    }

    callFunction(name, args) {
        // Look up: current speaker first, then any speaker
        let fn = this.functions[`${this.currentSpeaker}.${name}`];
        if (!fn) {
            for (const key of Object.keys(this.functions)) {
                if (key.endsWith(`.${name}`)) { fn = this.functions[key]; break; }
            }
        }
        if (!fn) return null;
        return fn(args);
    }

    pushScope(params = {}) {
        this.localScopes.push({ ...params });
    }

    popScope() {
        return this.localScopes.pop();
    }

    seal(name) {
        const sealKey = `${this.currentSpeaker}.${name}`;
        this.sealed.add(sealKey);
        this.mary.submit(this.currentSid, "seal", `seal:${name}`);
        console.log(`  [${this.currentSpeaker}] sealed: ${name}`);
    }

    requestTo(targetName, action) {
        const targetId = this.speakers[targetName].id;
        this.mary.request(this.currentSid, targetId, action);
        console.log(`  [${this.currentSpeaker}] request -> ${targetName}: ${action}`);
    }

    respondTo(accept) {
        const pending = this.mary.pendingRequests(this.currentSid);
        if (pending.length > 0) {
            const req = pending[0];
            this.mary.respond(this.currentSid, req.requestId, accept);
            const action = accept ? "accepted" : "refused";
            console.log(`  [${this.currentSpeaker}] ${action} request #${req.requestId}`);
        }
    }

    inspect(target) {
        if (typeof target === "string" && target in this.speakers) {
            const targetId = this.speakers[target].id;
            const info = this.mary.inspectSpeaker(this.currentSid, targetId);
            if (info) {
                console.log(`  --- inspect ${target} ---`);
                console.log(`  speaker: ${info.speaker.name} (#${info.speaker.id})`);
                console.log(`  status:  ${info.speaker.status}`);
                console.log(`  vars:    ${JSON.stringify(info.variables)}`);
                console.log(`  ---`);
            }
        } else if (Array.isArray(target) && target.length === 2) {
            const [speakerName, varName] = target;
            const ownerId = this.speakers[speakerName].id;
            const value = this.mary.memory.read(ownerId, varName);
            console.log(`  --- inspect ${speakerName}.${varName} ---`);
            console.log(`  value: ${value}`);
            console.log(`  ---`);
        }
    }

    history(speakerName, varName) {
        const ownerId = this.speakers[speakerName].id;
        const result = this.mary.inspectVariable(this.currentSid, ownerId, varName);
        if (result) {
            console.log(`  --- history ${speakerName}.${varName} ---`);
            console.log(`  current: ${result.currentValue}`);
            for (const h of result.history) {
                console.log(`    #${h.entryId}: ${JSON.stringify(h.stateBefore)} -> ${JSON.stringify(h.stateAfter)}`);
            }
            console.log(`  ---`);
        }
    }

    ledgerRead(count = null) {
        const total = this.mary.ledgerCount(this.currentSid);
        const n = count !== null ? Math.min(count, total) : total;
        const entries = this.mary.ledgerRead(this.currentSid, Math.max(0, total - n), total);
        console.log(`  --- ledger (last ${n} of ${total}) ---`);
        for (const e of entries) {
            const status = e.status || "-";
            const speakerName = this._speakerNameById(e.speakerId);
            console.log(`    #${e.entryId} [${String(status).padStart(8)}] ${speakerName}: ${e.action}`);
        }
        console.log(`  ---`);
    }

    verifyLedger() {
        const intact = this.mary.ledgerVerify();
        console.log(`  ledger integrity: ${intact ? "VALID" : "BROKEN"}`);
    }

    _speakerNameById(id) {
        for (const [name, speaker] of Object.entries(this.speakers)) {
            if (speaker.id === id) return name;
        }
        const s = this.mary.registry.get(id);
        return s ? s.name : `speaker_${id}`;
    }
}
