import json
import smtplib
import os

def lambda_handler(event, context):
    try:
        messages = []

        # Verificar si el evento contiene 'Records' antes de intentar acceder a él
        if isinstance(event, dict) and 'Records' in event:
            for record in event['Records']:
                try:
                    messages.append(json.loads(record['body']))
                except json.JSONDecodeError:
                    print(f"⚠️ No se pudo decodificar el mensaje: {record['body']}")
        else:
            # Si no es un evento de SQS, asumir que es una invocación manual
            messages.append(event)

        for message in messages:
            to_email = message.get("to", "")
            cc_email = message.get("cc", "")
            bcc_email = message.get("bcc", "")
            subject = "Notificación Automática"
            body = "Este es un mensaje automático de AWS Lambda."

            smtp_server = os.environ['EMAIL_SMTP_SERVER']
            smtp_port = int(os.environ['EMAIL_SMTP_PORT'])
            email_user = os.environ['EMAIL_USERNAME']
            email_pass = os.environ['EMAIL_PASSWORD']

            # Enviar el correo
            try:
                server = smtplib.SMTP(smtp_server, smtp_port)
                server.starttls()
                server.login(email_user, email_pass)
                # Convertir el mensaje a UTF-8 para evitar errores de codificación
                message_content = f"Subject: {subject}\n\n{body}".encode("utf-8")
                server.sendmail(email_user, [to_email, cc_email, bcc_email], message_content)
                server.quit()
                print(f"✅ Correo enviado a {to_email}")
            except Exception as e:
                print(f"❌ Error enviando correo: {e}")

        return {
            'statusCode': 200,
            'body': json.dumps('Correo enviado correctamente!')
        }
    except Exception as e:
        print(f"❌ Error en la Lambda: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error: {str(e)}")
        }
