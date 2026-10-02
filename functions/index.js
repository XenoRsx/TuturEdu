// functions/index.js
//
// Push notifications (FCM, see BLUEPRINT.md 5.12). Firestore itself can't
// call the FCM API - it needs a server context, so these Cloud Functions
// listen for events and push a notification to the relevant user's
// registered device(s) (users/{uid}.fcmTokens, an array since one account
// can be signed in on multiple devices/tabs - written client-side by
// lib/utils/push_notifications.dart).

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const nodemailer = require("nodemailer");
const crypto = require("crypto");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

const INVALID_TOKEN_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

// Must match defaultNotificationSoundId in lib/utils/notification_sounds.dart.
const DEFAULT_SOUND = "option2_marimba";

// Sends `notification`/`data` to every token in `tokens`, then removes any
// token FCM reports as dead from `uid`'s fcmTokens array so it doesn't grow
// unbounded with uninstalled/expired devices. `soundId` (users/{uid}.
// notificationSound) must match a raw resource name in
// android/app/src/main/res/raw/ - Android only, Web Push has no
// cross-browser custom-sound support so this field is simply ignored there.
async function sendAndPruneTokens(uid, tokens, notification, data, soundId) {
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification,
    data,
    android: {
      notification: {
        sound: soundId || DEFAULT_SOUND,
      },
    },
  });

  const staleTokens = response.responses
    .map((result, i) => (!result.success && INVALID_TOKEN_CODES.has(result.error?.code) ? tokens[i] : null))
    .filter(Boolean);

  if (staleTokens.length > 0) {
    await db.collection("users").doc(uid).update({
      fcmTokens: FieldValue.arrayRemove(...staleTokens),
    });
  }
}

// New chat message -> notify every other participant (covers 1:1, group,
// quick replies, and overtime/scheduled replies alike - they all end up as
// a normal document in this same sub-collection).
exports.onNewChatMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const { chatId } = event.params;
    const chatDoc = await db.collection("chats").doc(chatId).get();
    const chat = chatDoc.data();
    if (!chat) return;

    const recipients = (chat.participants || []).filter((uid) => uid !== message.senderId);
    if (recipients.length === 0) return;

    const senderDoc = await db.collection("users").doc(message.senderId).get();
    const senderName = senderDoc.data()?.name || "Someone";

    const messageText = message.attachmentName ? `📎 ${message.attachmentName}` : (message.text || "New message");
    const title = chat.isGroup ? (chat.groupName || "Group Chat") : senderName;
    const body = chat.isGroup ? `${senderName}: ${messageText}` : messageText;

    await Promise.all(
      recipients.map(async (uid) => {
        const userDoc = await db.collection("users").doc(uid).get();
        const tokens = userDoc.data()?.fcmTokens || [];
        const soundId = userDoc.data()?.notificationSound;
        await sendAndPruneTokens(uid, tokens, { title, body }, { chatId, type: "chatMessage" }, soundId);
      })
    );
  }
);

// New warning letter -> notify the linked parent (fulfils the "receive
// warning letter notification" line from BLUEPRINT.md 4.1's Parent Module
// scope, which was waiting on this exact prerequisite).
exports.onNewWarningLetter = onDocumentCreated(
  "warningLetters/{letterId}",
  async (event) => {
    const letter = event.data?.data();
    if (!letter?.parentUid) return;

    const parentDoc = await db.collection("users").doc(letter.parentUid).get();
    const tokens = parentDoc.data()?.fcmTokens || [];
    const soundId = parentDoc.data()?.notificationSound;

    await sendAndPruneTokens(
      letter.parentUid,
      tokens,
      { title: "Warning Letter", body: letter.reason || "A warning letter has been sent regarding your child." },
      { type: "warningLetter", letterId: event.params.letterId },
      soundId
    );
  }
);

