/*
 * Mary — A Kernel for Human Logic (C Implementation)
 * ===================================================
 * Every operation has a speaker. Every state change has a receipt.
 */

#include "mary.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* ── FNV-1a Hash (matches JS runtime) ──────────────────────────── */

void compute_hash(const char* data, char* out) {
    uint32_t hash = 0x811c9dc5u;
    for (int i = 0; data[i] != '\0'; i++) {
        hash ^= (uint8_t)data[i];
        hash *= 0x01000193u;
    }
    snprintf(out, MARY_HASH_LEN, "%08x", hash);
}

/* ── Internal: find variable index in partition ────────────────── */

static int _find_var(Partition* p, const char* name) {
    for (int i = 0; i < p->count; i++) {
        if (strcmp(p->keys[i], name) == 0) {
            return i;
        }
    }
    return -1;
}

/* ── Internal: get current timestamp (simplified for WASM) ─────── */

static double _timestamp(void) {
    /* In WASM/WASI, we use a simple counter for deterministic output */
    static double t = 1740000000.0;
    t += 0.001;
    return t;
}

/* ── Core Functions ─────────────────────────────────────────────── */

void mary_init(Mary* m) {
    memset(m, 0, sizeof(Mary));
    strcpy(m->last_hash, "genesis");

    /* Create root speaker (id 0) */
    m->speakers[0].id = 0;
    strcpy(m->speakers[0].name, "root");
    m->speakers[0].created_at = _timestamp();
    m->speakers[0].status = MARY_SPEAKER_ALIVE;
    m->speaker_count = 1;
    m->partitions[0].count = 0;

    /* Log boot */
    mary_ledger_append(m, 0, "boot", "mary_initialized", MARY_STATUS_ACTIVE);
}

int mary_create_speaker(Mary* m, int caller_id, const char* name) {
    if (m->speaker_count >= MARY_MAX_SPEAKERS) return -1;
    if (caller_id < 0 || caller_id >= m->speaker_count) return -1;
    if (m->speakers[caller_id].status != MARY_SPEAKER_ALIVE) return -1;

    int id = m->speaker_count;
    m->speakers[id].id = id;
    strncpy(m->speakers[id].name, name, MARY_NAME_LEN - 1);
    m->speakers[id].name[MARY_NAME_LEN - 1] = '\0';
    m->speakers[id].created_at = _timestamp();
    m->speakers[id].status = MARY_SPEAKER_ALIVE;
    m->partitions[id].count = 0;
    m->speaker_count++;

    /* Log creation */
    char action[MARY_ACTION_LEN];
    snprintf(action, sizeof(action), "create:%s", name);
    mary_ledger_append(m, caller_id, "create_speaker", action, MARY_STATUS_ACTIVE);

    return id;
}

int mary_write(Mary* m, int caller_id, const char* var, double value) {
    if (caller_id < 0 || caller_id >= m->speaker_count) return 0;
    if (m->speakers[caller_id].status != MARY_SPEAKER_ALIVE) return 0;

    /* Check seal */
    if (mary_is_sealed(m, caller_id, var)) return 0;

    Partition* p = &m->partitions[caller_id];
    int idx = _find_var(p, var);

    if (idx < 0) {
        /* New variable */
        if (p->count >= MARY_MAX_VARS) return 0;
        idx = p->count;
        strncpy(p->keys[idx], var, MARY_NAME_LEN - 1);
        p->keys[idx][MARY_NAME_LEN - 1] = '\0';
        p->count++;
    }

    p->num_values[idx] = value;
    p->str_values[idx][0] = '\0';
    p->types[idx] = MARY_TYPE_NUM;

    /* Log write */
    char action[MARY_ACTION_LEN];
    snprintf(action, sizeof(action), "write:%s", var);
    mary_ledger_append(m, caller_id, "write", action, MARY_STATUS_ACTIVE);

    return 1;
}

int mary_write_str(Mary* m, int caller_id, const char* var, const char* value) {
    if (caller_id < 0 || caller_id >= m->speaker_count) return 0;
    if (m->speakers[caller_id].status != MARY_SPEAKER_ALIVE) return 0;

    /* Check seal */
    if (mary_is_sealed(m, caller_id, var)) return 0;

    Partition* p = &m->partitions[caller_id];
    int idx = _find_var(p, var);

    if (idx < 0) {
        if (p->count >= MARY_MAX_VARS) return 0;
        idx = p->count;
        strncpy(p->keys[idx], var, MARY_NAME_LEN - 1);
        p->keys[idx][MARY_NAME_LEN - 1] = '\0';
        p->count++;
    }

    p->num_values[idx] = 0.0;
    strncpy(p->str_values[idx], value, MARY_STR_LEN - 1);
    p->str_values[idx][MARY_STR_LEN - 1] = '\0';
    p->types[idx] = MARY_TYPE_STR;

    /* Log write */
    char action[MARY_ACTION_LEN];
    snprintf(action, sizeof(action), "write:%s", var);
    mary_ledger_append(m, caller_id, "write", action, MARY_STATUS_ACTIVE);

    return 1;
}

