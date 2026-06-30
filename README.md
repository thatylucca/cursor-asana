# Plano de Trabalho Diário SAP/ABAP (Asana)

Automação que monta, toda manhã, um **plano de trabalho priorizado** com
os ~10 chamados mais importantes do Asana atribuídos à analista, extrai os
**objetos SAP** citados nas descrições, gera um relatório em português e
**envia por email**.

## Fluxo

1. Busca tarefas incompletas nos projetos configurados do Asana.
2. Filtra **somente** as atribuídas a `thatiany.silva@fogas.com.br` e **incompletas**.
3. Prioriza (ordem estrita):
   1. **VENCIDAS** (`due_date < hoje`) — máxima
   2. **VENCENDO HOJE** (`due_date == hoje`) — high
   3. **Sem prazo** nos projetos `Nível 2 de atendimento` / `Kanban` — medium
4. Extrai objetos SAP das descrições (Z\*, Y\*, `J_1B*`, `/FHG/*`, transações…).
5. Gera o relatório em português.
6. Envia por email via **Gmail API com ADC** (sem chaves de API).

## Execução

```bash
# Apenas gerar e imprimir (não envia email)
python daily_plan.py --dry-run

# Gerar e enviar por email
python daily_plan.py
```

## Pré-requisitos

| Necessidade | Como configurar |
|-------------|-----------------|
| `ASANA_PAT` | Token PAT do Asana (variável de ambiente / secret) |
| Acesso de rede a `app.asana.com` | Liberar o egress nas *Network Access settings* do Cloud Agent |
| ADC para Gmail | Application Default Credentials com escopo `gmail.send` |
| Dependências de email | `pip install -r requirements.txt` |

> O cliente do Asana usa apenas a biblioteca padrão (`urllib`), então a
> busca funciona sem instalar nada. As dependências do `requirements.txt`
> são necessárias **apenas para o envio de email** via Gmail API.

## Variáveis de ambiente (sobrescrevem os padrões)

- `ASANA_PAT` — token do Asana (obrigatório)
- `ASANA_PROJECT_GIDS` — GIDs separados por vírgula (padrão: os dois do projeto)
- `TARGET_ASSIGNEE_EMAIL` — email da assignee alvo
- `EMAIL_TO` / `EMAIL_FROM` — destino e remetente (`me` = identidade ADC)
- `NO_DUE_PROJECT_NAMES` — projetos cujas tarefas sem prazo entram (medium)
- `MAX_TASKS` — limite do plano (padrão: 10)
- `TIMEZONE` — fuso para definir "hoje" (padrão: `America/Sao_Paulo`)

## Análise de objetos SAP (ADT, leitura)

A confirmação de existência e a leitura rápida de código/metadados dos
objetos SAP devem ser feitas em **modo leitura** via o servidor MCP
`sap-abap-adt` (dentro do Cursor), que requer credenciais SAP configuradas
(`SAP_CLIENT`, etc.). O script já entrega, por chamado, os objetos
candidatos e a **primeira ação** sugerida para acelerar essa investigação.

## Testes

Testes offline da lógica pura (priorização, extração SAP, relatório):

```bash
python tests/test_logic.py
# ou, se tiver pytest:
python -m pytest -q
```

## Notas operacionais

- Se a API do Asana falhar, o relatório sai com `⚠️ ERRO: Não foi possível
  buscar tarefas do Asana` (e o programa não trava).
- Se o envio de email falhar, o relatório é impresso no stderr e o código
  de saída é `1`, deixando claro que **não foi entregue**.
- Chamados sem objetos SAP são marcados como *investigação funcional
  necessária*.