// New announcement -> notify every Student enrolled in its subject, plus
// each of those students' linked parent (see
// BLUEPRINT.md 5.19). Queries on `subjects array-contains` only and filters
// role in code rather than adding `role ==` to the query - combining the two
// on different fields would need a composite index, and the Teacher(s) of
// that subject are the only non-students this can match anyway.
exports.onNewAnnouncement = onDocumentCreated(
  "announcements/{announcementId}",
  async (event) => {
    const announcement = event.data?.data();
    if (!announcement?.subjectLevel) return;

    const usersSnap = await db
      .collection("users")
      .where("subjects", "array-contains", announcement.subjectLevel)
      .get();

    const students = usersSnap.docs.filter((doc) => doc.data().role === "Student");
    if (students.length === 0) return;

    // Parents of those students get it too (deduped - one parent with two
    // kids in the same class is notified once).
    const parentUids = [...new Set(students.map((doc) => doc.data().parentUid).filter(Boolean))];
    const parentDocs = await Promise.all(parentUids.map((uid) => db.collection("users").doc(uid).get()));
    const recipients = [...students, ...parentDocs.filter((doc) => doc.exists)];

    const body = (announcement.body || "").length > 120
      ? `${announcement.body.slice(0, 117)}...`
      : (announcement.body || "New announcement");

    await Promise.all(
      recipients.map((doc) =>
        sendAndPruneTokens(
          doc.id,
          doc.data().fcmTokens || [],
          { title: `📢 ${announcement.subjectLevel}: ${announcement.title || "Announcement"}`, body },
          { type: "announcement", announcementId: event.params.announcementId },
          doc.data().notificationSound
        )
      )
    );
  }
);

// New message report -> notify every Admin so it gets reviewed in Flagged
// Messages (BLUEPRINT.md 5.22). The message text itself is deliberately NOT
// put in the push body - only the reason - so reported content doesn't
// spread further via lock-screen notifications.
exports.onNewReport = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const report = event.data?.data();
    if (!report) return;

    const adminsSnap = await db.collection("users").where("role", "==", "Admin").get();

    await Promise.all(
      adminsSnap.docs.map((doc) =>
        sendAndPruneTokens(
          doc.id,
          doc.data().fcmTokens || [],
          { title: "🚩 Message reported", body: `Reason: ${report.reason || "Other"}` },
          { type: "report", reportId: event.params.reportId },
          doc.data().notificationSound
        )
      )
    );
  }
);

// ----- Server-side quiz scoring (BLUEPRINT.md 9.8) -----
// Answer keys live in quizzes/{quizId}/answerKeys/{questionId} (readable
// only by the quiz's teacher - see firestore.rules), never on the question
// docs students read. Quizzes saved before this existed still carry
// `correctIndex` on the question doc itself; this migrates those on first
// use (moves the value into answerKeys and strips it from the question) so
// a legacy quiz stops leaking its answers the first time anyone plays it.
async function loadAnswerKey(quizId, questionDocs) {
  const quizRef = db.collection("quizzes").doc(quizId);
  const keysSnap = await quizRef.collection("answerKeys").get();
  const keys = {};
  keysSnap.docs.forEach((doc) => {
    keys[doc.id] = doc.data().correctIndex;
  });

  const batch = db.batch();
  let pending = false;
  questionDocs.forEach((q) => {
    const legacy = q.data().correctIndex;
    if (typeof legacy === "number") {
      if (typeof keys[q.id] !== "number") keys[q.id] = legacy;
      batch.set(quizRef.collection("answerKeys").doc(q.id), {
        correctIndex: keys[q.id],
        createdBy: q.data().createdBy || null,
      });
      batch.update(q.ref, { correctIndex: FieldValue.delete() });
      pending = true;
    }
  });
  if (pending) await batch.commit();

  return keys;
}

