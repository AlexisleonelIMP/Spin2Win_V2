import {onCall} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore"; // <-- Necesaria para newWithdrawalRequest
import * as logger from "firebase-functions/logger";
import {setGlobalOptions} from "firebase-functions/v2"; // <-- Necesaria para setGlobalOptions
import {defineString} from "firebase-functions/params"; // <-- Necesaria para defineString (Brevo Key)
import * as admin from "firebase-admin";
const SibApiV3Sdk = require("sib-api-v3-sdk"); // <-- Necesaria para Brevo SDK

// Inicializa Firebase (una sola vez)
admin.initializeApp();

// FIJAMOS LA REGIÓN GLOBALMENTE (una sola vez)
setGlobalOptions({region: "southamerica-east1"}); // Asegúrate que esta es la región deseada para tus funciones


// =======================================================================
// ===== FUNCIÓN 1: spinTheWheel (Invocable) =====
// =======================================================================
const prizes = [
  {label: "10 Monedas", value: 10}, {label: "20 Monedas", value: 20},
  {label: "30 Monedas", value: 30}, {label: "40 Monedas", value: 40},
  {label: "50 Monedas", value: 50}, {label: "60 Monedas", value: 60},
  {label: "70 Monedas", value: 70}, {label: "Nada", value: 0},
];

