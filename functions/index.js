const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.sendPaymentReminder = onDocumentUpdated(
  "rooms/{roomCode}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!after.reminderTriggered || before.reminderTriggered === after.reminderTriggered) {
      return null;
    }

    const db = getFirestore();
    const messaging = getMessaging();
    const roomCode = event.params.roomCode;
    const storeName = after.storeName || "Split Bill";

    const participants = after.participants || [];
    const unpaidUids = participants
      .filter((p) => !p.isPaid && !p.isHost)
      .map((p) => p.uid)
      .filter(Boolean);

    if (unpaidUids.length === 0) {
      console.log("Semua peserta sudah bayar.");
      await event.data.after.ref.update({ reminderTriggered: false });
      return null;
    }

    const tokenPromises = unpaidUids.map((uid) =>
      db.collection("fcm_tokens").doc(uid).get()
    );
    const tokenDocs = await Promise.all(tokenPromises);

    const hasTokens = tokenDocs.some(
      (doc) => doc.exists && doc.data() && doc.data().token
    );
    if (!hasTokens) {
      console.log("Tidak ada FCM token ditemukan.");
      await event.data.after.ref.update({ reminderTriggered: false });
      return null;
    }

    const bills = after.bills || [];

    const sendPromises = unpaidUids.map(async (uid, index) => {
      const docSnap = tokenDocs[index];
      if (!docSnap || !docSnap.exists || !docSnap.data()) return;
      const token = docSnap.data().token;
      if (!token) return;

      const bill = bills.find((b) => b.uid === uid);
      const rawAmount = bill && bill.total ? bill.total : 0;
      const amount = rawAmount > 0
        ? "Rp " + rawAmount.toLocaleString("id-ID")
        : "tagihan kamu";

      const message = {
        token,
        notification: {
          title: "Jangan lupa bayar!",
          body: "Kamu masih punya " + amount + " untuk split \"" + storeName + "\". Bayar sekarang yuk!",
        },
        data: {
          roomCode: roomCode,
          storeName: storeName,
          type: "payment_reminder",
          amount: rawAmount.toString(),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "payment_reminder",
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      try {
        await messaging.send(message);
        console.log("Notif terkirim ke uid: " + uid);
      } catch (err) {
        console.error("Gagal kirim ke uid " + uid + ": " + err.message);
      }

      // Tulis ke Firestore supaya muncul di NotificationScreen
      try {
        await db
          .collection("notifications")
          .doc(uid)
          .collection("items")
          .add({
            type: "payment_reminder",
            title: "Jangan lupa bayar!",
            body:
              "Kamu masih punya " +
              amount +
              " untuk split \"" +
              storeName +
              "\". Bayar sekarang yuk!",
            roomCode: roomCode,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          });
      } catch (err) {
        console.error("Gagal tulis notif Firestore uid " + uid + ": " + err.message);
      }
    });

    await Promise.all(sendPromises);
    await event.data.after.ref.update({ reminderTriggered: false });
    console.log("Reminder selesai dikirim.");
    return null;
  }
);