// Self-Paced submit. Replaces attempt_quiz_screen.dart computing the score
// itself and writing quizAttempts directly (which let a student write any
// score they liked) - firestore.rules now denies client writes to
// quizAttempts entirely, this is the only path in.
exports.submitQuizAttempt = onCall({ region: "asia-southeast1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");

  const quizId = request.data?.quizId;
  const answers = request.data?.answers;
  if (typeof quizId !== "string" || !answers || typeof answers !== "object") {
    throw new HttpsError("invalid-argument", "Missing quizId or answers.");
  }

  const [userDoc, quizDoc] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("quizzes").doc(quizId).get(),
  ]);
  const user = userDoc.data();
  const quiz = quizDoc.data();
  if (!quiz) throw new HttpsError("not-found", "Quiz not found.");
  if (user?.role !== "Student" || !(user.subjects || []).includes(quiz.subjectLevel)) {
    throw new HttpsError("permission-denied", "This quiz isn't available for your subjects.");
  }
  if (quiz.mode !== "self_paced" && quiz.mode !== "both") {
    throw new HttpsError("failed-precondition", "This quiz isn't a Self-Paced quiz.");
  }
  if (quiz.dueDate && quiz.dueDate.toMillis() < Date.now()) {
    throw new HttpsError("failed-precondition", "This quiz's due date has passed.");
  }

  const questionsSnap = await db
    .collection("quizzes").doc(quizId).collection("questions").orderBy("order").get();
  const keys = await loadAnswerKey(quizId, questionsSnap.docs);

  let score = 0;
  let totalPoints = 0;
  const cleanAnswers = {};
  const correctAnswers = {};
  for (const q of questionsSnap.docs) {
    const data = q.data();
    const selected = answers[q.id];
    const optionCount = (data.options || []).length;
    if (!Number.isInteger(selected) || selected < 0 || selected >= optionCount) {
      throw new HttpsError("invalid-argument", "Please answer every question before submitting.");
    }
    const points = Number.isInteger(data.points) ? data.points : 100;
    totalPoints += points;
    cleanAnswers[q.id] = selected;
    correctAnswers[q.id] = keys[q.id];
    if (selected === keys[q.id]) score += points;
  }

  const maxAttempts = Number.isInteger(quiz.maxAttempts) ? quiz.maxAttempts : 1;
  const attemptRef = db.collection("quizAttempts").doc(`${quizId}_${uid}`);

  const attemptsUsed = await db.runTransaction(async (tx) => {
    const existing = (await tx.get(attemptRef)).data();
    // Attempts written before attemptsUsed existed only ever had one.
    const used = existing ? (existing.attemptsUsed ?? 1) : 0;
    if (used >= maxAttempts) {
      throw new HttpsError("failed-precondition", "You've used all your attempts for this quiz.");
    }
    tx.set(attemptRef, {
      quizId,
      studentUid: uid,
      status: "completed",
      startedAt: existing?.startedAt ?? FieldValue.serverTimestamp(),
      completedAt: FieldValue.serverTimestamp(),
      score,
      totalPoints,
      answers: cleanAnswers,
      correctAnswers,
      attemptsUsed: used + 1,
    });
    return used + 1;
  });

  return { score, totalPoints, correctAnswers, attemptsUsed };
});

// Live Session answer. Replaces live_quiz_play_screen.dart deciding for
// itself whether it was right and incrementing its own score. Checks the
// session is mid-question, that it's the question currently being asked,
// that the time limit (plus a small grace for network lag) hasn't passed,
// and that this student hasn't already answered it.
const LIVE_ANSWER_GRACE_MS = 3000;

exports.submitLiveAnswer = onCall({ region: "asia-southeast1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");

  const { sessionId, questionId, selectedIndex } = request.data || {};
  if (typeof sessionId !== "string" || typeof questionId !== "string" || !Number.isInteger(selectedIndex)) {
    throw new HttpsError("invalid-argument", "Missing sessionId, questionId or selectedIndex.");
  }

  const sessionRef = db.collection("quizSessions").doc(sessionId);
  const session = (await sessionRef.get()).data();
  if (!session) throw new HttpsError("not-found", "Session not found.");
  if (session.status !== "active") {
    throw new HttpsError("failed-precondition", "This question is no longer open.");
  }

  const questionsSnap = await db
    .collection("quizzes").doc(session.quizId).collection("questions").orderBy("order").get();
  const current = questionsSnap.docs[session.currentQuestionIndex ?? 0];
  if (!current || current.id !== questionId) {
    throw new HttpsError("failed-precondition", "This question is no longer open.");
  }

  const question = current.data();
  const limitMs = (Number.isInteger(question.timeLimitSeconds) ? question.timeLimitSeconds : 20) * 1000;
  const startedAtMs = session.currentQuestionStartedAt?.toMillis?.() ?? Date.now();
  const elapsedMs = Math.max(0, Date.now() - startedAtMs);
  if (elapsedMs > limitMs + LIVE_ANSWER_GRACE_MS) {
    throw new HttpsError("deadline-exceeded", "Time's up for this question.");
  }
  if (selectedIndex < 0 || selectedIndex >= (question.options || []).length) {
    throw new HttpsError("invalid-argument", "Invalid option.");
  }

  const keys = await loadAnswerKey(session.quizId, questionsSnap.docs);
  const correctIndex = keys[questionId];
  const correct = selectedIndex === correctIndex;
  const points = Number.isInteger(question.points) ? question.points : 100;

  const participantRef = sessionRef.collection("participants").doc(uid);
  await db.runTransaction(async (tx) => {
    const participant = (await tx.get(participantRef)).data();
    if (!participant) throw new HttpsError("permission-denied", "You haven't joined this session.");
    if (participant.answers && participant.answers[questionId]) {
      throw new HttpsError("already-exists", "You've already answered this question.");
    }
    tx.update(participantRef, {
      [`answers.${questionId}`]: {
        selectedIndex,
        correct,
        correctIndex,
        timeTakenMs: Math.min(elapsedMs, limitMs),
      },
      score: FieldValue.increment(correct ? points : 0),
    });
  });

  return { correct, correctIndex };
});