double mary_read_num(Mary* m, int caller_id, int owner_id, const char* var) {
    if (owner_id < 0 || owner_id >= m->speaker_count) return 0.0;

    Partition* p = &m->partitions[owner_id];
    int idx = _find_var(p, var);
    if (idx < 0) return 0.0;

    /* Log read */
    char action[MARY_ACTION_LEN];
    snprintf(action, sizeof(action), "read:%d.%s", owner_id, var);
    mary_ledger_append(m, caller_id, "read", action, MARY_STATUS_ACTIVE);

    if (p->types[idx] == MARY_TYPE_STR) {
        return atof(p->str_values[idx]);
    }
    return p->num_values[idx];
}

const char* mary_read_str(Mary* m, int caller_id, int owner_id, const char* var) {
    if (owner_id < 0 || owner_id >= m->speaker_count) return "";

    Partition* p = &m->partitions[owner_id];
    int idx = _find_var(p, var);
    if (idx < 0) return "";

    /* Log read */
    char action[MARY_ACTION_LEN];
    snprintf(action, sizeof(action), "read:%d.%s", owner_id, var);
    mary_ledger_append(m, caller_id, "read", action, MARY_STATUS_ACTIVE);

    if (p->types[idx] == MARY_TYPE_STR) {
        return p->str_values[idx];
    }
    /* Return empty for numeric types read as string */
    return "";
}

int mary_get_type(Mary* m, int owner_id, const char* var) {
    if (owner_id < 0 || owner_id >= m->speaker_count) return MARY_TYPE_NULL;

    Partition* p = &m->partitions[owner_id];
    int idx = _find_var(p, var);
    if (idx < 0) return MARY_TYPE_NULL;

    return p->types[idx];
}

/* ── Ledger Functions ───────────────────────────────────────────── */

void mary_ledger_append(Mary* m, int speaker_id, const char* operation,
                        const char* action, int status) {
    if (m->ledger_count >= MARY_MAX_LEDGER) return;

    LedgerEntry* e = &m->ledger[m->ledger_count];
    e->entry_id = m->ledger_count;
    e->speaker_id = speaker_id;
    strncpy(e->operation, operation, sizeof(e->operation) - 1);
    e->operation[sizeof(e->operation) - 1] = '\0';
    strncpy(e->action, action, MARY_ACTION_LEN - 1);
    e->action[MARY_ACTION_LEN - 1] = '\0';
    e->status = status;
    e->timestamp = _timestamp();
    strcpy(e->prev_hash, m->last_hash);
    e->break_reason[0] = '\0';

    /* Compute hash: "entry_id:speaker_id:operation:action:timestamp:prev_hash" */
    char hash_data[1024];
    snprintf(hash_data, sizeof(hash_data), "%d:%d:%s:%s:%.3f:%s",
             e->entry_id, e->speaker_id, e->operation, e->action,
             e->timestamp, e->prev_hash);
    compute_hash(hash_data, e->entry_hash);

    strcpy(m->last_hash, e->entry_hash);
    m->ledger_count++;
}

int mary_ledger_verify(Mary* m) {
    if (m->ledger_count == 0) return 1;

    char expected_prev[MARY_HASH_LEN];
    strcpy(expected_prev, "genesis");

    for (int i = 0; i < m->ledger_count; i++) {
        LedgerEntry* e = &m->ledger[i];

        if (strcmp(e->prev_hash, expected_prev) != 0) return 0;

        /* Recompute hash */
        char hash_data[1024];
        snprintf(hash_data, sizeof(hash_data), "%d:%d:%s:%s:%.3f:%s",
                 e->entry_id, e->speaker_id, e->operation, e->action,
                 e->timestamp, e->prev_hash);
        char recomputed[MARY_HASH_LEN];
        compute_hash(hash_data, recomputed);

        if (strcmp(e->entry_hash, recomputed) != 0) return 0;

        strcpy(expected_prev, e->entry_hash);
    }

    return 1;
}

int mary_ledger_count(Mary* m) {
    return m->ledger_count;
}

/* ── Request Functions ──────────────────────────────────────────── */

int mary_request(Mary* m, int from_id, int to_id, const char* action) {
    if (m->request_count >= MARY_MAX_REQUESTS) return -1;
    if (from_id < 0 || from_id >= m->speaker_count) return -1;
    if (to_id < 0 || to_id >= m->speaker_count) return -1;

    int rid = m->next_request_id++;
    Request* r = &m->requests[m->request_count];
    r->request_id = rid;
    r->from_speaker = from_id;
    r->to_speaker = to_id;
    strncpy(r->action, action, MARY_ACTION_LEN - 1);
    r->action[MARY_ACTION_LEN - 1] = '\0';
    r->status = MARY_REQ_PENDING;
    r->created_at = _timestamp();
    m->request_count++;

    /* Log request */
    char log_action[MARY_ACTION_LEN];
    snprintf(log_action, sizeof(log_action), "request:%d:%s", to_id, action);
    mary_ledger_append(m, from_id, "request", log_action, MARY_STATUS_ACTIVE);

    return rid;
}

