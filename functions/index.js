// functions/index.js
//
// Push notifications (FCM, see BLUEPRINT.md 5.12). Firestore itself can't
// call the FCM API - it needs a server context, so these Cloud Functions
// listen for events and push a notification to the relevant user's
// registered device(s) (users/{uid}.fcmTokens, an array since one account
// can be signed in on multiple devices/tabs - written client-side by
// lib/utils/push_notifications.dart).

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

const INVALID_TOKEN_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

// Sends `notification`/`data` to every token in `tokens`, then removes any
// token FCM reports as dead from `uid`'s fcmTokens array so it doesn't grow
// unbounded with uninstalled/expired devices.
async function sendAndPruneTokens(uid, tokens, notification, data) {
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification,
    data,
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
        await sendAndPruneTokens(uid, tokens, { title, body }, { chatId, type: "chatMessage" });
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

    await sendAndPruneTokens(
      letter.parentUid,
      tokens,
      { title: "Warning Letter", body: letter.reason || "A warning letter has been sent regarding your child." },
      { type: "warningLetter", letterId: event.params.letterId }
    );
  }
);
