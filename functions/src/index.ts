import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Inicializa Firebase para que la función pueda acceder a la base de datos
admin.initializeApp();

// Definimos los premios y sus valores en el servidor
const prizes = [
  {label: "10 Monedas", value: 10},
  {label: "20 Monedas", value: 20},
  {label: "30 Monedas", value: 30},
  {label: "40 Monedas", value: 40},
  {label: "50 Monedas", value: 50},
  {label: "60 Monedas", value: 60},
  {label: "70 Monedas", value: 70},
  {label: "Nada", value: 0},
];

// Esta es nuestra función segura, se llama "spinTheWheel"
export const spinTheWheel = onCall(async (request) => {
  // 1. Verifica que el usuario que llama a la función esté autenticado
  if (!request.auth) {
    logger.error("Intento de giro no autenticado.");
    throw new Error("Authentication required.");
  }

  const userId = request.auth.uid;
  logger.info(`Usuario ${userId} ha iniciado un giro.`);

  // 2. Lógica para elegir un premio al azar
  const randomIndex = Math.floor(Math.random() * prizes.length);
  const prizeWon = prizes[randomIndex];

  logger.info(`Usuario ${userId} ha ganado: ${prizeWon.label}`);

  // 3. Si el premio tiene valor, actualiza las monedas del usuario
  if (prizeWon.value > 0) {
    const userRef = admin.firestore().collection("users").doc(userId);
    const historyRef = userRef.collection("rouletteHistory").doc();

    try {
      await admin.firestore().runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw new Error("User document does not exist!");
        }

        const currentCoins = userDoc.data()?.coins || 0;
        const newCoins = currentCoins + prizeWon.value;

        // Actualiza las monedas del usuario
        transaction.update(userRef, {coins: newCoins});
        // Guarda un registro en el historial
        transaction.set(historyRef, {
          prize: prizeWon.label,
          coins: prizeWon.value,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      logger.info(`Monedas del usuario ${userId} actualizadas correctamente.`);
    } catch (error) {
      logger.error(`Error al actualizar monedas para ${userId}:`, error);
      throw new Error("Failed to update user coins.");
    }
  }

  // 4. Devuelve el premio a la aplicación para que muestre la animación
  return {prize: prizeWon};
});
