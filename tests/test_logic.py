"""Testes offline da lógica pura (priorização, extração SAP, relatório).

Não dependem de rede nem de credenciais — podem rodar em qualquer ambiente.
Execute com:  python -m pytest -q   (ou)  python tests/test_logic.py
"""

from __future__ import annotations

import os
import sys
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sap_triage.asana import Task  # noqa: E402
from sap_triage.prioritize import (  # noqa: E402
    P_HOJE,
    P_MEDIA,
    P_VENCIDA,
    prioritize,
)
from sap_triage.report import build_report  # noqa: E402
from sap_triage.sap_objects import extract  # noqa: E402

TODAY = date(2026, 6, 24)
EMAIL = "thatiany.silva@fogas.com.br"


def _task(name, due, projects, notes="", completed=False, email=EMAIL):
    return Task(
        gid=name,
        name=name,
        completed=completed,
        due_on=due,
        notes=notes,
        link=f"https://app.asana.com/0/x/{name}",
        assignee_email=email,
        project_names=projects,
    )


def test_priority_order():
    tasks = [
        _task("sem_prazo_kanban", None, ["Kanban"]),
        _task("hoje", "2026-06-24", ["Kanban"]),
        _task("vencida_antiga", "2026-06-01", ["Kanban"]),
        _task("vencida_recente", "2026-06-20", ["Kanban"]),
        _task("futura", "2026-07-01", ["Kanban"]),  # deve ser ignorada
        _task("sem_prazo_outro", None, ["Projeto X"]),  # ignorada (projeto fora)
    ]
    result = prioritize(tasks, TODAY, max_tasks=10)
    names = [pt.task.name for pt in result]
    assert names == [
        "vencida_antiga",
        "vencida_recente",
        "hoje",
        "sem_prazo_kanban",
    ], names
    assert result[0].priority == P_VENCIDA
    assert result[2].priority == P_HOJE
    assert result[3].priority == P_MEDIA


def test_filters_future_and_other_projects():
    tasks = [
        _task("futura", "2026-12-31", ["Kanban"]),
        _task("sem_prazo_fora", None, ["Outro"]),
    ]
    assert prioritize(tasks, TODAY) == []


def test_max_tasks_limit():
    tasks = [
        _task(f"v{i}", "2026-06-01", ["Kanban"]) for i in range(20)
    ]
    assert len(prioritize(tasks, TODAY, max_tasks=10)) == 10


def test_extract_custom_objects():
    notes = (
        "Erro no FM ZVM_CALC_IMPOSTO chamado pelo programa ZSD_RELATORIO. "
        "Verificar include J_1BNFE_GET e a tabela /FHG/T_PARAM. "
        "Reproduzir na transação VA02 e rodar trace na ST05."
    )
    objs = extract(notes)
    assert "ZVM_CALC_IMPOSTO" in objs.custom
    assert "ZSD_RELATORIO" in objs.custom
    assert "J_1BNFE_GET" in objs.custom
    assert "/FHG/T_PARAM" in objs.custom
    assert "VA02" in objs.transactions
    assert "ST05" in objs.transactions


def test_extract_empty():
    objs = extract("Cliente relata lentidão geral no sistema, sem detalhes.")
    assert objs.is_empty()


def test_report_contains_sections():
    tasks = [
        _task(
            "Erro NF-e",
            "2026-06-01",
            ["Nível 2 de atendimento"],
            notes="Falha no FM J_1B_NF_CREATE ao gerar nota.",
        ),
        _task(
            "Lentidão genérica",
            "2026-06-24",
            ["Kanban"],
            notes="Sistema lento, sem objeto específico.",
        ),
    ]
    result = prioritize(tasks, TODAY)
    report = build_report(result, TODAY)
    assert "📋 PLANO DE TRABALHO — 24/06/2026" in report
    assert "[VENCIDA] Erro NF-e" in report
    assert "[HOJE] Lentidão genérica" in report
    assert "J_1B_NF_CREATE" in report
    assert "⚠️ ATENÇÃO:" in report
    assert "Tarefas vencidas críticas:" in report
    assert "Lentidão genérica" in report  # listada em "sem objetos"


def _run_all():
    funcs = [v for k, v in globals().items() if k.startswith("test_")]
    for fn in funcs:
        fn()
        print(f"ok: {fn.__name__}")
    print(f"\n{len(funcs)} testes passaram.")


if __name__ == "__main__":
    _run_all()
