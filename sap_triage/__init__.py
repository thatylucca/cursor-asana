"""Triagem diária de chamados SAP/ABAP a partir do Asana.

Este pacote implementa o fluxo de trabalho descrito na automação:

1. Buscar tarefas incompletas no Asana atribuídas à analista.
2. Priorizar (vencidas > vencendo hoje > sem prazo em projetos-alvo).
3. Extrair objetos SAP citados nas descrições.
4. Gerar relatório em português.
5. Enviar o relatório por email (Gmail API via ADC).
"""

__all__ = [
    "config",
    "asana",
    "prioritize",
    "sap_objects",
    "report",
    "email_sender",
]
