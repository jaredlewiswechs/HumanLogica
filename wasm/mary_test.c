/*
 * Mary Kernel — C Test Harness
 * ============================
 * Verifies all core Mary operations before WASM compilation.
 *
 * Note: Mary struct is large (~12MB), so we use a single static
 * instance reinitialized per test to avoid stack overflow.
 */

#include "mary.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static int tests_run = 0;
static int tests_passed = 0;

/* Single static Mary instance — too large for stack */
static Mary m;

#define ASSERT(cond, msg) do { \
    tests_run++; \
    if (cond) { \
        tests_passed++; \
    } else { \
        printf("  FAIL: %s (line %d)\n", msg, __LINE__); \
    } \
} while(0)

#define ASSERT_EQ_INT(a, b, msg) ASSERT((a) == (b), msg)
#define ASSERT_EQ_STR(a, b, msg) ASSERT(strcmp((a), (b)) == 0, msg)

void test_init(void) {
    printf("── Test: Initialization ──\n");
    mary_init(&m);

    ASSERT_EQ_INT(m.speaker_count, 1, "root speaker created");
    ASSERT_EQ_STR(m.speakers[0].name, "root", "root speaker name");
    ASSERT_EQ_INT(m.speakers[0].status, MARY_SPEAKER_ALIVE, "root is alive");
    ASSERT_EQ_INT(m.ledger_count, 1, "boot entry in ledger");
    ASSERT_EQ_STR(m.ledger[0].operation, "boot", "boot operation logged");
    printf("\n");
}

void test_create_speaker(void) {
    printf("── Test: Speaker Creation ──\n");
    mary_init(&m);

    int teacher = mary_create_speaker(&m, 0, "Teacher");
    ASSERT_EQ_INT(teacher, 1, "teacher id = 1");
    ASSERT_EQ_STR(m.speakers[teacher].name, "Teacher", "teacher name");

    int student = mary_create_speaker(&m, 0, "Student");
    ASSERT_EQ_INT(student, 2, "student id = 2");
    ASSERT_EQ_STR(m.speakers[student].name, "Student", "student name");

    ASSERT_EQ_INT(m.speaker_count, 3, "3 speakers total (root + 2)");

    /* Invalid caller */
    int bad = mary_create_speaker(&m, 99, "Bad");
    ASSERT_EQ_INT(bad, -1, "invalid caller rejected");
    printf("\n");
}

void test_write_read(void) {
    printf("── Test: Write/Read ──\n");
    mary_init(&m);

    int teacher = mary_create_speaker(&m, 0, "Teacher");
    int student = mary_create_speaker(&m, 0, "Student");

    /* Teacher writes numeric value */
    int ok = mary_write(&m, teacher, "max_points", 100.0);
    ASSERT_EQ_INT(ok, 1, "teacher writes max_points");

    /* Teacher writes string value */
    ok = mary_write_str(&m, teacher, "assignment", "Build a Calculator");
    ASSERT_EQ_INT(ok, 1, "teacher writes assignment string");

    /* Read back numeric */
    double pts = mary_read_num(&m, teacher, teacher, "max_points");
    ASSERT(pts == 100.0, "read max_points = 100");

    /* Read back string */
    const char* asgn = mary_read_str(&m, student, teacher, "assignment");
    ASSERT_EQ_STR(asgn, "Build a Calculator", "student reads teacher's assignment");

    /* Student writes to own partition */
    ok = mary_write_str(&m, student, "submission", "def calc(): return 2+2");
    ASSERT_EQ_INT(ok, 1, "student writes submission");

    /* Teacher reads student's work */
    const char* work = mary_read_str(&m, teacher, student, "submission");
    ASSERT_EQ_STR(work, "def calc(): return 2+2", "teacher reads student work");

    /* Read non-existent variable */
    double missing = mary_read_num(&m, teacher, teacher, "nonexistent");
    ASSERT(missing == 0.0, "non-existent returns 0.0");

    const char* missing_str = mary_read_str(&m, teacher, teacher, "nonexistent");
    ASSERT_EQ_STR(missing_str, "", "non-existent string returns empty");

    /* Variable type tracking */
    int type_num = mary_get_type(&m, teacher, "max_points");
    ASSERT_EQ_INT(type_num, MARY_TYPE_NUM, "max_points is numeric");

    int type_str = mary_get_type(&m, teacher, "assignment");
    ASSERT_EQ_INT(type_str, MARY_TYPE_STR, "assignment is string");

    int type_null = mary_get_type(&m, teacher, "nonexistent");
    ASSERT_EQ_INT(type_null, MARY_TYPE_NULL, "nonexistent is null");
    printf("\n");
}

void test_overwrite(void) {
    printf("── Test: Variable Overwrite ──\n");
    mary_init(&m);

    int s = mary_create_speaker(&m, 0, "Speaker");

    mary_write(&m, s, "counter", 1.0);
    ASSERT(mary_read_num(&m, s, s, "counter") == 1.0, "counter = 1");

    mary_write(&m, s, "counter", 2.0);
    ASSERT(mary_read_num(&m, s, s, "counter") == 2.0, "counter = 2 after overwrite");

    mary_write_str(&m, s, "status", "submitted");
    ASSERT_EQ_STR(mary_read_str(&m, s, s, "status"), "submitted", "status = submitted");

    mary_write_str(&m, s, "status", "graded");
    ASSERT_EQ_STR(mary_read_str(&m, s, s, "status"), "graded", "status = graded after overwrite");
    printf("\n");
}

