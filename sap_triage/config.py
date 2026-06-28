"""Constantes e configuração da automação.

Valores podem ser sobrescritos por variáveis de ambiente para facilitar
testes e ajustes sem alterar o código.
"""

from __future__ import annotations

import os

# --- Asana ------------------------------------------------------------------
ASANA_BASE_URL = os.environ.get("ASANA_BASE_URL", "https://app.asana.com/api/1.0")

# Token PAT do Asana (header: Authorization: Bearer $ASANA_PAT)
ASANA_PAT = os.environ.get("ASANA_PAT", "")

# Projetos onde buscamos as tarefas.
ASANA_PROJECT_GIDS = [
    gid.strip()
    for gid in os.environ.get(
        "ASANA_PROJECT_GIDS", "1168831132413633,537510722828442"
    ).split(",")
    if gid.strip()
]

# --- Filtragem / destino ----------------------------------------------------
TARGET_ASSIGNEE_EMAIL = os.environ.get(
    "TARGET_ASSIGNEE_EMAIL", "thatiany.silva@fogas.com.br"
)
EMAIL_TO = os.environ.get("EMAIL_TO", "thatiany.silva@fogas.com.br")
EMAIL_FROM = os.environ.get("EMAIL_FROM", "me")  # "me" = identidade ADC autenticada

# Projetos cujas tarefas SEM prazo entram como prioridade MEDIUM.
NO_DUE_PROJECT_NAMES = [
    name.strip()
    for name in os.environ.get(
        "NO_DUE_PROJECT_NAMES", "Nível 2 de atendimento,Kanban"
    ).split(",")
    if name.strip()
]

# Limite final de tarefas no plano do dia.
MAX_TASKS = int(os.environ.get("MAX_TASKS", "10"))

# Fuso horário usado para definir "hoje".
TIMEZONE = os.environ.get("TIMEZONE", "America/Sao_Paulo")
