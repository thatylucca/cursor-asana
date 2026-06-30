#!/usr/bin/env python3
"""Entrypoint da automação: gera e envia o plano de trabalho diário.

Fluxo:
1. Busca tarefas incompletas no Asana (projetos configurados).
2. Filtra pela assignee alvo.
3. Prioriza (vencidas > vencendo hoje > sem prazo em projetos-alvo).
4. Extrai objetos SAP das descrições.
5. Gera o relatório em português.
6. Envia por email (Gmail API via ADC) ou imprime em modo --dry-run.

Uso:
    python daily_plan.py            # busca, gera e envia o relatório
    python daily_plan.py --dry-run  # só imprime o relatório (não envia)
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime

try:
    from zoneinfo import ZoneInfo
except ImportError:  # Python < 3.9
    ZoneInfo = None  # type: ignore

from sap_triage import config
from sap_triage.asana import AsanaClient, AsanaError, filter_relevant
from sap_triage.email_sender import EmailError, send_via_gmail_adc
from sap_triage.prioritize import prioritize
from sap_triage.report import build_error_report, build_report


def _today():
    if ZoneInfo is not None:
        try:
            return datetime.now(ZoneInfo(config.TIMEZONE)).date()
        except Exception:
            pass
    return datetime.now().date()


def _subject(today) -> str:
    return f"📋 Plano de Trabalho SAP — {today.strftime('%d/%m/%Y')}"


def generate_report(today) -> str:
    """Executa busca + priorização + relatório. Trata erro do Asana."""
    try:
        client = AsanaClient()
        tasks = client.fetch_tasks(config.ASANA_PROJECT_GIDS)
    except AsanaError as exc:
        print(f"[asana] {exc}", file=sys.stderr)
        return build_error_report(
            today, f"Não foi possível buscar tarefas do Asana ({exc})"
        )

    relevant = filter_relevant(tasks, config.TARGET_ASSIGNEE_EMAIL)
    prioritized = prioritize(relevant, today, max_tasks=config.MAX_TASKS)
    return build_report(prioritized, today)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Plano de trabalho diário SAP/Asana")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Apenas imprime o relatório, sem enviar email.",
    )
    args = parser.parse_args(argv)

    today = _today()
    report = generate_report(today)

    if args.dry_run:
        print(report)
        return 0

    try:
        msg_id = send_via_gmail_adc(
            sender=config.EMAIL_FROM,
            to=config.EMAIL_TO,
            subject=_subject(today),
            body=report,
        )
        print(f"Email enviado com sucesso para {config.EMAIL_TO} (id={msg_id}).")
        return 0
    except EmailError as exc:
        print(
            "ERRO: o relatório NÃO pôde ser entregue por email.\n"
            f"Motivo: {exc}\n\n"
            "--- RELATÓRIO (não enviado) ---\n"
            f"{report}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
