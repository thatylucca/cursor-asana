FUNCTION zvm_grava_nota.
*"----------------------------------------------------------------------
*"*"Interface local:
*"  IMPORTING
*"     VALUE(I_DEBUG) TYPE  CHAR1 OPTIONAL
*"  CHANGING
*"      T1_NF           TYPE  STANDARD TABLE OF ZVM_NF_IN         OPTIONAL
*"      T2_NF_IT        TYPE  STANDARD TABLE OF ZVM_NF_IT_IN      OPTIONAL
*"      T3_NF_IT_COND   TYPE  STANDARD TABLE OF ZVM_NF_IT_COND_IN OPTIONAL
*"      T4_NF_PAGTO     TYPE  STANDARD TABLE OF ZVM_NF_PAGTO_IN   OPTIONAL
*"  EXCEPTIONS
*"      EX_ERRO_INS_NF
*"      EX_PROG_BLOCKED
*"      EX_DATE_WITH_ERROR_1
*"      EX_DATE_WITH_ERROR_2
*"      EX_TABLE_BLOCKED
*"----------------------------------------------------------------------
*
* Migração TABLES -> estruturas (work areas / tabelas tipadas) - 04.07.2026
*
  CONSTANTS: c_except_competition(70)  VALUE 'Processo não executado por conta da concorrência',
             c_except_invalid_date(70) VALUE 'Processo não executado por conta da data de emissão',
             c_except_invalid_item(70) VALUE 'Processo não executado por conta de itens errados',
             c_except_blocked(70)      VALUE 'Processo não executado. Programação fechada',
             c_program(14)             VALUE 'ZVM_GRAVA_NOTA'.

  TYPES: BEGIN OF ty_max_nf,
           series LIKE zvm_nf-series,
           werks  LIKE zvm_nf-werks,
           nfnum  LIKE zvm_nf-nfnum,
         END OF ty_max_nf.

  DATA: v_id(10)      TYPE c,
        v_xfluvial    TYPE c,
        v_xgranel     TYPE c,
        v_erro        TYPE c,
        v_somapeso    TYPE i,
        v_menge       TYPE i,
        v_matnr       TYPE i,
        v_sit_estorno TYPE c,
        v_qtreg       TYPE i,
        ti_max_nf     TYPE TABLE OF ty_max_nf,
        ls_max_nf     TYPE ty_max_nf,
        ti_mard       TYPE TABLE OF mard,
        ls_mard       TYPE mard,
        aux_data      TYPE sy-datum.

  DATA: i_objtxt     TYPE TABLE OF solisti1,
        i_reclist    TYPE TABLE OF somlreci1,
        wa_reclist   TYPE somlreci1,
        wa_doc_chng  TYPE sodocchgi1,
        i_objpack    TYPE TABLE OF sopcklsti1,
        wa_objpack   TYPE sopcklsti1,
        v_lines_txt  TYPE i,
        v_locked     TYPE c VALUE 'X',
        v_times      TYPE i VALUE 10,
        s_sucess     TYPE string,
        v_nefnum     TYPE j_1bnfnum9,
        v_parid      TYPE zvm_nf-parid,
        v_sms        TYPE zmsg,
        pos          TYPE i,
        wa_objtxt    TYPE solisti1,
        wa_t2_nf_it  TYPE zvm_nf_it,
        v_vlritem    TYPE zcurr,
        v_totitem    TYPE zcurr,
        v_totnota    TYPE zcurr,
        nova_nota(1).

  DATA: ls_zvm_lock_gravanf TYPE zvm_lock_gravanf,
        ls_zvm_nf           TYPE zvm_nf,
        ls_zvm_nf_it        TYPE zvm_nf_it,
        ls_zvm_nf_it_cond   TYPE zvm_nf_it_cond,
        ls_zvm_nf_pagto     TYPE zvm_nf_pagto,
        ls_zvm_nota_control TYPE zvm_nota_control.

* Inicio Alteração - Nivel 019    11.08.2017 ---------------------
  DATA: w_qtdias(03)       TYPE n,
        w_ztag1            TYPE dztage,
        w_zterm            TYPE dzterm,
        w_qtdiaszerado(01) TYPE c,
        v_numemb           TYPE zvm_nemb,
        v_kunnr            TYPE j_1bparid,
        v_nfnum            TYPE j_1bnfnumb,
        w_numemb           TYPE zvm_nemb,
        w_parid            TYPE j_1bparid,
        w_nfnum            TYPE j_1bnfnumb.
* Final Alteração  - Nivel 019    11.08.2017 ---------------------

* Inicio Alteração - Nivel 020    03.11.2017 ---------------------
  DATA: w_code       TYPE string,
        w_err_string TYPE string,
        t_result     TYPE TABLE OF zmob_ins_ordem_result.
* Final Alteração  - Nivel 020    03.11.2017 ---------------------

* Inicio Alteração - Nivel 022    03.01.2018 ---------------------
  DATA: w_vbeln_ori TYPE vbeln,
        w_mensagem  TYPE string,
        cod_retorno TYPE  char4,
        msg_retorno TYPE  char100,
        msg_solucao TYPE  char100.
* Final Alteração  - Nivel 022    03.01.2018 ---------------------

* Nível 025
  DATA: it_rev_config TYPE TABLE OF zapp_rev_config,
        wa_rev_config TYPE zapp_rev_config.
