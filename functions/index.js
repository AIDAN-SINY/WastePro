const {onRequest} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const jwt = require("jsonwebtoken");

initializeApp();
const db = getFirestore();

/**
 * CamPay payment webhook.
 *
 * Configure this URL in the CamPay demo dashboard:
 *   https://<region>-waste-pro-f67a5.cloudfunctions.net/campayWebhook
 *
 * Set the webhook key (demo) before deploy:
 *   firebase functions:secrets:set CAMPAY_WEBHOOK_KEY
 * then redeploy. For emulator, put CAMPAY_WEBHOOK_KEY in functions/.env
 */
exports.campayWebhook = onRequest(
    {
      cors: true,
      secrets: ["CAMPAY_WEBHOOK_KEY"],
      invoker: "public",
    },
    async (req, res) => {
      try {
        const signature = req.query.signature || req.body?.signature;
        const externalReference =
          req.query.external_reference || req.body?.external_reference;
        const status = String(
            req.query.status || req.body?.status || "",
        ).toUpperCase();
        const operator = req.query.operator || req.body?.operator || null;
        const reason = req.query.reason || req.body?.reason || null;
        const operatorReference =
          req.query.operator_reference || req.body?.operator_reference || null;
        const reference =
          req.query.reference || req.body?.reference || null;

        if (!signature) {
          return res.status(400).send("Missing signature");
        }

        const webhookKey = process.env.CAMPAY_WEBHOOK_KEY;
        if (!webhookKey) {
          return res.status(500).send("Webhook key not configured");
        }

        let decoded;
        try {
          decoded = jwt.verify(signature, webhookKey, {algorithms: ["HS256"]});
        } catch (err) {
          console.warn("Invalid CamPay signature", err.message);
          return res.status(401).send("Invalid signature");
        }

        if (
          !decoded ||
          String(decoded.source || "").toLowerCase() !== "campay"
        ) {
          return res.status(401).send("Invalid webhook source");
        }

        const mapped =
          status === "SUCCESSFUL" ?
            "completed" :
            status === "FAILED" ?
              "failed" :
              "pending";

        let docRef = null;
        if (reference) {
          docRef = db.collection("transactions").doc(String(reference));
        } else if (externalReference) {
          const snap = await db
              .collection("transactions")
              .where("externalReference", "==", String(externalReference))
              .limit(1)
              .get();
          if (!snap.empty) {
            docRef = snap.docs[0].ref;
          }
        }

        if (!docRef) {
          await db.collection("webhook_events").add({
            provider: "campay",
            status: mapped,
            campayStatus: status,
            externalReference: externalReference || null,
            reference: reference || null,
            operator,
            reason,
            operatorReference,
            receivedAt: FieldValue.serverTimestamp(),
            matched: false,
          });
          return res.status(202).send("Accepted (unmatched)");
        }

        await docRef.set(
            {
              status: mapped,
              operator,
              reason,
              operatorReference,
              updatedAt: FieldValue.serverTimestamp(),
              webhookReceivedAt: FieldValue.serverTimestamp(),
              syncedBy: "webhook",
            },
            {merge: true},
        );

        await db.collection("webhook_events").add({
          provider: "campay",
          status: mapped,
          campayStatus: status,
          transactionId: docRef.id,
          externalReference: externalReference || null,
          operator,
          reason,
          operatorReference,
          receivedAt: FieldValue.serverTimestamp(),
          matched: true,
        });

        return res.status(200).send("OK");
      } catch (error) {
        console.error("campayWebhook error", error);
        return res.status(500).send("Internal error");
      }
    },
);