export const spinTheWheel = onCall(async (request) => {
  if (!request.auth) {
    logger.error("Intento de giro no autenticado.");
    throw new Error("Authentication required.");
  }
  const userId = request.auth.uid;
  logger.info(`Usuario ${userId} ha iniciado un giro.`); // Agregado para ver en logs
  const randomIndex = Math.floor(Math.random() * prizes.length);
  const prizeWon = prizes[randomIndex];

  logger.info(`Usuario ${userId} ha ganado: ${prizeWon.label}`); // Agregado para ver en logs

  if (prizeWon.value > 0) {
    const userRef = admin.firestore().collection("users").doc(userId);
    const historyRef = userRef.collection("rouletteHistory").doc();
    try {
      await admin.firestore().runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new Error("User not found");
        const currentCoins = userDoc.data()?.coins || 0;
        const newCoins = currentCoins + prizeWon.value;
        transaction.update(userRef, {coins: newCoins});
        transaction.set(historyRef, {
          prize: prizeWon.label,
          coins: prizeWon.value,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      logger.info(`Monedas del usuario ${userId} actualizadas correctamente.`); // Agregado para ver en logs
    } catch (error) {
      logger.error(`Error al actualizar monedas para ${userId}:`, error); // Agregado para ver en logs
      throw new Error("Failed to update user coins.");
    }
  }
  return {prize: prizeWon};
});


// =======================================================================
// ===== FUNCIÓN 2: newWithdrawalRequest (Activada por Evento) =====
// =======================================================================
const brevoApiKey = defineString("BREVO_API_KEY"); // Define la variable secreta

export const newWithdrawalRequest = onDocumentCreated(
    "users/{userId}/withdrawal_requests/{requestId}", // <-- Ruta del trigger ajustada para tu DB
    async (event) => {
      logger.info("Función newWithdrawalRequest activada."); // Agregado para ver en logs
      const snapshot = event.data;
      if (!snapshot) {
        logger.warn("No hay datos asociados al evento.");
        return;
      }
      const requestData = snapshot.data();
      const userId = requestData.userId; // Este userId viene del documento creado

      const db = admin.firestore();
      const userDoc = await db.collection("users").doc(userId).get();
      const userData = userDoc.data() || {};
      const userCreationDate = userData.createdAt?.toDate().toLocaleDateString("es-AR") || "N/A";
      const coinsBeforeWithdrawal = (userData.coins || 0) + (requestData.coinsToWithdraw || 0); // Asegurarse de que coinsToWithdraw sea 0 si no existe

      const lastWithdrawalQuery = await db.collection("users").doc(userId).collection("withdrawal_requests")
          .where("status", "==", "completed") // Asumiendo que 'completed' es el estado final de un retiro exitoso
          .orderBy("timestamp", "desc")
          .limit(1)
          .get();
      let lastWithdrawalDate = null;
      if (!lastWithdrawalQuery.empty) {
        lastWithdrawalDate = lastWithdrawalQuery.docs[0].data().timestamp.toDate();
      }

      let spinHistoryQuery: admin.firestore.Query = db.collection("users").doc(userId).collection("rouletteHistory");
      if (lastWithdrawalDate) {
        spinHistoryQuery = spinHistoryQuery.where("timestamp", ">", lastWithdrawalDate);
      }
      const spinHistorySnapshot = await spinHistoryQuery.get();
      const spinsSinceLastWithdrawal = spinHistorySnapshot.size;
      const coinsWonSinceLastWithdrawal = spinHistorySnapshot.docs.reduce(
          (sum, doc) => sum + (doc.data().coins || 0), 0);

      const allWithdrawalsQuery = await db.collection("users").doc(userId).collection("withdrawal_requests")
          .where("status", "==", "completed") // Asumiendo que 'completed' es el estado final
          .get();
      const totalWithdrawn = allWithdrawalsQuery.docs.reduce(
          (sum, doc) => sum + (doc.data().amountInPesos || 0), 0);

      // Configuración de Brevo (anteriormente Sendinblue)
      const apiKeyString = brevoApiKey.value();
      if (!apiKeyString) {
        logger.error("API Key de Brevo no encontrada o vacía.");
        return; // Detiene la ejecución si la clave no está configurada
      }
      const defaultClient = SibApiV3Sdk.ApiClient.instance;
      const apiKey = defaultClient.authentications["api-key"];
      apiKey.apiKey = apiKeyString;
      const apiInstance = new SibApiV3Sdk.TransactionalEmailsApi();
      const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();

      sendSmtpEmail.subject = `Solicitud de Retiro: ${requestData.userName}`;
      sendSmtpEmail.htmlContent = `
        <html><body><div style="font-family: Arial, sans-serif; line-height: 1.6;">
          <h1>Nueva Solicitud de Retiro</h1><hr>
          <h2>Datos de la Solicitud</h2>
          <ul>
            <li><strong>Usuario:</strong> ${requestData.userName} (${userData.email || "N/A"})</li>
            <li><strong>Monto a Retirar:</strong> ${requestData.coinsToWithdraw} Monedas</li>
            <li><strong>Equivale a:</strong> $${(requestData.amountInPesos || 0).toFixed(2)} ARS</li>
            <li><strong>Datos de Pago (Alias/CBU):</strong> ${requestData.userAlias}</li>
            <li><strong>Fecha/Hora Solicitud:</strong> ${requestData.timestamp?.toDate().toLocaleString("es-AR") || "N/A"}</li>
          </ul>
          <h2>Verificación de Saldo</h2>
          <ul>
            <li><strong>Saldo Previo (antes del retiro):</strong> ${coinsBeforeWithdrawal} Monedas</li>
            <li><strong>Saldo Restante (después del retiro):</strong> ${userData.coins || 0} Monedas</li>
          </ul>
          <h2>Contexto de Actividad</h2>
          <ul>
            <li><strong>Último retiro completado:</strong> ${lastWithdrawalDate ? lastWithdrawalDate.toLocaleDateString("es-AR") : "Ninguno"}</li>
            <li><strong>Giros realizados desde último retiro:</strong> ${spinsSinceLastWithdrawal}</li>
            <li><strong>Monedas ganadas desde último retiro:</strong> +${coinsWonSinceLastWithdrawal} Monedas</li>
          </ul>
          <h2>Historial del Usuario</h2>
          <ul>
            <li><strong>Usuario desde:</strong> ${userCreationDate}</li>
            <li><strong>Total retirado históricamente:</strong> $${totalWithdrawn.toFixed(2)} ARS</li>
          </ul>
        </div></body></html>
      `;
      sendSmtpEmail.sender = {"name": "Alertas Spin2Win", "email": "dordottinfo@gmail.com"};
      sendSmtpEmail.to = [{"email": "dordottinfo@gmail.com"}]; // Asegúrate que esta es la dirección a la que quieres que llegue el email

      try {
        await apiInstance.sendTransacEmail(sendSmtpEmail);
        logger.info("Notificación de retiro enriquecida enviada.");
      } catch (error) {
        logger.error("Error al enviar email:", error);
        // Puedes lanzar un error aquí para que la app sepa que hubo un problema en el envío
        // throw new Error("Error sending withdrawal notification.");
      }
    },
);