"""Geração do relatório de plano de trabalho em português."""

from __future__ import annotations

from datetime import date

from .prioritize import P_HOJE, P_MEDIA, P_VENCIDA, PrioritizedTask
from .sap_objects import SapObjects, extract

# Rótulo exibido no relatório por prioridade.
_LABEL = {
    P_VENCIDA: "VENCIDA",
    P_HOJE: "HOJE",
    P_MEDIA: "MEDIA",
}

NO_SAP_MARK = "⚠️ Chamado sem objetos SAP — investigação funcional necessária"


def _resumo_problema(notes: str) -> str:
    """Resumo objetivo em 1-2 linhas a partir da descrição."""
    if not notes.strip():
        return "Sem descrição no chamado."
    # Pega as primeiras linhas não vazias, limitando o tamanho.
    linhas = [ln.strip() for ln in notes.splitlines() if ln.strip()]
    resumo = " ".join(linhas)
    if len(resumo) > 220:
        resumo = resumo[:217].rstrip() + "..."
    return resumo


def _primeira_acao(objs: SapObjects) -> str:
    if objs.is_empty():
        return NO_SAP_MARK
    if objs.custom:
        alvo = objs.custom[0]
        return (
            f"Abrir {alvo} (SE80/SE37/SE38/SE11) e localizar o ponto citado "
            f"no chamado; conferir últimas alterações (versões) e logs."
        )
    alvo = objs.transactions[0]
    return f"Reproduzir o cenário na transação {alvo} e capturar trace (ST05)/dump (ST22)."


def _objetos_str(objs: SapObjects) -> str:
    if objs.is_empty():
        return "(nenhum identificado)"
    partes = []
    if objs.custom:
        partes.append("Objetos: " + ", ".join(objs.custom))
    if objs.transactions:
        partes.append("Transações: " + ", ".join(objs.transactions))
    return " | ".join(partes)


def build_report(items: list[PrioritizedTask], today: date) -> str:
    """Monta o relatório completo no template definido."""
    data_str = today.strftime("%d/%m/%Y")
    out: list[str] = [f"📋 PLANO DE TRABALHO — {data_str}", ""]

    vencidas_criticas: list[str] = []
    sem_objetos: list[str] = []

    if not items:
        out.append("Nenhuma tarefa elegível encontrada para hoje.")
    for pt in items:
        task = pt.task
        objs = extract(task.notes)
        label = _LABEL[pt.priority]

        if pt.priority == P_VENCIDA:
            venc = pt.due_date.strftime("%d/%m/%Y") if pt.due_date else "?"
            vencidas_criticas.append(f"{task.name} (venceu {venc})")
        if objs.is_empty():
            sem_objetos.append(task.name)

        out.append(f"[{label}] {task.name}")
        out.append(f"🔗 Link: {task.link or '(sem link)'}")
        out.append(f"⚠️ Problema: {_resumo_problema(task.notes)}")
        out.append(f"🔧 Objetos SAP: {_objetos_str(objs)}")
        out.append(f"🎯 Primeira Ação: {_primeira_acao(objs)}")
        out.append("")

    out.append("⚠️ ATENÇÃO:")
    out.append(
        "- Tarefas vencidas críticas: "
        + ("; ".join(vencidas_criticas) if vencidas_criticas else "nenhuma")
    )
    out.append(
        "- Chamados sem objetos SAP (provável investigação funcional): "
        + ("; ".join(sem_objetos) if sem_objetos else "nenhum")
    )

    return "\n".join(out)


def build_error_report(today: date, message: str) -> str:
    """Relatório curto para falhas (ex.: API do Asana indisponível)."""
    data_str = today.strftime("%d/%m/%Y")
    return (
        f"📋 PLANO DE TRABALHO — {data_str}\n\n"
        f"⚠️ ERRO: {message}"
    )