int mary_respond(Mary* m, int responder_id, int request_id, int accept) {
    for (int i = 0; i < m->request_count; i++) {
        Request* r = &m->requests[i];
        if (r->request_id == request_id && r->status == MARY_REQ_PENDING) {
            if (r->to_speaker != responder_id) return 0;
            r->status = accept ? MARY_REQ_ACCEPTED : MARY_REQ_REFUSED;

            /* Log response */
            char action[MARY_ACTION_LEN];
            snprintf(action, sizeof(action), "respond:%d:%s",
                     request_id, accept ? "accept" : "refuse");
            mary_ledger_append(m, responder_id, "respond", action, MARY_STATUS_ACTIVE);

            return 1;
        }
    }
    return 0;
}

int mary_pending_count(Mary* m, int speaker_id) {
    int count = 0;
    for (int i = 0; i < m->request_count; i++) {
        if (m->requests[i].to_speaker == speaker_id &&
            m->requests[i].status == MARY_REQ_PENDING) {
            count++;
        }
    }
    return count;
}

/* ── Inspection Functions ───────────────────────────────────────── */

void mary_inspect_speaker(Mary* m, int caller_id, int target_id) {
    if (target_id < 0 || target_id >= m->speaker_count) {
        printf("  --- inspect: speaker not found ---\n");
        return;
    }
    Speaker* s = &m->speakers[target_id];
    Partition* p = &m->partitions[target_id];

    printf("  --- inspect %s ---\n", s->name);
    printf("  speaker: %s (#%d)\n", s->name, s->id);
    printf("  status:  %s\n", s->status == MARY_SPEAKER_ALIVE ? "alive" : "suspended");
    printf("  vars:    [");
    for (int i = 0; i < p->count; i++) {
        if (i > 0) printf(", ");
        printf("\"%s\"", p->keys[i]);
    }
    printf("]\n");
    printf("  ---\n");

    /* Log inspection */
    char action[MARY_ACTION_LEN];
    snprintf(action, sizeof(action), "inspect:%d", target_id);
    mary_ledger_append(m, caller_id, "inspect", action, MARY_STATUS_ACTIVE);
}

void mary_inspect_variable(Mary* m, int caller_id, int owner_id, const char* var) {
    if (owner_id < 0 || owner_id >= m->speaker_count) return;

    Partition* p = &m->partitions[owner_id];
    int idx = _find_var(p, var);
    const char* owner_name = mary_speaker_name(m, owner_id);

    printf("  --- history %s.%s ---\n", owner_name, var);
    if (idx >= 0) {
        if (p->types[idx] == MARY_TYPE_STR) {
            printf("  current: %s\n", p->str_values[idx]);
        } else {
            double v = p->num_values[idx];
            if (v == (int)v) {
                printf("  current: %d\n", (int)v);
            } else {
                printf("  current: %g\n", v);
            }
        }
    } else {
        printf("  current: null\n");
    }

    /* Print write history from ledger */
    char match_action[MARY_ACTION_LEN];
    snprintf(match_action, sizeof(match_action), "write:%s", var);
    for (int i = 0; i < m->ledger_count; i++) {
        LedgerEntry* e = &m->ledger[i];
        if (e->speaker_id == owner_id && strcmp(e->action, match_action) == 0) {
            printf("    #%d: write:%s\n", e->entry_id, var);
        }
    }
    printf("  ---\n");

    /* Log history inspection */
    char action[MARY_ACTION_LEN];
    snprintf(action, sizeof(action), "history:%d.%s", owner_id, var);
    mary_ledger_append(m, caller_id, "inspect", action, MARY_STATUS_ACTIVE);
}

/* ── Seal Functions ─────────────────────────────────────────────── */

int mary_seal(Mary* m, int speaker_id, const char* var) {
    if (m->sealed_count >= MARY_MAX_VARS) return 0;

    char key[MARY_NAME_LEN];
    snprintf(key, MARY_NAME_LEN, "%d:%s", speaker_id, var);

    /* Check if already sealed */
    if (mary_is_sealed(m, speaker_id, var)) return 0;

    strncpy(m->sealed[m->sealed_count], key, MARY_NAME_LEN - 1);
    m->sealed[m->sealed_count][MARY_NAME_LEN - 1] = '\0';
    m->sealed_count++;

    /* Log seal */
    char action[MARY_ACTION_LEN];
    snprintf(action, sizeof(action), "seal:%s", var);
    mary_ledger_append(m, speaker_id, "seal", action, MARY_STATUS_ACTIVE);

    return 1;
}

int mary_is_sealed(Mary* m, int speaker_id, const char* var) {
    char key[MARY_NAME_LEN];
    snprintf(key, MARY_NAME_LEN, "%d:%s", speaker_id, var);

    for (int i = 0; i < m->sealed_count; i++) {
        if (strcmp(m->sealed[i], key) == 0) return 1;
    }
    return 0;
}

/* ── Helpers ────────────────────────────────────────────────────── */

const char* mary_speaker_name(Mary* m, int speaker_id) {
    if (speaker_id < 0 || speaker_id >= m->speaker_count) return "unknown";
    return m->speakers[speaker_id].name;
}
