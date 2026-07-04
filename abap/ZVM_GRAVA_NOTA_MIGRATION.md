# Migração ZVM_GRAVA_NOTA — TABLES para estruturas

## Interface (SE37)

Substituir os parâmetros `TABLES` por `CHANGING` com tabelas tipadas:

```abap
CHANGING
  T1_NF           TYPE STANDARD TABLE OF ZVM_NF_IN         OPTIONAL
  T2_NF_IT        TYPE STANDARD TABLE OF ZVM_NF_IT_IN      OPTIONAL
  T3_NF_IT_COND   TYPE STANDARD TABLE OF ZVM_NF_IT_COND_IN OPTIONAL
  T4_NF_PAGTO     TYPE STANDARD TABLE OF ZVM_NF_PAGTO_IN   OPTIONAL
```

## Principais ajustes no código

| Antes | Depois |
|-------|--------|
| `TABLES: zvm_lock_gravanf` | `DATA ls_zvm_lock_gravanf TYPE zvm_lock_gravanf` |
| `LOOP AT t1_nf` (header line) | `LOOP AT t1_nf ASSIGNING <ls_t1_nf>` |
| `t1_nf-campo` | `<ls_t1_nf>-campo` |
| `MODIFY t1_nf` | atribuição direta via `ASSIGNING` |
| `SELECT SINGLE * FROM zvm_nf` (sem INTO) | `INTO @ls_zvm_nf` |
| `zvm_nf-campo` após SELECT | `ls_zvm_nf-campo` |
| `INSERT zvm_nf` / `MOVE t1_nf TO zvm_nf` | `MOVE-CORRESPONDING` + `INSERT ... FROM ls_zvm_nf` |
| `ti_mard OCCURS 0 WITH HEADER LINE` | `TYPE TABLE OF mard` + `ls_mard` |
| `BEGIN OF ti_max_nf OCCURS 0` | `TYPES ty_max_nf` + `TYPE TABLE OF ty_max_nf` |
| `i_objtxt = '...' APPEND i_objtxt` | `wa_objtxt-line = '...' APPEND wa_objtxt TO i_objtxt` |
| `PERFORM clear_lock TABLES t1_nf` | `PERFORM clear_lock USING t1_nf` |
| `FORM clear_lock TABLES tb_nf` | `FORM clear_lock USING pt_nf TYPE STANDARD TABLE OF zvm_nf_in` |

## Chamadores da FM

Atualizar todas as chamadas que usavam `TABLES`:

```abap
" Antes
CALL FUNCTION 'ZVM_GRAVA_NOTA'
  TABLES
    t1_nf           = lt_nf
    t2_nf_it        = lt_it
    ...

" Depois
CALL FUNCTION 'ZVM_GRAVA_NOTA'
  CHANGING
    t1_nf           = lt_nf
    t2_nf_it        = lt_it
    ...
```

## Observações

- `MOVE-CORRESPONDING` foi usado entre estruturas de entrada (`ZVM_NF_IN`) e tabelas persistentes (`ZVM_NF`), pois os tipos podem diferir.
- O `FORM clear_lock` precisa declarar `ls_zvm_lock_gravanf` como variável local ou receber via `USING` — no fonte corrigido, usa a variável global da FM (padrão ABAP em includes de grupo de funções).
- Se `ls_zvm_lock_gravanf` não for visível no FORM, declare `DATA ls_zvm_lock_gravanf TYPE zvm_lock_gravanf` dentro do `FORM clear_lock` (já aplicado no fonte corrigido).