* Nível 025

  DATA: lt_nf           TYPE STANDARD TABLE OF zvm_nf,
        ls_nf           LIKE LINE OF lt_nf,
        lv_tamanho      TYPE i,
        lv_regio        TYPE regio,
        lt_nfc_sintegra TYPE STANDARD TABLE OF zsd_nfc_sintegra,
        ls_nfc_sintegra TYPE zsd_nfc_sintegra.

* Normalização do NFNUM após migração NUMC(6) -> CHAR(9) - tsilva 03.07.2026
  DATA: vl_nfnum_n9 TYPE n LENGTH 9,
        vl_nfnum_n6 TYPE n LENGTH 6.

  FIELD-SYMBOLS: <ls_t1_nf>         TYPE zvm_nf_in,
                 <ls_t2_nf_it>      TYPE zvm_nf_it_in,
                 <ls_t3_nf_it_cond> TYPE zvm_nf_it_cond_in,
                 <ls_t4_nf_pagto>   TYPE zvm_nf_pagto_in.

  WHILE i_debug = x.
    " Para depuração através da sm50
  ENDWHILE.

*--------------------------------------------------------------------*
* Normaliza o NFNUM para o formato canônico J_1BNFNUM9 ('000nnnnnn').
*--------------------------------------------------------------------*
  LOOP AT t1_nf ASSIGNING <ls_t1_nf>.
    vl_nfnum_n9 = <ls_t1_nf>-nfnum.
    <ls_t1_nf>-nfnum = vl_nfnum_n9.
  ENDLOOP.

  LOOP AT t2_nf_it ASSIGNING <ls_t2_nf_it>.
    vl_nfnum_n9 = <ls_t2_nf_it>-nfnum.
    <ls_t2_nf_it>-nfnum = vl_nfnum_n9.
  ENDLOOP.

  LOOP AT t3_nf_it_cond ASSIGNING <ls_t3_nf_it_cond>.
    vl_nfnum_n9 = <ls_t3_nf_it_cond>-nfnum.
    <ls_t3_nf_it_cond>-nfnum = vl_nfnum_n9.
  ENDLOOP.

  TRY.
      SORT t1_nf BY nfnum series sales_org.
      DELETE ADJACENT DUPLICATES FROM t1_nf COMPARING nfnum series sales_org.

      CLEAR v_erro.

      LOOP AT t1_nf ASSIGNING <ls_t1_nf>.

        IF ( <ls_t1_nf>-nfnum IS INITIAL OR <ls_t1_nf>-series IS INITIAL ).
          CONTINUE.
        ENDIF.

        SELECT SINGLE @abap_true
          FROM zvm_prog_emb
          INTO @DATA(lv_prog_blocked)
          WHERE numemb = @<ls_t1_nf>-numemb
            AND status >= '8'.

        IF sy-subrc = 0.
          v_erro = x. EXIT.
        ENDIF.

        IF <ls_t1_nf>-tipo_nf IS INITIAL.
          <ls_t1_nf>-tipo_nf = c_nota_caminhao.
        ENDIF.

        SELECT SINGLE *
          FROM zvm_lock_gravanf
          INTO @ls_zvm_lock_gravanf
          WHERE nfnum     = @<ls_t1_nf>-nfnum
            AND series    = @<ls_t1_nf>-series
            AND sales_org = @<ls_t1_nf>-sales_org.

        IF sy-subrc EQ 0.
          CONTINUE.
        ELSE.
          CLEAR ls_zvm_lock_gravanf.

          ls_zvm_lock_gravanf-nfnum     = <ls_t1_nf>-nfnum.
          ls_zvm_lock_gravanf-series    = <ls_t1_nf>-series.
          ls_zvm_lock_gravanf-sales_org = <ls_t1_nf>-sales_org.
          ls_zvm_lock_gravanf-erdat     = sy-datum.
          ls_zvm_lock_gravanf-erzet     = sy-uzeit.

          INSERT zvm_lock_gravanf FROM ls_zvm_lock_gravanf.

          IF sy-subrc NE 0.
            v_erro = x. EXIT.
          ENDIF.

          COMMIT WORK AND WAIT.

          IF sy-subrc NE 0.
            v_erro = x. EXIT.
          ENDIF.
        ENDIF.

        CLEAR aux_data.

        CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
          EXPORTING
            date      = sy-datum
            days      = 35
            months    = 0
            signum    = '-'
            years     = 0
          IMPORTING
            calc_date = aux_data.

        IF ( sy-subrc = 0 ).
          IF ( <ls_t1_nf>-data > sy-datum ).
            v_erro = x. EXIT.
          ELSEIF ( <ls_t1_nf>-tipo_nf = '0' ).
            IF ( <ls_t1_nf>-data < aux_data ).
              v_erro = x. EXIT.
            ENDIF.
          ENDIF.
        ENDIF.

        nova_nota = 'X'.

        IF <ls_t1_nf>-doctype EQ 'ZGEN' OR <ls_t1_nf>-doctype EQ 'ZDMA' OR
           <ls_t1_nf>-doctype EQ 'ZNFC' OR <ls_t1_nf>-doctype EQ 'ZDNC'.

          SELECT SINGLE *
            FROM zvm_nf
            INTO @ls_zvm_nf
            WHERE nfnum     = @<ls_t1_nf>-nfnum
              AND series    = @<ls_t1_nf>-series
              AND sales_org = @<ls_t1_nf>-sales_org
              AND tipo_nf   = @<ls_t1_nf>-tipo_nf
              AND ( doctype = 'ZGEN' OR doctype = 'ZDMA' OR
                    doctype = 'ZNFC' OR doctype = 'ZDNC' ).

          IF sy-subrc EQ 0.
            nova_nota = space.
          ENDIF.

        ELSE.

          SELECT SINGLE *
            FROM zvm_nf
            INTO @ls_zvm_nf
            WHERE nfnum     = @<ls_t1_nf>-nfnum
              AND series    = @<ls_t1_nf>-series
              AND sales_org = @<ls_t1_nf>-sales_org
              AND tipo_nf   = @<ls_t1_nf>-tipo_nf
              AND ( doctype = 'ZFGR' OR doctype = 'ZFPR' OR
                    doctype = 'ZEAV' OR doctype = 'ZSAV' ).

          IF sy-subrc EQ 0.
            nova_nota = space.

            UNPACK <ls_t1_nf>-parid TO v_parid.

            REFRESH : i_objpack, i_objtxt, i_reclist.
            CLEAR wa_doc_chng.
            MOVE <ls_t1_nf>-numemb TO v_numemb.
            MOVE <ls_t1_nf>-parid  TO v_kunnr.
            MOVE <ls_t1_nf>-nfnum  TO v_nfnum.

            SHIFT v_numemb LEFT DELETING LEADING '0'.
            SHIFT v_kunnr  LEFT DELETING LEADING '0'.
            SHIFT v_nfnum  LEFT DELETING LEADING '0'.

            IF ( ls_zvm_nf-parid NE v_parid ).

              wa_doc_chng-obj_descr = 'Fogás: Nota duplicada na programação'.
              wa_objtxt-line = '<html>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = 'Prezado desenvolvimento.di,<br><br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<b> Programação: </b>' && | | && v_numemb && | | && '<br>'
                            && '<b> Cliente: </b>' && | | && v_kunnr && | | &&'<br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<b> A nota fiscal' && | | && v_nfnum && | |
                            && 'série' && | | && <ls_t1_nf>-series && | |
                            && 'está duplicada na programação. </b>'.
              APPEND wa_objtxt TO i_objtxt.

              IF <ls_t1_nf>-cancel NE 'X'.
                wa_objtxt-line = '<b> A nota fiscal' && | | && v_nfnum && | |
                            && 'série' && | | && <ls_t1_nf>-series && | |
                            && 'válida. </b>'.
              ELSE.
                wa_objtxt-line = '<b> A nota fiscal' && | | && v_nfnum && | |
                            && 'série' && | | && <ls_t1_nf>-series && | |
                            && 'cancelada. </b>'.
              ENDIF.
              APPEND wa_objtxt TO i_objtxt.

              wa_objtxt-line = '</html>'.
              APPEND wa_objtxt TO i_objtxt.
            ENDIF.

            DESCRIBE TABLE i_objtxt LINES v_qtreg.
            IF ( ls_zvm_nf-netwr NE <ls_t1_nf>-netwr AND
                 <ls_t1_nf>-cancel NE 'X'         AND
                 v_qtreg      EQ 0 ).

              wa_doc_chng-obj_descr = 'Fogás: Valor da nota fiscal divergente'.
              wa_objtxt-line = '<html>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = 'Prezado desenvolvimento.di,<br><br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<b> Programação: </b>' && | | && v_numemb && | | && '<br>'
                            && '<b> Cliente: </b>' && | | && v_kunnr && | | &&'<br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<b> A nota fiscal' && | | && v_nfnum && | |
                            && 'série' && | | && <ls_t1_nf>-series && | |
                            && 'está com valor divergente: </b>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<b> Valor líquido ECC: </b>' && | | && ls_zvm_nf-netwr && | | && '<br>'
                            && '<b> Valor líquido App Distribuiçao: </b>' && | | && <ls_t1_nf>-netwr && | | &&'<br>'.
              APPEND wa_objtxt TO i_objtxt.

              wa_objtxt-line = '<br>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<table border="1">'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<tr>'
                                  && '<td><b>Produto</b></td>'
                                  && '<td><b>Quantidade</b></td>'
                                  && '<td><b>Vlr Unitário</b></td>'
                                  && '<td><b>Vlr Total</b></td>'
                               && '</tr>'.
              APPEND wa_objtxt TO i_objtxt.
              CLEAR v_totnota.
              LOOP AT t2_nf_it INTO wa_t2_nf_it.
                v_vlritem = wa_t2_nf_it-netpr.
                v_totitem = wa_t2_nf_it-menge * wa_t2_nf_it-netpr.
                v_totnota = v_totnota + v_totitem.
                wa_objtxt-line = '<tr>'
                                  && '<td>' && wa_t2_nf_it-matnr && '</td>'
                                  && '<td>' && wa_t2_nf_it-menge && '</td>'
                                  && '<td>' && v_vlritem         && '</td>'
                                  && '<td>' && v_totitem         && '</td>'
                               && '</tr>'.
                APPEND wa_objtxt TO i_objtxt.
              ENDLOOP.
              wa_objtxt-line = '<tr>'
                                  && '<td> Total itens ==> </td>'
                                  && '<td> </td>'
                                  && '<td> </td>'
                                  && '<td>' && v_totnota && '</td>'
                               && '</tr>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '<b> A nota fiscal' && | | && v_nfnum && | |
                          && 'série' && | | && <ls_t1_nf>-series && | |
                          && 'válida. </b>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '</table>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = '</html>'.
              APPEND wa_objtxt TO i_objtxt.
            ENDIF.

            DESCRIBE TABLE i_objtxt LINES v_lines_txt.
            IF v_lines_txt > 0.
              CLEAR: wa_reclist.
              wa_reclist-rec_type   = 'U'.
              wa_reclist-notif_del  = ' '.
              wa_reclist-notif_ndel = ' '.
              wa_reclist-notif_read = ' '.
              wa_reclist-express    = 'X'.
              wa_reclist-receiver   = 'desenvolvimento.di@fogas.com.br'.
              APPEND wa_reclist TO i_reclist.

              wa_doc_chng-sensitivty = 'O'.
              wa_doc_chng-priority   = '5'.
              wa_doc_chng-doc_size   = v_lines_txt * 255.

              CLEAR: wa_objpack.
              wa_objpack-head_start = 1.
              wa_objpack-head_num   = 0.
              wa_objpack-body_start = 1.
              wa_objpack-body_num   = v_lines_txt.
              wa_objpack-doc_type   = 'HTM'.
              APPEND wa_objpack TO i_objpack.

              CALL FUNCTION 'SO_NEW_DOCUMENT_ATT_SEND_API1'
                EXPORTING
                  document_data              = wa_doc_chng
                  put_in_outbox              = 'X'
                  commit_work                = 'X'
                TABLES
                  packing_list               = i_objpack
                  contents_txt               = i_objtxt
                  receivers                  = i_reclist
                EXCEPTIONS
                  too_many_receivers         = 1
                  document_not_sent          = 2
                  document_type_not_exist    = 3
                  operation_no_authorization = 4
                  parameter_error            = 5
                  x_error                    = 6
                  enqueue_error              = 7
                  OTHERS                     = 8.
              v_erro = x. EXIT.
            ENDIF.
          ENDIF.

        ENDIF.

        IF nova_nota EQ 'X'.
          IF <ls_t1_nf>-cancel = 'X' AND <ls_t1_nf>-tipo_nf = c_nota_caminhao AND
           ( <ls_t1_nf>-doctype EQ 'ZFPR' OR <ls_t1_nf>-doctype EQ 'ZFGR' OR
             <ls_t1_nf>-doctype EQ 'ZEAV' OR <ls_t1_nf>-doctype EQ 'ZSAV' ).

            <ls_t1_nf>-cancel     = ''.
            <ls_t1_nf>-estornado  = 'X'.
            <ls_t1_nf>-st_estorno = '3'.
          ENDIF.

        ELSE.
          IF ( ( <ls_t1_nf>-cancel = 'X' AND <ls_t1_nf>-tipo_nf = c_nota_caminhao ) OR
             ( <ls_t1_nf>-estornado = 'X' ) ) AND ls_zvm_nf-estornado <> 'X'.

            IF ls_zvm_nf-augbl IS INITIAL.

              IF ls_zvm_nf-doctype EQ 'ZFPR' OR ls_zvm_nf-doctype EQ 'ZFGR' OR
                 ls_zvm_nf-doctype EQ 'ZEAV' OR ls_zvm_nf-doctype EQ 'ZSAV'.
                v_sit_estorno = '3'.
              ELSE.
                v_sit_estorno = '2'.
              ENDIF.

              UPDATE zvm_nf SET estornado  = 'X'
                                st_estorno = v_sit_estorno
                      WHERE nfnum     = @<ls_t1_nf>-nfnum
                        AND series    = @<ls_t1_nf>-series
                        AND sales_org = @<ls_t1_nf>-sales_org
                        AND tipo_nf   = @<ls_t1_nf>-tipo_nf
                        AND doctype   = @ls_zvm_nf-doctype.

              v_nefnum = <ls_t1_nf>-nfnum.

              DELETE FROM zvm_boletos_med WHERE sales_org = @<ls_t1_nf>-sales_org
                                            AND nfenum    = @v_nefnum
                                            AND series    = @<ls_t1_nf>-series.

            ELSE.
              UPDATE zvm_nf SET estornado  = 'X'
                                st_estorno = '1'
               WHERE nfnum     = @<ls_t1_nf>-nfnum
                 AND series    = @<ls_t1_nf>-series
                 AND sales_org = @<ls_t1_nf>-sales_org
                 AND tipo_nf   = @<ls_t1_nf>-tipo_nf.
            ENDIF.

            CALL FUNCTION 'ZCO_PROCESSA_ESTORNO'
              EXPORTING
                i_estornado   = 'X'
                i_sales_order = <ls_t1_nf>-sales_org
                i_nfnum       = <ls_t1_nf>-nfnum
                i_parid       = <ls_t1_nf>-parid
                i_numemb      = <ls_t1_nf>-numemb.

          ENDIF.

          IF ( <ls_t1_nf>-tipo_nf = c_cupom_fiscal ) AND ls_zvm_nf-augbl IS INITIAL.
            LOOP AT t4_nf_pagto ASSIGNING <ls_t4_nf_pagto>
              WHERE nfnum  = <ls_t1_nf>-nfnum
                AND series = <ls_t1_nf>-series.
              MOVE-CORRESPONDING <ls_t4_nf_pagto> TO ls_zvm_nf_pagto.
              MODIFY zvm_nf_pagto FROM ls_zvm_nf_pagto.
              IF sy-subrc <> 0.
                v_erro = x.
                EXIT.
              ENDIF.
            ENDLOOP.
          ENDIF.

          IF ( ls_zvm_nf-doctype = 'ZNFC' OR ls_zvm_nf-doctype = 'ZDNC' ) AND <ls_t1_nf>-code IS NOT INITIAL.

            UPDATE zvm_nf SET authcod      = @<ls_t1_nf>-authcod
                              authdate     = @<ls_t1_nf>-authdate
                              authtime     = @<ls_t1_nf>-authtime
                              code         = @<ls_t1_nf>-code
                              chave_acesso = @<ls_t1_nf>-chave_acesso
                    WHERE nfnum     = @<ls_t1_nf>-nfnum
                      AND series    = @<ls_t1_nf>-series
                      AND sales_org = @<ls_t1_nf>-sales_org
                      AND tipo_nf   = @<ls_t1_nf>-tipo_nf
                      AND doctype   = @ls_zvm_nf-doctype.

            COMMIT WORK.
          ENDIF.

          CONTINUE.
        ENDIF.

        CALL FUNCTION 'NUMBER_GET_NEXT'
          EXPORTING
            nr_range_nr             = '01'
            object                  = 'ZVM_NF_ID'
            ignore_buffer           = 'X'
          IMPORTING
            number                  = v_id
          EXCEPTIONS
            interval_not_found      = 1
            number_range_not_intern = 2
            object_not_found        = 3
            quantity_is_0           = 4
            quantity_is_not_1       = 5
            interval_overflow       = 6
            buffer_overflow         = 7
            OTHERS                  = 8.

        IF sy-subrc <> 0.
          v_erro = x.
          EXIT.
        ENDIF.

        CASE <ls_t1_nf>-tipo_nf.
          WHEN c_cupom_fiscal.
            IF <ls_t1_nf>-doctype = 'ZGEN' OR <ls_t1_nf>-doctype = 'ZNFC'.
              SELECT MIN( vstel ) INTO @<ls_t1_nf>-vstel FROM tvswz
               WHERE werks EQ @<ls_t1_nf>-werks.
            ELSE.
              SELECT MAX( vstel ) INTO @<ls_t1_nf>-vstel FROM tvswz
              WHERE werks EQ @<ls_t1_nf>-werks.
            ENDIF.
          WHEN c_nota_caminhao.
            CLEAR v_xfluvial.
            SELECT SINGLE xfluvial INTO @v_xfluvial
              FROM zvm_nota_control
             WHERE series = @<ls_t1_nf>-series
               AND werks  = @<ls_t1_nf>-werks.

            IF <ls_t1_nf>-doctype = 'ZFGR'.
              v_xgranel = 'X'.
            ELSE.
              v_xgranel = space.
            ENDIF.

            SELECT SINGLE vstel INTO @<ls_t1_nf>-vstel
              FROM zvm_cfg_fat
              WHERE werks    EQ @<ls_t1_nf>-werks AND
                    xgranel  EQ @v_xgranel   AND
                    xfluvial EQ @v_xfluvial.
        ENDCASE.

        w_qtdiaszerado = 'N'.
        IF <ls_t1_nf>-extra = 'X'.
          SELECT * FROM zapp_rev_config
          INTO TABLE @it_rev_config.

          READ TABLE it_rev_config INTO wa_rev_config WITH KEY chave = 'ZBOL'.
          FIND <ls_t1_nf>-zterm IN wa_rev_config-valor MATCH OFFSET pos.

          IF sy-subrc NE 0.
            CLEAR: w_ztag1.
            SELECT SINGLE ztag1 INTO @w_ztag1 FROM t052
            WHERE zterm EQ @<ls_t1_nf>-zterm.
            IF w_ztag1 = 0.
              w_qtdiaszerado = 'S'.
            ELSE.
              w_qtdias = w_ztag1 + 1.
              SELECT SINGLE zterm, ztag1 INTO (@w_zterm, @w_ztag1) FROM t052
              WHERE zterm LIKE 'Z%' AND
              ztag1 EQ @w_qtdias AND
              xsplt NE 'X'.
            ENDIF.
            IF sy-subrc       NE 0 OR
            w_qtdiaszerado EQ 'S'.
              REFRESH : i_objpack, i_objtxt, i_reclist.
              MOVE <ls_t1_nf>-numemb TO w_numemb.
              MOVE <ls_t1_nf>-parid TO w_parid.
              MOVE <ls_t1_nf>-nfnum TO w_nfnum.

              SHIFT w_numemb LEFT DELETING LEADING '0'.
              SHIFT w_parid LEFT DELETING LEADING '0'.
              SHIFT w_nfnum LEFT DELETING LEADING '0'.

              CLEAR: wa_reclist.
              wa_reclist-rec_type   = 'U'.
              wa_reclist-notif_del  = ' '.
              wa_reclist-notif_ndel = ' '.
              wa_reclist-notif_read = ' '.
              wa_reclist-express    = 'X'.
              wa_reclist-receiver   = 'servicedesk@fogas.com.br'.
              APPEND wa_reclist TO i_reclist.

              wa_objtxt-line = '<html>'.
              APPEND wa_objtxt TO i_objtxt.
              wa_objtxt-line = 'Prezado ServiceDesk,<br><br>'.
              APPEND wa_objtxt TO i_objtxt.
              IF w_qtdiaszerado = 'S'.
                CONCATENATE 'A forma de pagamento <b>' <ls_t1_nf>-zterm ' </b> não tem quantidade de dias para prazo de pgto definida. <br><br>' INTO wa_objtxt-line SEPARATED BY space.
                APPEND wa_objtxt TO i_objtxt.
                CONCATENATE '<b> Programação: </b>' w_numemb '<br>' '<b> Cliente: </b>' w_parid '<br>' '<b> NF: </b>' w_nfnum '<br>' '<b> Série: </b>' <ls_t1_nf>-series '<br>' INTO wa_objtxt-line SEPARATED BY space.
                APPEND wa_objtxt TO i_objtxt.
              ELSE.
                CONCATENATE 'Não existe forma de pagamento de <b>' w_qtdias ' dias </b> para prazo de pgto. <br><br>' INTO wa_objtxt-line SEPARATED BY space.
                APPEND wa_objtxt TO i_objtxt.
                CONCATENATE '<b> Programação: </b>' w_numemb '<br>' '<b> Cliente: </b>' w_parid '<br>' '<b> NF: </b>' w_nfnum '<br>' '<b> Série: </b>' <ls_t1_nf>-series '<br>' INTO wa_objtxt-line SEPARATED BY space.
                APPEND wa_objtxt TO i_objtxt.
              ENDIF.
              wa_objtxt-line = '</html>'.
              APPEND wa_objtxt TO i_objtxt.

              DESCRIBE TABLE i_objtxt LINES v_lines_txt.

              CLEAR wa_doc_chng.
              IF w_qtdiaszerado = 'S'.
                CONCATENATE 'Programação' w_numemb ' Forma de pgto sem qtde de dias' INTO wa_doc_chng-obj_descr SEPARATED BY space.
              ELSE.
                CONCATENATE 'Programação' w_numemb ' Forma de pgto não encontrada' INTO wa_doc_chng-obj_descr SEPARATED BY space.
              ENDIF.
              wa_doc_chng-sensitivty = 'O'.
              wa_doc_chng-priority   = '5'.
              wa_doc_chng-doc_size   = v_lines_txt * 255.

              CLEAR: wa_objpack.
              wa_objpack-head_start = 1.
              wa_objpack-head_num   = 0.
              wa_objpack-body_start = 1.
              wa_objpack-body_num   = v_lines_txt.
              wa_objpack-doc_type   = 'HTM'.
              APPEND wa_objpack TO i_objpack.

              CALL FUNCTION 'SO_NEW_DOCUMENT_ATT_SEND_API1'
                EXPORTING
                  document_data              = wa_doc_chng
                  put_in_outbox              = 'X'
                  commit_work                = 'X'
                TABLES
                  packing_list               = i_objpack
                  contents_txt               = i_objtxt
                  receivers                  = i_reclist
                EXCEPTIONS
                  too_many_receivers         = 1
                  document_not_sent          = 2
                  document_type_not_exist    = 3
                  operation_no_authorization = 4
                  parameter_error            = 5
                  x_error                    = 6
                  enqueue_error              = 7
                  OTHERS                     = 8.

              v_erro = x. EXIT.

            ELSE.
              <ls_t1_nf>-zterm = w_zterm.
            ENDIF.

          ENDIF.
        ENDIF.

        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
          EXPORTING
            input  = <ls_t1_nf>-authcod
          IMPORTING
            output = <ls_t1_nf>-authcod.

        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
          EXPORTING
            input  = <ls_t1_nf>-code
          IMPORTING
            output = <ls_t1_nf>-code.

        MOVE-CORRESPONDING <ls_t1_nf> TO ls_zvm_nf.
        ls_zvm_nf-id = v_id.

        INSERT zvm_nf FROM ls_zvm_nf.

        IF sy-subrc <> 0.
          v_erro = x.
          EXIT.
        ENDIF.

        IF ls_zvm_nf-extra = 'X'
          AND ls_zvm_nf-vbeln_ori IS NOT INITIAL.
          CLEAR w_vbeln_ori.
          PACK ls_zvm_nf-vbeln_ori TO w_vbeln_ori.
          SELECT SINGLE @abap_true FROM vbak INTO @DATA(lv_vbak_exists) WHERE vbeln EQ @ls_zvm_nf-vbeln_ori.
          IF sy-subrc = 0.
            CALL FUNCTION 'ZMOB_DEL_ORDEM'
              EXPORTING
                i_vbeln      = ls_zvm_nf-vbeln_ori
              IMPORTING
                e_code       = w_code
                e_err_string = w_err_string
              TABLES
                t_result     = t_result.
            IF w_code NE 0.
              v_erro = x.
              EXIT.
            ENDIF.
          ENDIF.
        ENDIF.

        v_somapeso = 0.

        LOOP AT t2_nf_it ASSIGNING <ls_t2_nf_it>
          WHERE nfnum  = <ls_t1_nf>-nfnum
            AND series = <ls_t1_nf>-series.

          IF <ls_t2_nf_it>-matnr CO '0123456789 '.
            UNPACK <ls_t2_nf_it>-matnr TO <ls_t2_nf_it>-matnr.
          ENDIF.

          CASE <ls_t1_nf>-tipo_nf.
            WHEN c_cupom_fiscal.
              CLEAR ti_mard.
              CALL FUNCTION 'ZVM_GET_ESTOQUE'
                EXPORTING
                  i_exercicio    = sy-datum(4)
                  i_werks        = <ls_t1_nf>-werks
                  i_matnr        = <ls_t2_nf_it>-matnr
                  i_lgort        = <ls_t2_nf_it>-lgort
                  i_soma_estoque = ' '
                TABLES
                  t_mard         = ti_mard
                EXCEPTIONS
                  not_found      = 1
                  OTHERS         = 2.

              IF <ls_t2_nf_it>-lgort IS INITIAL AND <ls_t1_nf>-werks NE '0400'.
                SORT ti_mard BY labst ASCENDING.

                LOOP AT ti_mard INTO ls_mard WHERE labst >= <ls_t2_nf_it>-menge.
                  <ls_t2_nf_it>-lgort = ls_mard-lgort.
                  EXIT.
                ENDLOOP.
              ELSE.
                IF <ls_t1_nf>-werks EQ '0400'.
                  <ls_t2_nf_it>-lgort = '0401'.
                ENDIF.
              ENDIF.

            WHEN c_nota_caminhao.

              SELECT SINGLE lgort INTO @<ls_t2_nf_it>-lgort
                 FROM zvm_nota_control
                 WHERE werks EQ @<ls_t1_nf>-werks AND
                       series EQ @<ls_t1_nf>-series.

              IF <ls_t2_nf_it>-matnr EQ 'GLP'.
                v_somapeso = v_somapeso + <ls_t2_nf_it>-menge.
              ELSE.
                MOVE: <ls_t2_nf_it>-menge   TO v_menge,
                      <ls_t2_nf_it>-matnr+1 TO v_matnr.
                v_somapeso = v_somapeso + ( v_matnr * v_menge ).
              ENDIF.
          ENDCASE.

          MOVE-CORRESPONDING <ls_t2_nf_it> TO ls_zvm_nf_it.
          ls_zvm_nf_it-id = v_id.
          INSERT zvm_nf_it FROM ls_zvm_nf_it.

          IF sy-subrc <> 0.
            v_erro = x.
            EXIT.
          ENDIF.

        ENDLOOP.

        IF v_erro = x.
          EXIT.
        ENDIF.

        IF ( v_somapeso <> <ls_t1_nf>-ntgew AND <ls_t1_nf>-tipo_nf EQ c_nota_caminhao ).
          v_erro = x. EXIT.
        ENDIF.

        LOOP AT t3_nf_it_cond ASSIGNING <ls_t3_nf_it_cond>
          WHERE nfnum  = <ls_t1_nf>-nfnum
            AND series = <ls_t1_nf>-series.
          MOVE-CORRESPONDING <ls_t3_nf_it_cond> TO ls_zvm_nf_it_cond.
          ls_zvm_nf_it_cond-id = v_id.
          INSERT zvm_nf_it_cond FROM ls_zvm_nf_it_cond.

          IF sy-subrc <> 0.
            v_erro = x.
            EXIT.
          ENDIF.

        ENDLOOP.

        IF v_erro = x.
          EXIT.
        ENDIF.

        IF <ls_t1_nf>-tipo_nf = c_cupom_fiscal.
          LOOP AT t4_nf_pagto ASSIGNING <ls_t4_nf_pagto>
            WHERE nfnum  = <ls_t1_nf>-nfnum
              AND series = <ls_t1_nf>-series.
            MOVE-CORRESPONDING <ls_t4_nf_pagto> TO ls_zvm_nf_pagto.
            ls_zvm_nf_pagto-id = v_id.
            INSERT zvm_nf_pagto FROM ls_zvm_nf_pagto.

            IF sy-subrc <> 0.
              v_erro = x.
              EXIT.
            ENDIF.

          ENDLOOP.
        ENDIF.

        IF v_erro = x.
          EXIT.
        ENDIF.

      ENDLOOP.

      IF v_erro IS INITIAL.

        CLEAR ti_max_nf.

        SELECT series, werks, MAX( nfnum ) AS nfnum
          INTO TABLE @ti_max_nf
          FROM zvm_nf
         WHERE tipo_nf <> @c_cupom_fiscal
           AND tipo_nf <> @c_orgao_publico
           AND doctype = 'ZGEN'
         GROUP BY series, werks.

        SORT ti_max_nf BY series werks ASCENDING.

        LOOP AT ti_max_nf INTO ls_max_nf.

          SELECT SINGLE *
            FROM zvm_nota_control
            INTO @ls_zvm_nota_control
           WHERE series = @ls_max_nf-series
             AND werks = @ls_max_nf-werks.

          IF sy-subrc = 0.
            vl_nfnum_n6 = ls_max_nf-nfnum.
            IF ls_zvm_nota_control-nfnum < vl_nfnum_n6.
              ls_zvm_nota_control-nfnum = vl_nfnum_n6.
              MODIFY zvm_nota_control FROM ls_zvm_nota_control.
              IF sy-subrc <> 0.
                v_erro = x.
                EXIT.
              ENDIF.
            ENDIF.
          ELSE.
            CLEAR ls_zvm_nota_control.
            ls_zvm_nota_control-series = ls_max_nf-series.
            ls_zvm_nota_control-nfnum  = ls_max_nf-nfnum.
            INSERT zvm_nota_control FROM ls_zvm_nota_control.
            IF sy-subrc <> 0.
              v_erro = x.
              EXIT.
            ENDIF.
          ENDIF.
        ENDLOOP.

        CLEAR ti_max_nf.

        SELECT series, werks, MAX( nfnum ) AS nfnum
          INTO TABLE @ti_max_nf
          FROM zvm_nf
         WHERE tipo_nf <> @c_cupom_fiscal
           AND tipo_nf <> @c_orgao_publico
           AND ( doctype = 'ZFPR' OR doctype = 'ZFGR' OR
                 doctype = 'ZEAV' OR doctype = 'ZSAV' )
         GROUP BY series, werks.

        SORT ti_max_nf BY series werks ASCENDING.

        LOOP AT ti_max_nf INTO ls_max_nf.

          SELECT SINGLE *
            FROM zvm_nota_control
            INTO @ls_zvm_nota_control
           WHERE series = @ls_max_nf-series
             AND werks  = @ls_max_nf-werks.

          IF sy-subrc = 0.
            IF ls_zvm_nota_control-nfenum < ls_max_nf-nfnum.
              ls_zvm_nota_control-nfenum = ls_max_nf-nfnum.
              MODIFY zvm_nota_control FROM ls_zvm_nota_control.
              IF sy-subrc <> 0.
                v_erro = x.
                EXIT.
              ENDIF.
            ENDIF.
          ELSE.
            CLEAR ls_zvm_nota_control.
            ls_zvm_nota_control-series  = ls_max_nf-series.
            ls_zvm_nota_control-nfenum  = ls_max_nf-nfnum.
            ls_zvm_nota_control-werks   = ls_max_nf-werks.
            INSERT zvm_nota_control FROM ls_zvm_nota_control.
            IF sy-subrc <> 0.
              v_erro = x.
              EXIT.
            ENDIF.
          ENDIF.
        ENDLOOP.
      ENDIF.

      CLEAR ls_nfc_sintegra.
      LOOP AT t1_nf INTO ls_nf.
        IF ls_nf-doctype NE 'ZNFC'.
          CONTINUE.
        ENDIF.

        lv_tamanho = strlen( ls_nf-cpf_nfce ).
        IF  lv_tamanho <= 11.
          CONTINUE.
        ENDIF.

        SELECT SINGLE stcd1 INTO @DATA(lv_stcd1)
          FROM zsd_nfc_sintegra
          WHERE stcd1 = @ls_nf-cpf_nfce.

        IF  sy-subrc EQ 0.
          CONTINUE.
        ENDIF.

        SELECT SINGLE regio INTO @lv_regio
          FROM zdepara_config WHERE vkorg = @ls_nf-sales_org.

        ls_nfc_sintegra-mandt = sy-mandt.
        ls_nfc_sintegra-stcd1 = ls_nf-cpf_nfce.
        ls_nfc_sintegra-vkorg = ls_nf-sales_org.
        ls_nfc_sintegra-data_inc = sy-datum.
        ls_nfc_sintegra-hora_inc = sy-uzeit.
        ls_nfc_sintegra-uf    = lv_regio.
        MODIFY zsd_nfc_sintegra FROM ls_nfc_sintegra.
        CLEAR ls_nfc_sintegra.
      ENDLOOP.

      IF v_erro IS INITIAL.
        PERFORM clear_lock USING t1_nf.
      ELSE.
        ROLLBACK WORK.
        PERFORM clear_lock USING t1_nf.
        RAISE ex_erro_ins_nf.
      ENDIF.
  ENDTRY.

