const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions/v2");
const functions = require("firebase-functions");
const {setGlobalOptions} = require("firebase-functions/v2");

const admin = require("firebase-admin");
const SibApiV3Sdk = require("sib-api-v3-sdk");

// FIJAMOS LA REGIÓN A LA DE TU BASE DE DATOS
setGlobalOptions({region: "southamerica-east1"});

admin.initializeApp();

/**
 * Se activa cada vez que se crea un nuevo documento
 * en la colección 'withdrawal_requests', usando la sintaxis v2.
 */
exports.newWithdrawalRequest = onDocumentCreated(
    "withdrawal_requests/{requestId}",
    async (event) => {
      logger.info("Función newWithdrawalRequest activada.");

      // Obtenemos la API Key y configuramos Brevo AHORA, dentro de la función
      const BREVO_API_KEY = functions.config().brevo.key;

      if (!BREVO_API_KEY) {
        logger.error(
            "API Key de Brevo no encontrada. La función no puede continuar.",
        );
        return;
      }

      const defaultClient = SibApiV3Sdk.ApiClient.instance;
      const apiKey = defaultClient.authentications["api-key"];
      apiKey.apiKey = BREVO_API_KEY;
      const apiInstance = new SibApiV3Sdk.TransactionalEmailsApi();

      const snapshot = event.data;
      if (!snapshot) {
        logger.warn("No data associated with the event");
        return;
      }
      const requestData = snapshot.data();

      const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();

      sendSmtpEmail.subject = `Solicitud de Retiro: ${requestData.userName}`;
      sendSmtpEmail.htmlContent = `
          <h1>Nueva Solicitud de Retiro Pendiente</h1>
          <p>Se ha recibido una nueva solicitud. Revísala en Firebase.</p>
          <hr>
          <h3>Detalles:</h3>
          <ul>
            <li><strong>Usuario:</strong> ${requestData.userName}</li>
            <li><strong>ID de Usuario:</strong> ${requestData.userId}</li>
            <li><strong>Monedas:</strong> ${requestData.coinsToWithdraw}</li>
            <li>
                <strong>Monto a pagar:</strong>
                $${requestData.amountInPesos} (ARS)
            </li>
            <li><strong>Alias/CBU:</strong> ${requestData.userAlias}</li>
          </ul>
        `;
      sendSmtpEmail.sender = {
        "name": "Alertas Spin2Win",
        "email": "notificaciones@spin2win.app", // Email verificado en Brevo
      };
      sendSmtpEmail.to = [{"email": "dordottinfo@gmail.com"}];

      try {
        await apiInstance.sendTransacEmail(sendSmtpEmail);
        logger.info("Notificación de retiro enviada vía Brevo.");
      } catch (error) {
        logger.error("Error al enviar email con Brevo:", error);
      }
    },
);
