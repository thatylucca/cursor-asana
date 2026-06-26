"""Envio do relatório por email usando a Gmail API com ADC.

Segue as regras da automação:
- Usa Application Default Credentials (ADC), sem chaves de API.
- Não armazena segredos manualmente.

Se as bibliotecas do Google ou as credenciais ADC não estiverem
disponíveis, levanta ``EmailError`` para que o chamador possa registrar a
falha e cair em um modo alternativo (ex.: salvar/imprimir o relatório).
"""

from __future__ import annotations

import base64
from email.mime.text import MIMEText

GMAIL_SEND_SCOPE = "https://www.googleapis.com/auth/gmail.send"


class EmailError(RuntimeError):
    """Erro ao enviar email."""


def _build_raw_message(sender: str, to: str, subject: str, body: str) -> str:
    msg = MIMEText(body, _charset="utf-8")
    msg["to"] = to
    msg["from"] = sender
    msg["subject"] = subject
    return base64.urlsafe_b64encode(msg.as_bytes()).decode("ascii")


def send_via_gmail_adc(
    *,
    sender: str,
    to: str,
    subject: str,
    body: str,
) -> str:
    """Envia email via Gmail API autenticando por ADC.

    Retorna o id da mensagem enviada. Levanta ``EmailError`` em falha.
    """
    try:
        import google.auth
        from google.auth.transport.requests import Request  # noqa: F401
        from googleapiclient.discovery import build
    except ImportError as exc:  # dependências não instaladas
        raise EmailError(
            "Bibliotecas google-auth/google-api-python-client ausentes. "
            "Instale com: pip install -r requirements.txt"
        ) from exc

    try:
        credentials, _ = google.auth.default(scopes=[GMAIL_SEND_SCOPE])
    except Exception as exc:  # ADC não configurado
        raise EmailError(
            "ADC indisponível. Configure as credenciais do ambiente "
            "(Application Default Credentials) com escopo de envio do Gmail."
        ) from exc

    try:
        service = build("gmail", "v1", credentials=credentials, cache_discovery=False)
        raw = _build_raw_message(sender, to, subject, body)
        sent = (
            service.users()
            .messages()
            .send(userId="me", body={"raw": raw})
            .execute()
        )
        return sent.get("id", "")
    except Exception as exc:  # falha de API/permissão
        raise EmailError(f"Falha ao enviar via Gmail API: {exc}") from exc
