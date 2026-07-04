# Ajuste ZVM_GRAVA_NOTA — header lines para work areas

## Interface (SE37) — sem alteração

A interface permanece com `TABLES` e `STRUCTURE`:

```abap
TABLES
  T1_NF STRUCTURE  ZVM_NF_IN OPTIONAL
  T2_NF_IT STRUCTURE  ZVM_NF_IT_IN OPTIONAL
  T3_NF_IT_COND STRUCTURE  ZVM_NF_IT_COND_IN OPTIONAL
  T4_NF_PAGTO STRUCTURE  ZVM_NF_PAGTO_IN OPTIONAL
```

Os chamadores continuam usando `CALL FUNCTION ... TABLES` — nenhuma mudança necessária.

## Ajustes apenas na implementação

| Antes (não compila) | Depois |
|---------------------|--------|
| `TABLES: zvm_lock_gravanf` | `DATA ls_zvm_lock_gravanf TYPE zvm_lock_gravanf` |
| `LOOP AT t1_nf` / `t1_nf-campo` (header line) | `LOOP AT t1_nf ASSIGNING <ls_t1_nf>` / `<ls_t1_nf>-campo` |
| `MODIFY t1_nf` | atribuição direta via `ASSIGNING` |
| `SELECT SINGLE * FROM zvm_nf` (sem INTO) | `INTO @ls_zvm_nf` |
| `zvm_nf-campo` após SELECT | `ls_zvm_nf-campo` |
| `INSERT zvm_nf` / `MOVE t1_nf TO zvm_nf` | `MOVE-CORRESPONDING` + `INSERT ... FROM ls_zvm_nf` |
| `ti_mard OCCURS 0 WITH HEADER LINE` | `TYPE TABLE OF mard` + `ls_mard` |
| `BEGIN OF ti_max_nf OCCURS 0` | `TYPES ty_max_nf` + `TYPE TABLE OF ty_max_nf` |
| `i_objtxt = '...' APPEND i_objtxt` | `wa_objtxt-line = '...' APPEND wa_objtxt TO i_objtxt` |
| `FORM clear_lock TABLES tb_nf` com header line | `LOOP AT tb_nf INTO ls_nf` + work area local |

## Observações

- SQL usa **OpenSQL clássico** (sem `@`) com variáveis locais `lv_nfnum`, `lv_series`, etc. copiadas do field-symbol no início do loop — evita erros de escape misto.
- `UPDATE ... SET` mantém sintaxe clássica (sem vírgulas entre campos).
- `MOVE-CORRESPONDING` entre `ZVM_NF_IN` e `ZVM_NF` cobre diferenças de tipo entre estrutura de entrada e tabela persistente.
- `i_reclist` / `i_objtxt`: sempre via `wa_reclist` / `wa_objtxt` + `APPEND ... TO`.
