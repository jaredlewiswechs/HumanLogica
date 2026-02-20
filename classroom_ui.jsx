import { useState, useCallback, useEffect, useRef } from "react";

// ═══════════════════════════════════════════════════════════════
// MARY — The Kernel (embedded, simplified for browser)
// ═══════════════════════════════════════════════════════════════

function createMary() {
  let nextSpeakerId = 0;
  let nextEntryId = 0;
  let lastHash = "genesis";
  const speakers = {};
  const memory = {};
  const ledger = [];

  function hash(str) {
    let h = 0;
    for (let i = 0; i < str.length; i++) {
      h = ((h << 5) - h + str.charCodeAt(i)) | 0;
    }
    return Math.abs(h).toString(16).padStart(8, "0");
  }

  function log(speakerId, operation, action, status, extra = {}) {
    const entry = {
      id: nextEntryId++,
      speakerId,
      speaker: speakers[speakerId]?.name || `speaker_${speakerId}`,
      operation,
      action,
      status,
      timestamp: Date.now(),
      prevHash: lastHash,
      ...extra,
    };
    entry.hash = hash(`${entry.id}:${entry.speakerId}:${entry.action}:${entry.timestamp}:${entry.prevHash}`);
    lastHash = entry.hash;
    ledger.push(entry);
    return entry;
  }

  function createSpeaker(name) {
    const id = nextSpeakerId++;
    speakers[id] = { id, name, status: "alive", createdAt: Date.now() };
    memory[id] = {};
    log(id, "create_speaker", `create:${name}`, "active");
    return speakers[id];
  }

  function write(callerId, varName, value) {
    const old = memory[callerId]?.[varName];
    if (!memory[callerId]) return false;
    memory[callerId][varName] = value;
    log(callerId, "write", `write:${varName}`, "active", {
      before: old,
      after: value,
    });
    return true;
  }

  function writeTo(callerId, targetId, varName, value) {
    if (callerId !== targetId) {
      log(callerId, "write_violation", `write:${targetId}.${varName}`, "broken", {
        reason: "write_ownership_violation",
      });
      return false;
    }
    return write(callerId, varName, value);
  }

  function read(ownerId, varName) {
    return memory[ownerId]?.[varName] ?? null;
  }

  function listVars(ownerId) {
    return Object.keys(memory[ownerId] || {});
  }

  return {
    createSpeaker,
    write,
    writeTo,
    read,
    listVars,
    getSpeaker: (id) => speakers[id],
    getSpeakers: () => ({ ...speakers }),
    getLedger: () => [...ledger],
    getViolations: () => ledger.filter((e) => e.operation === "write_violation"),
    verifyIntegrity: () => {
      let prev = "genesis";
      for (const entry of ledger) {
        if (entry.prevHash !== prev) return false;
        prev = entry.hash;
      }
      return true;
    },
    log,
    hash,
  };
}

// ═══════════════════════════════════════════════════════════════
// CLASSROOM — The First World (embedded)
// ═══════════════════════════════════════════════════════════════

function createClassroom(mary, teacherId, courseName) {
  let nextAssignment = 1;
  const assignments = {};
  const worldId = "world_0";

  mary.write(teacherId, `${worldId}.course.name`, courseName);

  function createAssignment(title, description, maxPoints = 100) {
    const aid = `assignment_${nextAssignment++}`;
    assignments[aid] = {
      id: aid,
      title,
      description,
      maxPoints,
      createdAt: Date.now(),
      dueAt: Date.now() + 7 * 24 * 60 * 60 * 1000,
      allowResubmit: true,
    };
    mary.write(teacherId, `${worldId}.${aid}.title`, title);
    mary.write(teacherId, `${worldId}.${aid}.max_points`, maxPoints);
    mary.write(teacherId, `${worldId}.${aid}.status`, "published");
    mary.log(teacherId, "expression", `publish:${aid}:${title}`, "active");
    return aid;
  }

  function submitWork(studentId, aid, content) {
    if (!assignments[aid]) return { status: "error", reason: "not_found" };
    const key = `${worldId}.${studentId}.sub.${aid}`;
    const existingV = mary.read(studentId, `${key}.version`);
    const version = existingV ? existingV + 1 : 1;
    const contentHash = mary.hash(content);

    mary.write(studentId, `${key}.content`, content);
    mary.write(studentId, `${key}.version`, version);
    mary.write(studentId, `${key}.submitted_at`, Date.now());
    mary.write(studentId, `${key}.content_hash`, contentHash);
    mary.write(studentId, `${key}.late`, false);
    mary.log(studentId, "expression", `submit:${aid}:v${version}`, "active");

    return { status: "active", version, contentHash, ledgerEntry: mary.getLedger().length - 1 };
  }

  function grade(studentId, aid, score, feedback) {
    const key = `${worldId}.${studentId}.sub.${aid}`;
    const content = mary.read(studentId, `${key}.content`);
    if (!content) return { status: "error", reason: "no_submission" };

    const version = mary.read(studentId, `${key}.version`);
    const gKey = `${worldId}.grade.${studentId}.${aid}`;
    mary.write(teacherId, `${gKey}.score`, score);
    mary.write(teacherId, `${gKey}.max`, assignments[aid].maxPoints);
    mary.write(teacherId, `${gKey}.feedback`, feedback);
    mary.write(teacherId, `${gKey}.graded_at`, Date.now());
    mary.write(teacherId, `${gKey}.sub_version`, version);
    mary.log(teacherId, "expression", `grade:${studentId}:${aid}:${score}/${assignments[aid].maxPoints}`, "active");

    return { status: "active", score, max: assignments[aid].maxPoints, version };
  }

  function getSubmission(studentId, aid) {
    const key = `${worldId}.${studentId}.sub.${aid}`;
    const content = mary.read(studentId, `${key}.content`);
    if (!content) return null;
    return {
      studentId,
      content,
      version: mary.read(studentId, `${key}.version`),
      submittedAt: mary.read(studentId, `${key}.submitted_at`),
      contentHash: mary.read(studentId, `${key}.content_hash`),
    };
  }

  function getGrade(studentId, aid) {
    const gKey = `${worldId}.grade.${studentId}.${aid}`;
    const score = mary.read(teacherId, `${gKey}.score`);
    if (score === null) return null;
    return {
      score,
      max: mary.read(teacherId, `${gKey}.max`),
      feedback: mary.read(teacherId, `${gKey}.feedback`),
      subVersion: mary.read(teacherId, `${gKey}.sub_version`),
    };
  }

  return {
    worldId,
    assignments,
    createAssignment,
    submitWork,
    grade,
    getSubmission,
    getGrade,
    getAssignments: () => ({ ...assignments }),
  };
}

