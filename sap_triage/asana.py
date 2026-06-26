"""Cliente mínimo da API do Asana usando apenas a biblioteca padrão.

Evita dependências externas para que a automação funcione em ambientes
restritos. Usa o token PAT no header ``Authorization: Bearer``.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Iterable

from . import config


class AsanaError(RuntimeError):
    """Erro ao comunicar com a API do Asana."""


# Campos que pedimos ao Asana para cada tarefa.
TASK_OPT_FIELDS = ",".join(
    [
        "name",
        "completed",
        "due_on",
        "due_at",
        "notes",
        "permalink_url",
        "assignee.email",
        "assignee.name",
        "projects.name",
    ]
)


@dataclass
class Task:
    """Representa uma tarefa do Asana já normalizada."""

    gid: str
    name: str
    completed: bool
    due_on: str | None  # "YYYY-MM-DD" ou None
    notes: str
    link: str
    assignee_email: str | None
    project_names: list[str] = field(default_factory=list)

    @classmethod
    def from_api(cls, data: dict[str, Any]) -> "Task":
        assignee = data.get("assignee") or {}
        projects = data.get("projects") or []
        return cls(
            gid=data.get("gid", ""),
            name=(data.get("name") or "").strip(),
            completed=bool(data.get("completed")),
            due_on=data.get("due_on"),
            notes=data.get("notes") or "",
            link=data.get("permalink_url") or "",
            assignee_email=(assignee.get("email") or "").lower() or None,
            project_names=[p.get("name", "") for p in projects],
        )


class AsanaClient:
    def __init__(self, pat: str | None = None, base_url: str | None = None) -> None:
        self.pat = pat if pat is not None else config.ASANA_PAT
        self.base_url = (base_url or config.ASANA_BASE_URL).rstrip("/")
        if not self.pat:
            raise AsanaError("ASANA_PAT não configurado.")

    def _get(self, path: str, params: dict[str, str]) -> dict[str, Any]:
        url = f"{self.base_url}{path}?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url)
        req.add_header("Authorization", f"Bearer {self.pat}")
        req.add_header("Accept", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:  # pragma: no cover - rede
            body = exc.read().decode("utf-8", "replace")
            raise AsanaError(f"HTTP {exc.code} em {path}: {body}") from exc
        except urllib.error.URLError as exc:  # pragma: no cover - rede
            raise AsanaError(f"Falha de rede ao acessar {url}: {exc.reason}") from exc

    def iter_project_tasks(self, project_gid: str) -> Iterable[Task]:
        """Itera todas as tarefas de um projeto, lidando com paginação."""
        offset: str | None = None
        while True:
            params = {"opt_fields": TASK_OPT_FIELDS, "limit": "100"}
            if offset:
                params["offset"] = offset
            payload = self._get(f"/projects/{project_gid}/tasks", params)
            for item in payload.get("data", []):
                yield Task.from_api(item)
            next_page = payload.get("next_page")
            if not next_page or not next_page.get("offset"):
                break
            offset = next_page["offset"]

    def fetch_tasks(self, project_gids: list[str]) -> list[Task]:
        """Busca tarefas de vários projetos, sem duplicar por gid."""
        seen: dict[str, Task] = {}
        for gid in project_gids:
            for task in self.iter_project_tasks(gid):
                if task.gid in seen:
                    # Mescla nomes de projetos quando a tarefa aparece em mais de um.
                    for name in task.project_names:
                        if name not in seen[task.gid].project_names:
                            seen[task.gid].project_names.append(name)
                else:
                    seen[task.gid] = task
        return list(seen.values())


def filter_relevant(tasks: list[Task], assignee_email: str) -> list[Task]:
    """Mantém apenas tarefas incompletas atribuídas ao email alvo."""
    target = assignee_email.lower()
    return [
        t
        for t in tasks
        if not t.completed and (t.assignee_email or "") == target
    ]