void test_ledger(void) {
    printf("── Test: Ledger ──\n");
    mary_init(&m);

    int teacher = mary_create_speaker(&m, 0, "Teacher");
    mary_write(&m, teacher, "x", 42.0);

    int count = mary_ledger_count(&m);
    ASSERT(count > 0, "ledger has entries");

    /* Verify hash chain */
    int intact = mary_ledger_verify(&m);
    ASSERT_EQ_INT(intact, 1, "ledger integrity VALID");

    /* Tamper test: corrupt an entry */
    mary_init(&m);
    mary_create_speaker(&m, 0, "T");
    mary_write(&m, 1, "y", 10.0);
    /* Corrupt a hash */
    strcpy(m.ledger[1].entry_hash, "corrupted");
    int broken = mary_ledger_verify(&m);
    ASSERT_EQ_INT(broken, 0, "tampered ledger detected as BROKEN");
    printf("\n");
}

void test_requests(void) {
    printf("── Test: Requests ──\n");
    mary_init(&m);

    int teacher = mary_create_speaker(&m, 0, "Teacher");
    int student = mary_create_speaker(&m, 0, "Student");

    /* Student requests review */
    int rid = mary_request(&m, student, teacher, "review_grade");
    ASSERT(rid >= 0, "request created");

    /* Teacher has 1 pending */
    int pending = mary_pending_count(&m, teacher);
    ASSERT_EQ_INT(pending, 1, "teacher has 1 pending request");

    /* Student has 0 pending */
    pending = mary_pending_count(&m, student);
    ASSERT_EQ_INT(pending, 0, "student has 0 pending");

    /* Wrong person tries to respond */
    int bad = mary_respond(&m, student, rid, 1);
    ASSERT_EQ_INT(bad, 0, "student cannot respond to own request");

    /* Teacher refuses */
    int ok = mary_respond(&m, teacher, rid, 0);
    ASSERT_EQ_INT(ok, 1, "teacher responds");

    /* No more pending */
    pending = mary_pending_count(&m, teacher);
    ASSERT_EQ_INT(pending, 0, "no pending after response");
    printf("\n");
}

void test_seal(void) {
    printf("── Test: Seal ──\n");
    mary_init(&m);

    int s = mary_create_speaker(&m, 0, "Speaker");

    mary_write(&m, s, "grade", 95.0);
    ASSERT(mary_read_num(&m, s, s, "grade") == 95.0, "grade = 95");

    /* Seal the variable */
    int sealed = mary_seal(&m, s, "grade");
    ASSERT_EQ_INT(sealed, 1, "seal succeeded");

    /* Try to overwrite */
    int ok = mary_write(&m, s, "grade", 100.0);
    ASSERT_EQ_INT(ok, 0, "write to sealed variable rejected");

    /* Value unchanged */
    ASSERT(mary_read_num(&m, s, s, "grade") == 95.0, "grade still 95 after rejected write");

    /* Cannot seal twice */
    int sealed2 = mary_seal(&m, s, "grade");
    ASSERT_EQ_INT(sealed2, 0, "cannot seal twice");
    printf("\n");
}

void test_hash(void) {
    printf("── Test: Hash (FNV-1a) ──\n");
    char hash[MARY_HASH_LEN];

    compute_hash("hello", hash);
    ASSERT(strlen(hash) == 8, "hash length is 8 hex chars");
    ASSERT_EQ_STR(hash, "4f9f2cab", "FNV-1a of 'hello'");

    compute_hash("", hash);
    ASSERT_EQ_STR(hash, "811c9dc5", "FNV-1a of empty string");

    /* Different inputs produce different hashes */
    char h1[MARY_HASH_LEN], h2[MARY_HASH_LEN];
    compute_hash("abc", h1);
    compute_hash("abd", h2);
    ASSERT(strcmp(h1, h2) != 0, "different inputs -> different hashes");
    printf("\n");
}

void test_inspect(void) {
    printf("── Test: Inspect ──\n");
    mary_init(&m);

    int teacher = mary_create_speaker(&m, 0, "Teacher");
    mary_write_str(&m, teacher, "course", "CS 101");
    mary_write(&m, teacher, "students", 30.0);

    printf("  (inspect output below)\n");
    mary_inspect_speaker(&m, 0, teacher);
    mary_inspect_variable(&m, 0, teacher, "course");
    printf("\n");
}

void test_speaker_name(void) {
    printf("── Test: Speaker Name Lookup ──\n");
    mary_init(&m);

    mary_create_speaker(&m, 0, "Jared");
    mary_create_speaker(&m, 0, "Maria");

    ASSERT_EQ_STR(mary_speaker_name(&m, 0), "root", "id 0 = root");
    ASSERT_EQ_STR(mary_speaker_name(&m, 1), "Jared", "id 1 = Jared");
    ASSERT_EQ_STR(mary_speaker_name(&m, 2), "Maria", "id 2 = Maria");
    ASSERT_EQ_STR(mary_speaker_name(&m, 99), "unknown", "id 99 = unknown");
    printf("\n");
}

int main(void) {
    printf("\n");
    printf("============================================================\n");
    printf("  Mary Kernel — C Test Harness\n");
    printf("============================================================\n");
    printf("\n");

    test_init();
    test_create_speaker();
    test_write_read();
    test_overwrite();
    test_ledger();
    test_requests();
    test_seal();
    test_hash();
    test_inspect();
    test_speaker_name();

    printf("============================================================\n");
    printf("  Results: %d/%d tests passed\n", tests_passed, tests_run);
    if (tests_passed == tests_run) {
        printf("  All tests passed. Mary kernel is correct.\n");
    } else {
        printf("  %d FAILURES\n", tests_run - tests_passed);
    }
    printf("============================================================\n");
    printf("\n");

    return tests_passed == tests_run ? 0 : 1;
}