// ═══════════════════════════════════════════════════════════════
// STATUS BADGE
// ═══════════════════════════════════════════════════════════════

const statusColors = {
  active: { bg: "#0a2e1a", text: "#34d399", border: "#166534" },
  inactive: { bg: "#2a1f00", text: "#fbbf24", border: "#854d0e" },
  broken: { bg: "#2a0a0a", text: "#f87171", border: "#991b1b" },
  pending: { bg: "#1a1a2e", text: "#818cf8", border: "#4338ca" },
};

function StatusBadge({ status }) {
  const c = statusColors[status] || statusColors.pending;
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 5,
        padding: "2px 10px",
        borderRadius: 4,
        fontSize: 11,
        fontFamily: "'IBM Plex Mono', monospace",
        fontWeight: 600,
        letterSpacing: "0.05em",
        textTransform: "uppercase",
        background: c.bg,
        color: c.text,
        border: `1px solid ${c.border}`,
      }}
    >
      <span
        style={{
          width: 6,
          height: 6,
          borderRadius: "50%",
          background: c.text,
          boxShadow: `0 0 6px ${c.text}`,
        }}
      />
      {status}
    </span>
  );
}

// ═══════════════════════════════════════════════════════════════
// MAIN APP
// ═══════════════════════════════════════════════════════════════

