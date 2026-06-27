"""Priorização das tarefas conforme a ordem estrita da automação.

Ordem:
1. VENCIDAS  (due_date < hoje)            -> prioridade MÁXIMA
2. VENCENDO HOJE (due_date == hoje)       -> prioridade HIGH
3. SEM PRAZO em projetos-alvo             -> prioridade MEDIUM
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from . import config
from .asana import Task

# Rótulos de prioridade.
P_VENCIDA = "VENCIDA"
P_HOJE = "HOJE"
P_MEDIA = "MEDIA"

# Peso numérico para ordenação (menor = mais importante).
_WEIGHT = {P_VENCIDA: 0, P_HOJE: 1, P_MEDIA: 2}


@dataclass
class PrioritizedTask:
    task: Task
    priority: str
    due_date: date | None


def _parse_due(due_on: str | None) -> date | None:
    if not due_on:
        return None
    try:
        return date.fromisoformat(due_on)
    except ValueError:
        return None


def classify(
    task: Task,
    today: date,
    no_due_projects: list[str] | None = None,
) -> PrioritizedTask | None:
    """Classifica uma tarefa; retorna ``None`` se ela não entra no plano."""
    no_due_projects = no_due_projects or config.NO_DUE_PROJECT_NAMES
    due = _parse_due(task.due_on)

    if due is not None:
        if due < today:
            return PrioritizedTask(task, P_VENCIDA, due)
        if due == today:
            return PrioritizedTask(task, P_HOJE, due)
        # Prazo futuro: fora do escopo do plano do dia.
        return None

    # Sem prazo: só entra se pertencer a um dos projetos-alvo.
    if any(p in no_due_projects for p in task.project_names):
        return PrioritizedTask(task, P_MEDIA, None)
    return None


def prioritize(
    tasks: list[Task],
    today: date,
    *,
    max_tasks: int | None = None,
    no_due_projects: list[str] | None = None,
) -> list[PrioritizedTask]:
    """Aplica a classificação, ordena e limita a ~N tarefas."""
    max_tasks = max_tasks if max_tasks is not None else config.MAX_TASKS

    classified = [
        pt
        for pt in (classify(t, today, no_due_projects) for t in tasks)
        if pt is not None
    ]

    def sort_key(pt: PrioritizedTask):
        # 1) peso da prioridade; 2) vencidas mais antigas primeiro;
        # 3) nome para estabilidade.
        due_ordinal = pt.due_date.toordinal() if pt.due_date else 10**9
        return (_WEIGHT[pt.priority], due_ordinal, pt.task.name.lower())

    classified.sort(key=sort_key)
    return classified[:max_tasks]
