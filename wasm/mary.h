/*
 * Mary — A Kernel for Human Logic (C Implementation)
 * ===================================================
 * Port of the Mary kernel for WASM compilation.
 * Every operation has a speaker. Every state change has a receipt.
 *
 * Hash: FNV-1a (matches JS runtime)
 */

#ifndef MARY_H
#define MARY_H

#include <stdint.h>

/* ── Limits ─────────────────────────────────────────────────────── */
#define MARY_MAX_SPEAKERS     64
#define MARY_MAX_VARS        256
#define MARY_MAX_LEDGER     8192
#define MARY_MAX_REQUESTS    256
#define MARY_NAME_LEN         64
#define MARY_STR_LEN         256
#define MARY_ACTION_LEN      256
#define MARY_HASH_LEN         17  /* 8 hex chars + null */
#define MARY_REASON_LEN      128

/* ── Status Constants ───────────────────────────────────────────── */
#define MARY_STATUS_ACTIVE     0
#define MARY_STATUS_INACTIVE   1
#define MARY_STATUS_BROKEN     2

/* ── Speaker Status ─────────────────────────────────────────────── */
#define MARY_SPEAKER_ALIVE     0
#define MARY_SPEAKER_SUSPENDED 1

/* ── Request Status ─────────────────────────────────────────────── */
#define MARY_REQ_PENDING       0
#define MARY_REQ_ACCEPTED      1
#define MARY_REQ_REFUSED       2

/* ── Variable Types ─────────────────────────────────────────────── */
#define MARY_TYPE_NULL         0
#define MARY_TYPE_NUM          1
#define MARY_TYPE_STR          2
#define MARY_TYPE_BOOL         3

/* ── Speaker ────────────────────────────────────────────────────── */
typedef struct {
    int id;
    char name[MARY_NAME_LEN];
    double created_at;
    int status;
} Speaker;

/* ── Ledger Entry ───────────────────────────────────────────────── */
typedef struct {
    int entry_id;
    int speaker_id;
    char operation[32];
    char action[MARY_ACTION_LEN];
    int status;         /* MARY_STATUS_* or -1 for none */
    double timestamp;
    char prev_hash[MARY_HASH_LEN];
    char entry_hash[MARY_HASH_LEN];
    char break_reason[MARY_REASON_LEN];
} LedgerEntry;

/* ── Memory Partition (per speaker) ─────────────────────────────── */
typedef struct {
    char keys[MARY_MAX_VARS][MARY_NAME_LEN];
    double num_values[MARY_MAX_VARS];
    char str_values[MARY_MAX_VARS][MARY_STR_LEN];
    int types[MARY_MAX_VARS];  /* MARY_TYPE_* */
    int count;
} Partition;

/* ── Request ────────────────────────────────────────────────────── */
typedef struct {
    int request_id;
    int from_speaker;
    int to_speaker;
    char action[MARY_ACTION_LEN];
    int status;
    double created_at;
} Request;

/* ── Mary Kernel ────────────────────────────────────────────────── */
typedef struct {
    Speaker speakers[MARY_MAX_SPEAKERS];
    int speaker_count;
    Partition partitions[MARY_MAX_SPEAKERS];
    LedgerEntry ledger[MARY_MAX_LEDGER];
    int ledger_count;
    Request requests[MARY_MAX_REQUESTS];
    int request_count;
    int next_request_id;
    char last_hash[MARY_HASH_LEN];
    /* Sealed variables: "speaker_id:varname" entries */
    char sealed[MARY_MAX_VARS][MARY_NAME_LEN];
    int sealed_count;
} Mary;

/* ── Core Functions ─────────────────────────────────────────────── */
void mary_init(Mary* m);
int  mary_create_speaker(Mary* m, int caller_id, const char* name);
int  mary_write(Mary* m, int caller_id, const char* var, double value);
int  mary_write_str(Mary* m, int caller_id, const char* var, const char* value);
double mary_read_num(Mary* m, int caller_id, int owner_id, const char* var);
const char* mary_read_str(Mary* m, int caller_id, int owner_id, const char* var);
int  mary_get_type(Mary* m, int owner_id, const char* var);

/* ── Ledger Functions ───────────────────────────────────────────── */
void mary_ledger_append(Mary* m, int speaker_id, const char* operation,
                        const char* action, int status);
int  mary_ledger_verify(Mary* m);
int  mary_ledger_count(Mary* m);

/* ── Request Functions ──────────────────────────────────────────── */
int  mary_request(Mary* m, int from_id, int to_id, const char* action);
int  mary_respond(Mary* m, int responder_id, int request_id, int accept);
int  mary_pending_count(Mary* m, int speaker_id);

/* ── Inspection Functions ───────────────────────────────────────── */
void mary_inspect_speaker(Mary* m, int caller_id, int target_id);
void mary_inspect_variable(Mary* m, int caller_id, int owner_id, const char* var);

/* ── Seal Functions ─────────────────────────────────────────────── */
int  mary_seal(Mary* m, int speaker_id, const char* var);
int  mary_is_sealed(Mary* m, int speaker_id, const char* var);

/* ── Hash (FNV-1a, matches JS runtime) ──────────────────────────── */
void compute_hash(const char* data, char* out);

/* ── Helpers ────────────────────────────────────────────────────── */
const char* mary_speaker_name(Mary* m, int speaker_id);

#endif /* MARY_H */