export default function ClassroomWorld() {
  const maryRef = useRef(null);
  const classroomRef = useRef(null);
  const [, forceUpdate] = useState(0);
  const rerender = () => forceUpdate((n) => n + 1);

  const [students, setStudents] = useState([]);
  const [view, setView] = useState("dashboard");
  const [currentSpeaker, setCurrentSpeaker] = useState(null);
  const [teacherId, setTeacherId] = useState(null);
  const [notifications, setNotifications] = useState([]);
  const [showLedger, setShowLedger] = useState(false);
  const [tamperLog, setTamperLog] = useState([]);
  const [initialized, setInitialized] = useState(false);

  // Input states
  const [newStudentName, setNewStudentName] = useState("");
  const [assignTitle, setAssignTitle] = useState("");
  const [assignDesc, setAssignDesc] = useState("");
  const [assignPoints, setAssignPoints] = useState("100");
  const [submitContent, setSubmitContent] = useState("");
  const [gradeScore, setGradeScore] = useState("");
  const [gradeFeedback, setGradeFeedback] = useState("");
  const [selectedStudent, setSelectedStudent] = useState(null);
  const [selectedAssignment, setSelectedAssignment] = useState(null);

  const addNotification = useCallback((msg, type = "info") => {
    const n = { id: Date.now(), msg, type };
    setNotifications((prev) => [n, ...prev].slice(0, 8));
    setTimeout(() => setNotifications((prev) => prev.filter((x) => x.id !== n.id)), 4000);
  }, []);

  // Initialize
  useEffect(() => {
    if (initialized) return;
    const mary = createMary();
    maryRef.current = mary;

    const root = mary.createSpeaker("root");
    const helena = mary.createSpeaker("helena");
    const teacher = mary.createSpeaker("Jared");
    setTeacherId(teacher.id);
    setCurrentSpeaker(teacher.id);

    const classroom = createClassroom(mary, teacher.id, "CS 101 — Spring 2026");
    classroomRef.current = classroom;

    // Pre-enroll students
    const s1 = mary.createSpeaker("Maria");
    const s2 = mary.createSpeaker("James");
    const s3 = mary.createSpeaker("Aisha");
    setStudents([s1, s2, s3]);

    // Pre-create assignments
    classroom.createAssignment("Build a Calculator", "Build a four-function calculator in Python. Handle +, -, *, / and division by zero.", 100);
    classroom.createAssignment("Linked List Lab", "Implement a singly linked list with insert, delete, and search.", 100);

    setInitialized(true);
  }, [initialized]);

  const mary = maryRef.current;
  const classroom = classroomRef.current;

  if (!mary || !classroom) return null;

  const assignments = Object.values(classroom.getAssignments());
  const ledger = mary.getLedger();
  const violations = mary.getViolations();
  const integrity = mary.verifyIntegrity();
  const speakerName = mary.getSpeaker(currentSpeaker)?.name || "Unknown";
  const isTeacher = currentSpeaker === teacherId;

  // ── Actions ──

  function enrollStudent() {
    if (!newStudentName.trim()) return;
    const s = mary.createSpeaker(newStudentName.trim());
    setStudents((prev) => [...prev, s]);
    addNotification(`Enrolled ${s.name} (speaker #${s.id})`, "success");
    setNewStudentName("");
    rerender();
  }

  function createAssignment() {
    if (!assignTitle.trim()) return;
    const aid = classroom.createAssignment(assignTitle.trim(), assignDesc.trim() || "Complete the assignment.", parseInt(assignPoints) || 100);
    addNotification(`Assignment created: ${aid} — ${assignTitle}`, "success");
    setAssignTitle("");
    setAssignDesc("");
    setAssignPoints("100");
    rerender();
  }

  function submitWork() {
    if (!selectedAssignment || !submitContent.trim()) return;
    const receipt = classroom.submitWork(currentSpeaker, selectedAssignment, submitContent.trim());
    if (receipt.status === "active") {
      addNotification(`Submitted ${selectedAssignment} v${receipt.version} — hash: ${receipt.contentHash}`, "success");
    } else {
      addNotification(`Submission failed: ${receipt.reason}`, "error");
    }
    setSubmitContent("");
    rerender();
  }

  function gradeSubmission() {
    if (!selectedStudent || !selectedAssignment || !gradeScore) return;
    const result = classroom.grade(selectedStudent, selectedAssignment, parseInt(gradeScore), gradeFeedback);
    if (result.status === "active") {
      addNotification(`Graded ${mary.getSpeaker(selectedStudent)?.name}: ${result.score}/${result.max}`, "success");
    } else {
      addNotification(`Grading failed: ${result.reason}`, "error");
    }
    setGradeScore("");
    setGradeFeedback("");
    rerender();
  }

  function attemptTamper() {
    if (!selectedStudent) {
      addNotification("Select a student first", "error");
      return;
    }
    const targetVar = `${classroom.worldId}.${selectedStudent}.sub.assignment_1.content`;
    const result = mary.writeTo(currentSpeaker, selectedStudent, targetVar, "TAMPERED");
    const entry = mary.getLedger().slice(-1)[0];
    setTamperLog((prev) => [
      ...prev,
      {
        by: speakerName,
        target: mary.getSpeaker(selectedStudent)?.name,
        blocked: !result,
        entry,
      },
    ]);
    if (!result) {
      addNotification(`BLOCKED — Axiom 8: Write Ownership Violation`, "error");
    }
    rerender();
  }

  // ── Computed views ──

  function getGradebook() {
    return students.map((s) => {
      const row = { student: s, grades: {} };
      let total = 0, max = 0;
      for (const a of assignments) {
        const g = classroom.getGrade(s.id, a.id);
        const sub = classroom.getSubmission(s.id, a.id);
        row.grades[a.id] = { grade: g, submission: sub };
        if (g) { total += g.score; max += g.max; }
      }
      row.total = max > 0 ? Math.round((total / max) * 1000) / 10 : 0;
      row.totalRaw = `${total}/${max}`;
      return row;
    });
  }

  // ═══════════════════════════════════════════════════════════
  // RENDER
  // ═══════════════════════════════════════════════════════════

  const fontStack = "'IBM Plex Mono', 'SF Mono', 'Fira Code', monospace";
  const fontSans = "'IBM Plex Sans', -apple-system, sans-serif";

  return (
    <div
      style={{
        minHeight: "100vh",
        background: "#0a0a0f",
        color: "#e2e2e8",
        fontFamily: fontSans,
        fontSize: 13,
      }}
    >
      <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600;700&family=IBM+Plex+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet" />

      {/* ── HEADER ── */}
      <div
        style={{
          borderBottom: "1px solid #1a1a2e",
          padding: "12px 20px",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          background: "#0d0d14",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
          <div>
            <div style={{ fontFamily: fontStack, fontWeight: 700, fontSize: 14, color: "#f0f0f0", letterSpacing: "0.02em" }}>
              THE CLASSROOM WORLD
            </div>
            <div style={{ fontSize: 10, color: "#555", fontFamily: fontStack, letterSpacing: "0.1em" }}>
              HUMAN LOGIC → MARY → HELENA
            </div>
          </div>
          <div style={{ height: 24, width: 1, background: "#1a1a2e" }} />
          <div style={{ fontSize: 12, color: "#888" }}>
            CS 101 — Spring 2026
          </div>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <span style={{ width: 7, height: 7, borderRadius: "50%", background: integrity ? "#34d399" : "#f87171", boxShadow: `0 0 8px ${integrity ? "#34d399" : "#f87171"}` }} />
            <span style={{ fontFamily: fontStack, fontSize: 10, color: integrity ? "#34d399" : "#f87171" }}>
              LEDGER {integrity ? "VALID" : "BROKEN"}
            </span>
          </div>
          <div style={{ fontFamily: fontStack, fontSize: 10, color: "#666" }}>
            {ledger.length} entries
          </div>
          <div style={{ fontFamily: fontStack, fontSize: 10, color: violations.length > 0 ? "#f87171" : "#666" }}>
            {violations.length} violation{violations.length !== 1 ? "s" : ""}
          </div>
        </div>
      </div>

      {/* ── SPEAKER SWITCHER ── */}
      <div
        style={{
          borderBottom: "1px solid #1a1a2e",
          padding: "8px 20px",
          display: "flex",
          alignItems: "center",
          gap: 8,
          background: "#0b0b12",
          flexWrap: "wrap",
        }}
      >
        <span style={{ fontSize: 10, color: "#555", fontFamily: fontStack, letterSpacing: "0.1em", marginRight: 4 }}>
          SPEAKING AS:
        </span>
        <button
          onClick={() => { setCurrentSpeaker(teacherId); rerender(); }}
          style={{
            padding: "4px 12px",
            borderRadius: 4,
            border: `1px solid ${currentSpeaker === teacherId ? "#4338ca" : "#1a1a2e"}`,
            background: currentSpeaker === teacherId ? "#1a1a3e" : "transparent",
            color: currentSpeaker === teacherId ? "#818cf8" : "#666",
            fontFamily: fontStack,
            fontSize: 11,
            cursor: "pointer",
            fontWeight: currentSpeaker === teacherId ? 600 : 400,
          }}
        >
          Jared (teacher)
        </button>
        {students.map((s) => (
          <button
            key={s.id}
            onClick={() => { setCurrentSpeaker(s.id); rerender(); }}
            style={{
              padding: "4px 12px",
              borderRadius: 4,
              border: `1px solid ${currentSpeaker === s.id ? "#166534" : "#1a1a2e"}`,
              background: currentSpeaker === s.id ? "#0a2e1a" : "transparent",
              color: currentSpeaker === s.id ? "#34d399" : "#666",
              fontFamily: fontStack,
              fontSize: 11,
              cursor: "pointer",
              fontWeight: currentSpeaker === s.id ? 600 : 400,
            }}
          >
            {s.name}
          </button>
        ))}
      </div>

      {/* ── NAV ── */}
      <div
        style={{
          borderBottom: "1px solid #1a1a2e",
          padding: "0 20px",
          display: "flex",
          gap: 0,
          background: "#0b0b12",
        }}
      >
        {["dashboard", "assignments", "gradebook", "inspect", "tamper"].map((v) => (
          <button
            key={v}
            onClick={() => setView(v)}
            style={{
              padding: "10px 18px",
              background: "transparent",
              border: "none",
              borderBottom: view === v ? "2px solid #818cf8" : "2px solid transparent",
              color: view === v ? "#e2e2e8" : "#555",
              fontFamily: fontStack,
              fontSize: 11,
              cursor: "pointer",
              letterSpacing: "0.06em",
              textTransform: "uppercase",
              fontWeight: view === v ? 600 : 400,
            }}
          >
            {v === "tamper" ? "⚠ tamper test" : v}
          </button>
        ))}
      </div>

      {/* ── NOTIFICATIONS ── */}
      <div style={{ position: "fixed", top: 12, right: 12, zIndex: 100, display: "flex", flexDirection: "column", gap: 6, maxWidth: 360 }}>
        {notifications.map((n) => (
          <div
            key={n.id}
            style={{
              padding: "8px 14px",
              borderRadius: 6,
              fontFamily: fontStack,
              fontSize: 11,
              background: n.type === "success" ? "#0a2e1a" : n.type === "error" ? "#2a0a0a" : "#1a1a2e",
              color: n.type === "success" ? "#34d399" : n.type === "error" ? "#f87171" : "#818cf8",
              border: `1px solid ${n.type === "success" ? "#166534" : n.type === "error" ? "#991b1b" : "#4338ca"}`,
              animation: "fadeIn 0.2s ease",
            }}
          >
            {n.msg}
          </div>
        ))}
      </div>

      {/* ── MAIN CONTENT ── */}
      <div style={{ padding: 20, maxWidth: 1000, margin: "0 auto" }}>
        {/* DASHBOARD */}
        {view === "dashboard" && (
          <div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr 1fr", gap: 12, marginBottom: 24 }}>
              {[
                { label: "Students", value: students.length, color: "#34d399" },
                { label: "Assignments", value: assignments.length, color: "#818cf8" },
                { label: "Ledger", value: ledger.length, color: "#fbbf24" },
                { label: "Violations", value: violations.length, color: violations.length > 0 ? "#f87171" : "#555" },
              ].map((s, i) => (
                <div
                  key={i}
                  style={{
                    background: "#111118",
                    border: "1px solid #1a1a2e",
                    borderRadius: 8,
                    padding: "16px 18px",
                  }}
                >
                  <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 8 }}>
                    {s.label}
                  </div>
                  <div style={{ fontFamily: fontStack, fontSize: 28, fontWeight: 700, color: s.color }}>
                    {s.value}
                  </div>
                </div>
              ))}
            </div>

            {/* Quick actions */}
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
              {/* Enroll */}
              <div style={{ background: "#111118", border: "1px solid #1a1a2e", borderRadius: 8, padding: 18 }}>
                <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 12 }}>
                  ENROLL STUDENT
                </div>
                <div style={{ display: "flex", gap: 8 }}>
                  <input
                    value={newStudentName}
                    onChange={(e) => setNewStudentName(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && enrollStudent()}
                    placeholder="Student name"
                    style={{
                      flex: 1,
                      padding: "8px 12px",
                      background: "#0a0a0f",
                      border: "1px solid #1a1a2e",
                      borderRadius: 4,
                      color: "#e2e2e8",
                      fontFamily: fontStack,
                      fontSize: 12,
                      outline: "none",
                    }}
                  />
                  <button
                    onClick={enrollStudent}
                    style={{
                      padding: "8px 16px",
                      background: "#1a1a3e",
                      border: "1px solid #4338ca",
                      borderRadius: 4,
                      color: "#818cf8",
                      fontFamily: fontStack,
                      fontSize: 11,
                      cursor: "pointer",
                      fontWeight: 600,
                    }}
                  >
                    Enroll
                  </button>
                </div>
              </div>

              {/* Create Assignment (teacher only) */}
              {isTeacher && (
                <div style={{ background: "#111118", border: "1px solid #1a1a2e", borderRadius: 8, padding: 18 }}>
                  <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 12 }}>
                    CREATE ASSIGNMENT
                  </div>
                  <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                    <input
                      value={assignTitle}
                      onChange={(e) => setAssignTitle(e.target.value)}
                      placeholder="Title"
                      style={{
                        padding: "8px 12px",
                        background: "#0a0a0f",
                        border: "1px solid #1a1a2e",
                        borderRadius: 4,
                        color: "#e2e2e8",
                        fontFamily: fontStack,
                        fontSize: 12,
                        outline: "none",
                      }}
                    />
                    <div style={{ display: "flex", gap: 8 }}>
                      <input
                        value={assignPoints}
                        onChange={(e) => setAssignPoints(e.target.value)}
                        placeholder="Points"
                        style={{
                          width: 70,
                          padding: "8px 12px",
                          background: "#0a0a0f",
                          border: "1px solid #1a1a2e",
                          borderRadius: 4,
                          color: "#e2e2e8",
                          fontFamily: fontStack,
                          fontSize: 12,
                          outline: "none",
                        }}
                      />
                      <button
                        onClick={createAssignment}
                        style={{
                          flex: 1,
                          padding: "8px 16px",
                          background: "#1a1a3e",
                          border: "1px solid #4338ca",
                          borderRadius: 4,
                          color: "#818cf8",
                          fontFamily: fontStack,
                          fontSize: 11,
                          cursor: "pointer",
                          fontWeight: 600,
                        }}
                      >
                        Create
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* Submit Work (student only) */}
              {!isTeacher && (
                <div style={{ background: "#111118", border: "1px solid #1a1a2e", borderRadius: 8, padding: 18 }}>
                  <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 12 }}>
                    SUBMIT WORK
                  </div>
                  <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                    <select
                      value={selectedAssignment || ""}
                      onChange={(e) => setSelectedAssignment(e.target.value)}
                      style={{
                        padding: "8px 12px",
                        background: "#0a0a0f",
                        border: "1px solid #1a1a2e",
                        borderRadius: 4,
                        color: "#e2e2e8",
                        fontFamily: fontStack,
                        fontSize: 12,
                      }}
                    >
                      <option value="">Select assignment</option>
                      {assignments.map((a) => (
                        <option key={a.id} value={a.id}>{a.title}</option>
                      ))}
                    </select>
                    <textarea
                      value={submitContent}
                      onChange={(e) => setSubmitContent(e.target.value)}
                      placeholder="Your code or work here..."
                      rows={3}
                      style={{
                        padding: "8px 12px",
                        background: "#0a0a0f",
                        border: "1px solid #1a1a2e",
                        borderRadius: 4,
                        color: "#e2e2e8",
                        fontFamily: fontStack,
                        fontSize: 12,
                        outline: "none",
                        resize: "vertical",
                      }}
                    />
                    <button
                      onClick={submitWork}
                      style={{
                        padding: "8px 16px",
                        background: "#0a2e1a",
                        border: "1px solid #166534",
                        borderRadius: 4,
                        color: "#34d399",
                        fontFamily: fontStack,
                        fontSize: 11,
                        cursor: "pointer",
                        fontWeight: 600,
                      }}
                    >
                      Submit
                    </button>
                  </div>
                </div>
              )}
            </div>

            {/* Student list */}
            <div style={{ marginTop: 24, background: "#111118", border: "1px solid #1a1a2e", borderRadius: 8, padding: 18 }}>
              <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 12 }}>
                ENROLLED SPEAKERS
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                <div style={{ display: "flex", padding: "6px 0", borderBottom: "1px solid #1a1a2e", fontFamily: fontStack, fontSize: 10, color: "#555" }}>
                  <span style={{ width: 50 }}>ID</span>
                  <span style={{ width: 120 }}>NAME</span>
                  <span style={{ width: 80 }}>ROLE</span>
                  <span style={{ flex: 1 }}>STATUS</span>
                </div>
                <div style={{ display: "flex", padding: "6px 0", borderBottom: "1px solid #0d0d14", fontFamily: fontStack, fontSize: 12 }}>
                  <span style={{ width: 50, color: "#555" }}>#{teacherId}</span>
                  <span style={{ width: 120, color: "#818cf8", fontWeight: 600 }}>Jared</span>
                  <span style={{ width: 80, color: "#818cf8" }}>teacher</span>
                  <StatusBadge status="active" />
                </div>
                {students.map((s) => (
                  <div key={s.id} style={{ display: "flex", padding: "6px 0", borderBottom: "1px solid #0d0d14", fontFamily: fontStack, fontSize: 12, alignItems: "center" }}>
                    <span style={{ width: 50, color: "#555" }}>#{s.id}</span>
                    <span style={{ width: 120, color: "#34d399" }}>{s.name}</span>
                    <span style={{ width: 80, color: "#555" }}>student</span>
                    <StatusBadge status="active" />
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* ASSIGNMENTS */}
        {view === "assignments" && (
          <div>
            <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 16 }}>
              ASSIGNMENTS & SUBMISSIONS
            </div>
            {assignments.map((a) => (
              <div key={a.id} style={{ background: "#111118", border: "1px solid #1a1a2e", borderRadius: 8, padding: 18, marginBottom: 12 }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 12 }}>
                  <div>
                    <div style={{ fontFamily: fontStack, fontSize: 14, fontWeight: 600 }}>{a.title}</div>
                    <div style={{ fontSize: 12, color: "#666", marginTop: 4 }}>{a.description}</div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <div style={{ fontFamily: fontStack, fontSize: 18, fontWeight: 700, color: "#818cf8" }}>{a.maxPoints}</div>
                    <div style={{ fontFamily: fontStack, fontSize: 9, color: "#555" }}>POINTS</div>
                  </div>
                </div>
                <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", marginBottom: 8, letterSpacing: "0.1em" }}>SUBMISSIONS</div>
                <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                  {students.map((s) => {
                    const sub = classroom.getSubmission(s.id, a.id);
                    const grade = classroom.getGrade(s.id, a.id);
                    return (
                      <div
                        key={s.id}
                        style={{
                          display: "flex",
                          alignItems: "center",
                          gap: 12,
                          padding: "8px 12px",
                          background: "#0a0a0f",
                          borderRadius: 4,
                          border: "1px solid #141420",
                        }}
                      >
                        <span style={{ fontFamily: fontStack, fontSize: 12, color: "#e2e2e8", width: 80 }}>{s.name}</span>
                        {sub ? (
                          <>
                            <StatusBadge status="active" />
                            <span style={{ fontFamily: fontStack, fontSize: 10, color: "#555" }}>v{sub.version}</span>
                            <span style={{ fontFamily: fontStack, fontSize: 10, color: "#444" }}>{sub.contentHash}</span>
                            <span style={{ fontFamily: fontStack, fontSize: 11, color: "#888", flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                              {sub.content.slice(0, 60)}...
                            </span>
                            {grade && (
                              <span style={{ fontFamily: fontStack, fontSize: 12, fontWeight: 700, color: grade.score >= 90 ? "#34d399" : grade.score >= 70 ? "#fbbf24" : "#f87171" }}>
                                {grade.score}/{grade.max}
                              </span>
                            )}
                            {!grade && isTeacher && (
                              <button
                                onClick={() => {
                                  setSelectedStudent(s.id);
                                  setSelectedAssignment(a.id);
                                  setView("gradebook");
                                }}
                                style={{
                                  padding: "3px 10px",
                                  background: "#1a1a3e",
                                  border: "1px solid #4338ca",
                                  borderRadius: 4,
                                  color: "#818cf8",
                                  fontFamily: fontStack,
                                  fontSize: 10,
                                  cursor: "pointer",
                                }}
                              >
                                Grade
                              </button>
                            )}
                          </>
                        ) : (
                          <StatusBadge status="inactive" />
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* GRADEBOOK */}
        {view === "gradebook" && (
          <div>
            <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 16 }}>
              GRADEBOOK — COMPUTED VIEW OVER LEDGER
            </div>

            {/* Grade table */}
            <div style={{ background: "#111118", border: "1px solid #1a1a2e", borderRadius: 8, padding: 18, marginBottom: 16, overflowX: "auto" }}>
              <table style={{ width: "100%", borderCollapse: "collapse", fontFamily: fontStack, fontSize: 12 }}>
                <thead>
                  <tr style={{ borderBottom: "1px solid #1a1a2e" }}>
                    <th style={{ textAlign: "left", padding: "8px 12px", fontSize: 10, color: "#555", letterSpacing: "0.1em" }}>STUDENT</th>
                    {assignments.map((a) => (
                      <th key={a.id} style={{ textAlign: "center", padding: "8px 12px", fontSize: 10, color: "#555", letterSpacing: "0.1em" }}>
                        {a.title.split(" ").slice(0, 2).join(" ").toUpperCase()}
                      </th>
                    ))}
                    <th style={{ textAlign: "right", padding: "8px 12px", fontSize: 10, color: "#555", letterSpacing: "0.1em" }}>TOTAL</th>
                  </tr>
                </thead>
                <tbody>
                  {getGradebook().map((row) => (
                    <tr key={row.student.id} style={{ borderBottom: "1px solid #0d0d14" }}>
                      <td style={{ padding: "10px 12px", color: "#e2e2e8", fontWeight: 500 }}>{row.student.name}</td>
                      {assignments.map((a) => {
                        const g = row.grades[a.id];
                        return (
                          <td key={a.id} style={{ textAlign: "center", padding: "10px 12px" }}>
                            {g.grade ? (
                              <span style={{ color: g.grade.score >= 90 ? "#34d399" : g.grade.score >= 70 ? "#fbbf24" : "#f87171", fontWeight: 600 }}>
                                {g.grade.score}
                              </span>
                            ) : g.submission ? (
                              <span style={{ color: "#818cf8", fontSize: 10 }}>pending</span>
                            ) : (
                              <span style={{ color: "#333" }}>—</span>
                            )}
                          </td>
                        );
                      })}
                      <td style={{ textAlign: "right", padding: "10px 12px", fontWeight: 700, color: row.total >= 90 ? "#34d399" : row.total >= 70 ? "#fbbf24" : row.total > 0 ? "#f87171" : "#333" }}>
                        {row.total > 0 ? `${row.total}%` : "—"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Grading form (teacher only) */}
            {isTeacher && (
              <div style={{ background: "#111118", border: "1px solid #1a1a2e", borderRadius: 8, padding: 18 }}>
                <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 12 }}>
                  GRADE SUBMISSION
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginBottom: 8 }}>
                  <select
                    value={selectedStudent || ""}
                    onChange={(e) => setSelectedStudent(parseInt(e.target.value) || null)}
                    style={{ padding: "8px 12px", background: "#0a0a0f", border: "1px solid #1a1a2e", borderRadius: 4, color: "#e2e2e8", fontFamily: fontStack, fontSize: 12 }}
                  >
                    <option value="">Select student</option>
                    {students.map((s) => (
                      <option key={s.id} value={s.id}>{s.name}</option>
                    ))}
                  </select>
                  <select
                    value={selectedAssignment || ""}
                    onChange={(e) => setSelectedAssignment(e.target.value)}
                    style={{ padding: "8px 12px", background: "#0a0a0f", border: "1px solid #1a1a2e", borderRadius: 4, color: "#e2e2e8", fontFamily: fontStack, fontSize: 12 }}
                  >
                    <option value="">Select assignment</option>
                    {assignments.map((a) => (
                      <option key={a.id} value={a.id}>{a.title}</option>
                    ))}
                  </select>
                </div>
                <div style={{ display: "flex", gap: 8 }}>
                  <input
                    value={gradeScore}
                    onChange={(e) => setGradeScore(e.target.value)}
                    placeholder="Score"
                    type="number"
                    style={{ width: 80, padding: "8px 12px", background: "#0a0a0f", border: "1px solid #1a1a2e", borderRadius: 4, color: "#e2e2e8", fontFamily: fontStack, fontSize: 12, outline: "none" }}
                  />
                  <input
                    value={gradeFeedback}
                    onChange={(e) => setGradeFeedback(e.target.value)}
                    placeholder="Feedback"
                    style={{ flex: 1, padding: "8px 12px", background: "#0a0a0f", border: "1px solid #1a1a2e", borderRadius: 4, color: "#e2e2e8", fontFamily: fontStack, fontSize: 12, outline: "none" }}
                  />
                  <button
                    onClick={gradeSubmission}
                    style={{ padding: "8px 16px", background: "#0a2e1a", border: "1px solid #166534", borderRadius: 4, color: "#34d399", fontFamily: fontStack, fontSize: 11, cursor: "pointer", fontWeight: 600 }}
                  >
                    Grade
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* INSPECT */}
        {view === "inspect" && (
          <div>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
              <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", textTransform: "uppercase" }}>
                LEDGER INSPECTOR — APPEND-ONLY, HASH-CHAINED
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                <span style={{ width: 7, height: 7, borderRadius: "50%", background: integrity ? "#34d399" : "#f87171" }} />
                <span style={{ fontFamily: fontStack, fontSize: 10, color: integrity ? "#34d399" : "#f87171" }}>
                  CHAIN {integrity ? "INTACT" : "BROKEN"}
                </span>
              </div>
            </div>

            {/* Violations */}
            {violations.length > 0 && (
              <div style={{ background: "#1a0808", border: "1px solid #991b1b", borderRadius: 8, padding: 14, marginBottom: 16 }}>
                <div style={{ fontFamily: fontStack, fontSize: 10, color: "#f87171", letterSpacing: "0.1em", marginBottom: 8 }}>
                  ⚠ WRITE VIOLATIONS CAUGHT
                </div>
                {violations.map((v) => (
                  <div key={v.id} style={{ fontFamily: fontStack, fontSize: 11, color: "#f87171", padding: "4px 0", opacity: 0.9 }}>
                    #{v.id} — {v.speaker}: {v.action} → {v.reason}
                  </div>
                ))}
              </div>
            )}

            {/* Ledger entries */}
            <div style={{ background: "#111118", border: "1px solid #1a1a2e", borderRadius: 8, overflow: "hidden" }}>
              <div style={{ maxHeight: 500, overflowY: "auto" }}>
                {[...ledger].reverse().slice(0, 80).map((e) => (
                  <div
                    key={e.id}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: 8,
                      padding: "6px 14px",
                      borderBottom: "1px solid #0d0d14",
                      fontFamily: fontStack,
                      fontSize: 11,
                      background: e.operation === "write_violation" ? "#1a0808" : "transparent",
                    }}
                  >
                    <span style={{ color: "#333", width: 36, textAlign: "right", flexShrink: 0 }}>#{e.id}</span>
                    <StatusBadge status={e.status === "active" ? "active" : e.status === "broken" ? "broken" : "inactive"} />
                    <span style={{ color: "#818cf8", width: 80, flexShrink: 0 }}>{e.speaker}</span>
                    <span style={{ color: "#888", flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{e.action}</span>
                    <span style={{ color: "#333", fontSize: 9, flexShrink: 0 }}>{e.hash}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* TAMPER TEST */}
        {view === "tamper" && (
          <div>
            <div style={{ fontFamily: fontStack, fontSize: 10, color: "#f87171", letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 16 }}>
              ⚠ AXIOM 8 — WRITE OWNERSHIP VIOLATION TEST
            </div>

            <div style={{ background: "#1a0808", border: "1px solid #991b1b", borderRadius: 8, padding: 18, marginBottom: 16 }}>
              <p style={{ color: "#f87171", fontSize: 12, margin: "0 0 12px 0", lineHeight: 1.6 }}>
                This test attempts to write to another speaker's memory partition.
                Mary MUST reject this. If she doesn't, the system is broken.
              </p>
              <p style={{ color: "#888", fontSize: 11, margin: "0 0 16px 0", fontStyle: "italic" }}>
                Speaking as: <strong style={{ color: "#e2e2e8" }}>{speakerName}</strong>
              </p>

              <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                <select
                  value={selectedStudent || ""}
                  onChange={(e) => setSelectedStudent(parseInt(e.target.value) || null)}
                  style={{ padding: "8px 12px", background: "#0a0a0f", border: "1px solid #991b1b", borderRadius: 4, color: "#e2e2e8", fontFamily: fontStack, fontSize: 12 }}
                >
                  <option value="">Target speaker</option>
                  {[...students, { id: teacherId, name: "Jared (teacher)" }]
                    .filter((s) => s.id !== currentSpeaker)
                    .map((s) => (
                      <option key={s.id} value={s.id}>{s.name}</option>
                    ))}
                </select>
                <button
                  onClick={attemptTamper}
                  style={{
                    padding: "8px 20px",
                    background: "#3a0a0a",
                    border: "1px solid #f87171",
                    borderRadius: 4,
                    color: "#f87171",
                    fontFamily: fontStack,
                    fontSize: 12,
                    cursor: "pointer",
                    fontWeight: 700,
                    letterSpacing: "0.05em",
                  }}
                >
                  ATTEMPT TAMPER
                </button>
              </div>
            </div>

            {/* Tamper log */}
            {tamperLog.length > 0 && (
              <div style={{ background: "#111118", border: "1px solid #1a1a2e", borderRadius: 8, padding: 18 }}>
                <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", letterSpacing: "0.1em", marginBottom: 12 }}>
                  TAMPER ATTEMPT LOG
                </div>
                {tamperLog.map((t, i) => (
                  <div
                    key={i}
                    style={{
                      padding: "10px 14px",
                      background: "#0a0a0f",
                      border: "1px solid #991b1b",
                      borderRadius: 6,
                      marginBottom: 8,
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
                      <span style={{ fontFamily: fontStack, fontSize: 18, color: t.blocked ? "#f87171" : "#34d399" }}>
                        {t.blocked ? "✗" : "✓"}
                      </span>
                      <span style={{ fontFamily: fontStack, fontSize: 12, color: "#e2e2e8" }}>
                        {t.by} → {t.target}'s partition
                      </span>
                      <StatusBadge status={t.blocked ? "broken" : "active"} />
                    </div>
                    <div style={{ fontFamily: fontStack, fontSize: 10, color: "#888", paddingLeft: 26 }}>
                      {t.blocked
                        ? "BLOCKED by Mary. Axiom 8: Only speaker s can write to s's variables. The attempt was recorded in the ledger. Permanently."
                        : "ERROR: This should never happen."}
                    </div>
                    <div style={{ fontFamily: fontStack, fontSize: 10, color: "#555", paddingLeft: 26, marginTop: 4 }}>
                      Ledger entry #{t.entry.id} — hash: {t.entry.hash}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── FOOTER ── */}
      <div
        style={{
          borderTop: "1px solid #1a1a2e",
          padding: "16px 20px",
          textAlign: "center",
          fontFamily: fontStack,
          fontSize: 10,
          color: "#333",
          letterSpacing: "0.05em",
          marginTop: 40,
        }}
      >
        EVERY OPERATION HAD A SPEAKER · EVERY STATE CHANGE HAS A RECEIPT · THE LEDGER IS INTACT · HUMAN LOGIC HOLDS
        <br />
        <span style={{ color: "#222" }}>Jared Lewis, 2026 · All Rights Reserved</span>
      </div>
    </div>
  );
}