// Admin-only: permanently deletes ANOTHER user's account (Firebase Auth +
// Firestore profile). Needs the Admin SDK - the client SDK can only ever
// delete the CURRENTLY signed-in user's own account (see
// settings_screen.dart's self-service delete), there's no client-side way
// to remove someone else's Auth account. Callable, so manage_users_screen.dart
// invokes it directly (no HTTP endpoint/CORS setup needed). Explicit region
// to match the rest of this project - onCall has no trigger resource to
// infer a region from the way the Firestore-triggered functions above do.
exports.deleteUserAccount = onCall({ region: "asia-southeast1" }, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const targetUid = request.data?.uid;
  if (!targetUid || typeof targetUid !== "string") {
    throw new HttpsError("invalid-argument", "Missing target uid.");
  }

  if (targetUid === callerUid) {
    throw new HttpsError("failed-precondition", "Use Settings to delete your own account.");
  }

  const callerDoc = await db.collection("users").doc(callerUid).get();
  if (callerDoc.data()?.role !== "Admin") {
    throw new HttpsError("permission-denied", "Only an Admin can delete other users' accounts.");
  }

  await db.collection("users").doc(targetUid).delete();

  try {
    await auth.deleteUser(targetUid);
  } catch (error) {
    // Already gone from Authentication (e.g. previously removed by hand via
    // the Console) - the Firestore profile deletion above still succeeded,
    // so treat this as an acceptable no-op instead of failing the call.
    if (error.code !== "auth/user-not-found") {
      throw error;
    }
  }

  return { success: true };
});

// ----- MFA (email OTP), see BLUEPRINT.md 5.17 -----
//
// Mandatory second factor at every fresh sign-in (login AND self-
// registration) for every role. Firebase Auth has no built-in "send an
// arbitrary code by email" multi-factor option (its native MFA only does
// SMS/TOTP) - this is a custom implementation: a random 6-digit code,
// hashed and stored in mfaCodes/{uid} with a 5-minute expiry, emailed via
// Gmail SMTP through nodemailer. Requires two secrets set once via
// `firebase functions:secrets:set MFA_SMTP_USER` and `...MFA_SMTP_PASS`
// (a Gmail address + App Password - the Google Account needs 2-Step
// Verification on to generate an App Password at
// myaccount.google.com/apppasswords). Never set secrets by pasting them
// into chat/a shared terminal - run that command yourself so the value
// only ever passes through your own local Firebase CLI session.
const MFA_SMTP_USER = defineSecret("MFA_SMTP_USER");
const MFA_SMTP_PASS = defineSecret("MFA_SMTP_PASS");

const MFA_CODE_TTL_MS = 5 * 60 * 1000;
const MFA_MAX_ATTEMPTS = 5;

function hashMfaCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