ENDFUNCTION.

*&---------------------------------------------------------------------*
*&      Form  clear_lock
*&---------------------------------------------------------------------*
FORM clear_lock USING pt_nf TYPE STANDARD TABLE OF zvm_nf_in.

  DATA: ls_nf               TYPE zvm_nf_in,
        ls_zvm_lock_gravanf TYPE zvm_lock_gravanf.

  LOOP AT pt_nf INTO ls_nf.
    CLEAR ls_zvm_lock_gravanf.
    MOVE-CORRESPONDING ls_nf TO ls_zvm_lock_gravanf.

    SELECT SINGLE *
      FROM zvm_lock_gravanf
      INTO @ls_zvm_lock_gravanf
      WHERE nfnum     = @ls_zvm_lock_gravanf-nfnum
        AND series    = @ls_zvm_lock_gravanf-series
        AND sales_org = @ls_zvm_lock_gravanf-sales_org.

    IF sy-subrc EQ 0.
      DELETE FROM zvm_lock_gravanf
        WHERE nfnum     = @ls_zvm_lock_gravanf-nfnum
          AND series    = @ls_zvm_lock_gravanf-series
          AND sales_org = @ls_zvm_lock_gravanf-sales_org.
    ENDIF.
  ENDLOOP.

  COMMIT WORK AND WAIT.
ENDFORM.
