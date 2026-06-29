"""Extração de objetos SAP citados nas descrições dos chamados.

A descrição de um chamado costuma citar Function Modules, Includes,
Programs, Tabelas e Transações. Aqui aplicamos heurísticas baseadas nos
padrões fornecidos pela analista. A classificação não é perfeita (um
mesmo token pode ser FM ou tabela), então preferimos detectar a presença
e categorizar pelo contexto quando possível.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

# Transações conhecidas frequentemente citadas (lista não exaustiva).
KNOWN_TCODES = {
    "SE11", "SE16", "SE16N", "SE37", "SE38", "SE80", "SE91", "SE93",
    "ST05", "ST22", "SM37", "SM50", "SM12", "SM13", "SLG1", "AL11",
    "SAT", "SE24", "SE18", "SE19", "SE10", "SE09", "SU01", "PFCG",
    "VA01", "VA02", "VA03", "VF01", "VF02", "VF03", "ME21N", "ME22N",
    "ME23N", "MIGO", "MIRO", "FB60", "FB70", "F-02", "MM01", "MM02",
    "MM03", "XD01", "XD02", "XD03", "VL01N", "VL02N", "VL03N",
}

# Objetos customizados / específicos: Z*, Y*, J_1B*, /FHG/*, etc.
_RE_CUSTOM = re.compile(
    r"(?<![A-Za-z0-9_/])"  # não começa no meio de uma palavra
    r"(?:"
    r"/[A-Z0-9]+/[A-Z0-9_]+"   # namespaces ex.: /FHG/ALGO
    r"|J_1B[A-Z0-9_]*"          # localização Brasil
    r"|[ZY][A-Z0-9_]{2,}"      # Z*/Y* (mín. 3 chars no total)
    r")",
)

# Transações: token alfanumérico curto (2-4) que esteja na lista conhecida,
# ou que apareça precedido de palavras indicativas.
_RE_TCODE_CANDIDATE = re.compile(r"(?<![A-Za-z0-9_])([A-Z][A-Z0-9]{1,4}(?:-[A-Z0-9]+)?)")

_TCODE_CONTEXT = re.compile(
    r"(?:transa[çc][ãa]o|tcode|t-code|tx|c[óo]digo de transa)\s*[:\-]?\s*"
    r"([A-Z][A-Z0-9]{1,4})",
    re.IGNORECASE,
)


@dataclass
class SapObjects:
    custom: list[str] = field(default_factory=list)   # Z*/Y*/J_1B*//FHG/*
    transactions: list[str] = field(default_factory=list)

    def is_empty(self) -> bool:
        return not self.custom and not self.transactions

    def all_objects(self) -> list[str]:
        return self.custom + self.transactions


def _dedupe_keep_order(items) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        key = item.upper()
        if key not in seen:
            seen.add(key)
            out.append(item.upper())
    return out


def extract(text: str) -> SapObjects:
    """Extrai objetos SAP de um texto livre (descrição do chamado)."""
    if not text:
        return SapObjects()

    custom_matches = _RE_CUSTOM.findall(text)

    # Transações: as que vierem com contexto explícito + as conhecidas.
    tcodes: list[str] = [m.upper() for m in _TCODE_CONTEXT.findall(text)]
    for cand in _RE_TCODE_CANDIDATE.findall(text):
        upper = cand.upper()
        if upper in KNOWN_TCODES:
            tcodes.append(upper)

    custom = _dedupe_keep_order(custom_matches)
    # Garante que um tcode não seja confundido com objeto custom (não há
    # sobreposição porque custom exige Z/Y/J_1B///, mas mantemos limpo).
    transactions = _dedupe_keep_order(tcodes)

    return SapObjects(custom=custom, transactions=transactions)