// Branded HTML body for the OTP email - inline styles throughout, since
// most email clients strip <style> blocks and ignore external CSS.
// Colors match kBrandBlue/kInkDark/kInkMuted etc. in lib/main.dart, so the
// email reads as the same product as the app.
function buildMfaEmailHtml(code) {
  return `
    <div style="background:#F1F5F9;padding:32px 16px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">
      <div style="max-width:440px;margin:0 auto;background:#FFFFFF;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(16,38,64,0.08);">
        <div style="background:#2E86C1;padding:22px 32px;">
          <span style="color:#FFFFFF;font-size:19px;font-weight:700;letter-spacing:-0.3px;">TuturEdu</span>
        </div>
        <div style="padding:32px;">
          <p style="margin:0 0 6px;font-size:11.5px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;color:#2E86C1;">Verification Code</p>
          <h1 style="margin:0 0 16px;font-size:21px;line-height:1.3;color:#1B3B5F;">Confirm it's you</h1>
          <p style="margin:0 0 24px;font-size:14px;line-height:1.6;color:#475569;">
            Use the code below to finish signing in to your TuturEdu account.
            It expires in <strong>5 minutes</strong>.
          </p>
          <div style="background:#F4FAF7;border:1px solid #DCE6EE;border-radius:12px;padding:20px 16px;text-align:center;margin-bottom:24px;">
            <span style="font-size:32px;font-weight:700;letter-spacing:9px;color:#1B3B5F;font-family:'Courier New',monospace;">${code}</span>
          </div>
          <p style="margin:0;font-size:12.5px;line-height:1.6;color:#94A3B8;">
            If you didn't request this code, you can safely ignore this email —
            someone may have typed your email address by mistake.
          </p>
        </div>
        <div style="background:#F8FAFC;padding:14px 32px;border-top:1px solid #EEF2F6;">
          <p style="margin:0;font-size:11px;color:#94A3B8;">Pusat Tuisyen Arena Matriks &middot; TuturEdu Chat Platform</p>
        </div>
      </div>
    </div>
  `;
}

// Generates a fresh code, stores its hash (never the plaintext) in
// Firestore, and emails the plaintext code to the CALLER'S OWN verified
// account email - there's no "target uid" parameter, so this can never be
// used to spam an arbitrary address.
exports.sendMfaCode = onCall(
  { region: "asia-southeast1", secrets: [MFA_SMTP_USER, MFA_SMTP_PASS] },
  async (request) => {
    const uid = request.auth?.uid;
    const email = request.auth?.token?.email;
    if (!uid || !email) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const code = crypto.randomInt(0, 1000000).toString().padStart(6, "0");

    await db.collection("mfaCodes").doc(uid).set({
      codeHash: hashMfaCode(code),
      expiresAt: Date.now() + MFA_CODE_TTL_MS,
      attempts: 0,
    });

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: { user: MFA_SMTP_USER.value(), pass: MFA_SMTP_PASS.value() },
    });

    await transporter.sendMail({
      from: `"TuturEdu" <${MFA_SMTP_USER.value()}>`,
      to: email,
      subject: `Your TuturEdu verification code: ${code}`,
      text:
        `Your TuturEdu sign-in verification code is ${code}.\n\n` +
        "It expires in 5 minutes. If you didn't request this, you can safely ignore this email.",
      html: buildMfaEmailHtml(code),
    });

    return { success: true };
  }
);

// Checks `code` against the hash stored for the CALLER's own uid - a
// mismatch increments `attempts` (capped at MFA_MAX_ATTEMPTS before the
// code is invalidated outright) rather than revealing anything about the
// stored value.
exports.verifyMfaCode = onCall({ region: "asia-southeast1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const code = request.data?.code;
  if (!code || typeof code !== "string") {
    throw new HttpsError("invalid-argument", "Missing code.");
  }

  const docRef = db.collection("mfaCodes").doc(uid);
  const doc = await docRef.get();
  const data = doc.data();

  if (!data) {
    throw new HttpsError("failed-precondition", "No verification code was requested. Request a new one.");
  }

  if (Date.now() > data.expiresAt) {
    await docRef.delete();
    throw new HttpsError("deadline-exceeded", "This code has expired. Request a new one.");
  }

  if (data.attempts >= MFA_MAX_ATTEMPTS) {
    await docRef.delete();
    throw new HttpsError("resource-exhausted", "Too many incorrect attempts. Request a new code.");
  }

  if (hashMfaCode(code) !== data.codeHash) {
    await docRef.update({ attempts: FieldValue.increment(1) });
    throw new HttpsError("permission-denied", "Incorrect code.");
  }

  await docRef.delete();

  // A correct OTP proves the caller controls this account's email inbox -
  // the same thing Firebase's own sendEmailVerification() link proves - so
  // record it as Firebase Auth's emailVerified flag instead of making the
  // user click a second, redundant verification link at sign-up.
  if (request.auth.token.email_verified !== true) {
    await auth.updateUser(uid, { emailVerified: true });
  }

  return { success: true };
});
