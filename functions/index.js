const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions/v2");
const {setGlobalOptions} = require("firebase-functions/v2");
// ***** CAMBIO: Importamos el método moderno para secretos *****
const {defineString} = require("firebase-functions/params");

const admin = require("firebase-admin");
const SibApiV3Sdk = require("sib-api-v3-sdk");

// FIJAMOS LA REGIÓN A LA DE TU BASE DE DATOS
setGlobalOptions({region: "southamerica-east1"});

admin.initializeApp();

// ***** CAMBIO: Definimos la API Key como un parámetro secreto *****
const brevoApiKey = defineString("BREVO_API_KEY");

/**
 * Se activa cada vez que se crea un nuevo documento
 * en la colección 'withdrawal_requests', usando la sintaxis v2.
 */
exports.newWithdrawalRequest = onDocumentCreated(
    "withdrawal_requests/{requestId}",
    async (event) => {
      logger.info("Función newWithdrawalRequest activada.");

      // ***** CAMBIO: Leemos el valor del parámetro secreto *****
      const apiKeyString = brevoApiKey.value();

      if (!apiKeyString) {
        logger.error(
            "API Key de Brevo no fue encontrada en los parámetros.",
        );
        return;
      }

      // Configuramos Brevo con la clave obtenida
      const defaultClient = SibApiV3Sdk.ApiClient.instance;
      const apiKey = defaultClient.authentications["api-key"];
      apiKey.apiKey = apiKeyString;
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
        "email": "dordottinfo@gmail.com",
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
