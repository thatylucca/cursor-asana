function ZCD_PROC_ZRCM.
*"----------------------------------------------------------------------
*"*"Interface local:
*"  IMPORTING
*"     VALUE(I_EMISSOR) TYPE  KUNNR
*"     VALUE(I_RECEBEDOR) TYPE  KUNNR
*"     VALUE(I_VBELN) TYPE  VBELN_VA OPTIONAL
*"     VALUE(I_LIFNR) TYPE  LIFNR OPTIONAL
*"     VALUE(I_AGENDA) TYPE  CHAR10 OPTIONAL
*"     VALUE(I_DADOS_ADC) TYPE  STRING OPTIONAL
*"  EXPORTING
*"     VALUE(COD_RETORNO) TYPE  CHAR4
*"     VALUE(MSG_RETORNO) TYPE  CHAR100
*"     VALUE(MSG_SOLUCAO) TYPE  CHAR100
*"     VALUE(E_VBELN) TYPE  VBELN_VA
*"     VALUE(E_VBELN_VL) TYPE  VBELN_VL
*"     VALUE(E_VBELN_VF) TYPE  VBELN_VF
*"     VALUE(E_DOCNUM) TYPE  J_1BDOCNUM
*"     VALUE(E_NFENUM) TYPE  J_1BNFNUM9
*"     VALUE(E_SERIES) TYPE  J_1BSERIES
*"  TABLES
*"      T_ORDEM_H STRUCTURE  ZMOB_ORDEM
*"      T_ORDEM_I STRUCTURE  ZMOB_ORDEM_ITEM
*"----------------------------------------------------------------------
* 001 - Erro no fornecimento da remessa na org venda 8000              *
*                                                                      *
*                    Master Análise e Programação - D Sávio 09/09/2021 *
*----------------------------------------------------------------------*
* 002 - Mudança para pegar os campos WERKS e LGORT, para evitar erros  *
*       no fornecimento                                                *
*                    Master Análise e Programação - D Sávio 14/12/2021 *
*----------------------------------------------------------------------*
* 003 - Após a confirmação do faturamento da ordem, para MATNR = 'B190'*
*       com MARA-RAUBE = '3' ou '03', montar em memória o movimento    *
*       561 (entrada inicial de estoque) via PERFORM interno           *
*       ZF_MONTA_MOV_561, SEM CALL FUNCTION remoto e SEM postagem      *
*       no SAP.                                                        *
*                                       D Sávio 30/09/2026             *
*----------------------------------------------------------------------*
data: wa_ordem_guid    type guid_32,
      it_ordem_h       type table of zmob_ordem,
      wa_ordem_h       type          zmob_ordem,
      it_ordem_i       type table of zmob_ordem_item,
      wa_ordem_i       type          zmob_ordem_item,
      it_ordem_zmob    type table of zmob_ordem_est,
      wa_ordem_zmob    type          zmob_ordem_est,
      it_guid          type table of zmob_guid_est,
      wa_guid          type          zmob_guid_est,
      wa_tab           type          thead,
      wa_linha         type          string,
      it_line          type table of tline,
      wa_line          type          tline,
      wa_nome          type          tdobname,
      it_result_zmob   type table of zmob_ins_ordem_result,
      it_vbap          type table of vbap,
      wa_vbap          type          vbap,
      it_itens         type table of zcd_reg_baixa_estoque,
      wa_itens         type          zcd_reg_baixa_estoque,
      wa_ordem         type vbeln_va,
      wa_vstel         type vstel,
      wa_lgort         type lgort_d,
      it_lips          type table of lips,
      wa_lips          type          lips,
      it_bapivbrk      type bapivbrk occurs 0 with header line,
      it_result_bapi   like bapiret1 occurs 0 with header line,
      it_success_bapi  like bapivbrksuccess occurs 0 with header line,
      it_errors_bapi   like bapivbrkerrors occurs 0 with header line,
      wa_fornecimento  type vbeln_vl,
      wa_faturamento   type vbeln_vf,
      wa_docnum        type j_1bdocnum,
      wa_nfenum        type j_1bnfnum9,
      wa_series        type j_1bseries,
      it_bdc_tab       like bdcdata occurs 0 with header line,
      wa_ctuparams     type ctu_params,
      it_bdcmsg        like bdcmsgcoll occurs 0 with header line,
      wa_knvv          type knvv,
      wa_vbak          type vbak,
      wa_zcd_tb_notas  type zcd_tb_notas,
      wa_data(08)      type c,
      wa_campo1(15)    type c,
      wa_campo2(15)    type c,
      wa_valor(15)     type c,
      wa_pos(02)       type c,
      wa_cont          type i,
      wa_tot           type i,
      wa_qtmsg(03)     type n,
      wa_werks         type werks_d,
      v_raube          type raube,
      it_vbap_561      type table of vbap,
      wa_vbap_561      type          vbap,
      v_raube_561      type raube,
      wa_lgort_561     type lgort_d,
      wa_erro(1)       type c,
      wa_cod_retorno   type char4,
      wa_msg_retorno   type char100,
      wa_msg_solucao   type	char100.

field-symbols: <fs_t_ordem_i> type zmob_ordem_item.

ranges: r_docnum for j_1bnferfcbatch-docnum.
  " Buscando documentos da ordem de cobertura
  clear wa_zcd_tb_notas.
  if i_agenda eq ' '.
    select single * into wa_zcd_tb_notas from zcd_tb_notas
      where vbeln = i_vbeln.
  else.
    select single * into wa_zcd_tb_notas from zcd_tb_notas
      where num_agenda = i_agenda.
  endif.
  if sy-subrc eq 0.
    move: wa_zcd_tb_notas-nfenum   to e_nfenum,
          wa_zcd_tb_notas-nfenum   to wa_nfenum,
          wa_zcd_tb_notas-series   to e_series,
          wa_zcd_tb_notas-series   to wa_series,
          wa_zcd_tb_notas-docnum   to e_docnum,
          wa_zcd_tb_notas-docnum   to wa_docnum,
          wa_zcd_tb_notas-vbeln    to e_vbeln,
          wa_zcd_tb_notas-vbeln    to wa_ordem,
          wa_zcd_tb_notas-vbeln_vl to e_vbeln_vl,
          wa_zcd_tb_notas-vbeln_vl to wa_fornecimento,
          wa_zcd_tb_notas-vbeln_vf to e_vbeln_vf,
          wa_zcd_tb_notas-vbeln_vf to wa_faturamento.
  else.
    clear: wa_zcd_tb_notas,
           wa_ordem,
           wa_fornecimento,
           wa_faturamento,
           wa_docnum,
           wa_nfenum,
           wa_series,
           e_vbeln,
           e_vbeln_vl,
           e_vbeln_vf,
           e_series,
           e_nfenum.
    wa_zcd_tb_notas-emissor    = i_emissor.
    wa_zcd_tb_notas-recebedor  = i_recebedor.
    wa_zcd_tb_notas-erdat      = sy-datum.
    wa_zcd_tb_notas-erzet      = sy-uzeit.
    wa_zcd_tb_notas-auart      = 'ZRCM'.
    wa_zcd_tb_notas-placa      = i_lifnr.
    wa_zcd_tb_notas-num_agenda = i_agenda.
  endif.
  " Criando a ordem ZRCM
  if e_vbeln is initial.
    call function 'GUID_CREATE'
      IMPORTING
        ev_guid_32 = wa_ordem_guid.
    if sy-subrc ne 0.
      cod_retorno = 'E001'.
      msg_retorno = 'Erro ao gerar GUID. (E1)'.
      EXIT.
    endif.
    read table t_ordem_h into wa_ordem_h index 1.
    wa_ordem_h-guid = wa_ordem_guid.
    modify t_ordem_h from wa_ordem_h index 1 transporting guid.
    loop at t_ordem_i assigning <fs_t_ordem_i>.
      <fs_t_ordem_i>-guid = wa_ordem_guid.
    endloop.
    " Cria a Ordem
    call function 'ZMOB_INS_ORDEM'
      TABLES
        t_ordem_h     = t_ordem_h
        t_ordem_i     = t_ordem_i
        t_result      = it_result_zmob
      EXCEPTIONS
        e_ins_ordem_h = 1
        e_ins_ordem_i = 2
        e_ins_time    = 3
        others        = 4.
    if sy-subrc eq 0.
     " Recupera o Número da Ordem
      wa_guid-guid = wa_ordem_guid.
      append wa_guid to it_guid.
      call function 'ZMOB_GET_ORDENS'
        EXPORTING
          i_use_guid_list = 'X'
        TABLES
          t_ordem         = it_ordem_zmob
          t_guid          = it_guid.
      if sy-subrc ne 0.
        cod_retorno = 'E002'.
        msg_retorno = 'Erro ao recuperar ordem. (E2)'.
        exit.
      endif.
    else.
      cod_retorno = 'E003'.
      msg_retorno = 'Erro ao criar ordem. (E3)'.
      exit.
    endif.
    read table it_ordem_zmob index 1 into wa_ordem_zmob.
    if wa_ordem_zmob-vbeln is initial.
      cod_retorno = 'E004'.
      msg_retorno = 'Erro ao criar ordem. (E4)'.
      exit.
    else.
      wa_ordem = wa_ordem_zmob-vbeln.
      e_vbeln  = wa_ordem_zmob-vbeln.
      wa_zcd_tb_notas-vbeln = e_vbeln.
      modify zcd_tb_notas from wa_zcd_tb_notas.
      commit work and wait.
      wait up to 5 seconds.
    endif.
    if i_agenda ne ' '.
*     "Incluir texto na ordem
      clear: it_line, it_line[], wa_tab.
      wa_tab-tdobject   = 'VBBK'.
      wa_tab-tdid       = 'Z003'.
      wa_tab-tdspras    = 'P'.
      wa_tab-tdname     = wa_ordem.
      wa_line-tdformat = '*.'.
      concatenate 'Abastecimento agenda n°:' i_agenda
                                           into wa_linha separated by space.
      wa_line-tdline = wa_linha.
      append wa_line to it_line.
      call function 'SAVE_TEXT'
        EXPORTING
          client          = sy-mandt
          header          = wa_tab
          savemode_direct = 'X'
        TABLES
          lines           = it_line
        EXCEPTIONS
          id              = 1
          language        = 2
          name            = 3
          object          = 4
          others          = 5.
      if sy-subrc eq 0.
        move wa_ordem to wa_nome.
        call function 'COMMIT_TEXT'
          EXPORTING
            object   = 'VBBK'
            name     = wa_nome
            id       = 'Z003'
            language = 'P'.
      endif.
    endif.
  endif.

  " Criar fornecimento
  if e_vbeln_vl is initial.
    " Verifica se o fornecimento já foi criado
    select single vbeln from vbfa
      into e_vbeln_vl
      where vbelv = e_vbeln and
        ( ( vbtyp_n = 'T' and vbtyp_v = 'H' ) or " remessa da ZRCN
          ( vbtyp_n = 'J' and vbtyp_v = 'C' ) ). " remessa da ZRCM
    if sy-subrc = 0.
      wa_zcd_tb_notas-vbeln_vl = e_vbeln_vl.
      modify zcd_tb_notas from wa_zcd_tb_notas.
      commit work and wait.
    else.
      clear: wa_vbak, it_vbap, it_vbap[].
      select single * from vbak into wa_vbak
        where vbeln = wa_ordem.
      select * from vbap into table it_vbap
        where vbeln = wa_ordem.
      if wa_vbak is initial or it_vbap[] is initial.
        cod_retorno = 'E005'.
        msg_retorno = 'Erro no fornecimento da ordem. (E5)'.
        exit.
      endif.
      "Definindo local de expedição e depósito
      clear: wa_werks, wa_lgort, wa_vstel.
* Inicio Alteração 001 -     09.09.2021 ---------------------
* Inicio Alteração 002 -     14.12.2021 ---------------------
*      concatenate '0' wa_vbak-vkorg(3) into wa_werks.
      select single werks into wa_werks from zdepara_config
        where vkorg = wa_vbak-vkorg.
* Final Alteração  002 -     14.12.2021 ---------------------
      read table it_vbap into wa_vbap index 1.
      wa_vstel = wa_vbap-vstel.
* Inicio Alteração 002 -     14.12.2021 ---------------------
*      wa_lgort = wa_vbap-vstel.
      select single raube into v_raube from mara
        where matnr = wa_vbap-matnr.
      select single lgort into wa_lgort from tvkol
        where vstel = wa_vstel and
              werks = wa_werks and
              raube = v_raube.


      if V_RAUBE = '3' and wa_vbap-matnr = 'B190'.
        select single lgort into wa_lgort from zvm_cfg_fat
          where werks    eq wa_werks and
                vstel    eq wa_vstel and
                xfluvial ne 'X' and xgranel ne 'X'.
      endif.


* Final Alteração  002 -     14.12.2021 ---------------------
      "Para rotina Fogas Log o campo wa_vstel é carregado
      if i_agenda ne ' '.
*      select single werks into wa_werks from zdepara_config
*        where vkorg = wa_vbak-vkorg.
        select single lgort into wa_lgort from zvm_cfg_fat
          where werks    eq wa_werks and
                xfluvial ne 'X'.
*      select single vstel lgort into (wa_vstel, wa_lgort)
*          from zvm_cfg_fat
*        where werks    eq wa_werks      and
**             vstel    eq wa_vbap-vstel and
*              xgranel  ne 'X'           and
*              xfluvial ne 'X'.
* Final Alteração  001 -     09.09.2021 ---------------------
        if sy-subrc ne 0.
          cod_retorno = 'E006'.
          msg_retorno = 'Local de expedição e/ou depósito não podem ser determinados. (E6)'.
          exit.
        endif.
* Inicio Alteração 001 -     09.09.2021 ---------------------
      endif.
* Final Alteração  001 -     09.09.2021 ---------------------
      write wa_vbak-vdatu to wa_data.
      refresh: it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-program  = 'SAPMV50A'.
      it_bdc_tab-dynpro   = '4001'.
      it_bdc_tab-dynbegin = 'X'.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-fnam     = 'BDC_OKCODE'.
      it_bdc_tab-fval     = '/00'.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-fnam     = 'LIKP-VSTEL'.
      it_bdc_tab-fval     = wa_vstel.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-fnam     = 'LV50C-VBELN'.
      it_bdc_tab-fval     = wa_ordem.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-program  = 'SAPMV50A'.
      it_bdc_tab-dynpro   = '1000'.
      it_bdc_tab-dynbegin = 'X'.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-fnam     = 'BDC_OKCODE'.
      it_bdc_tab-fval     = '=T\01'.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-program = 'SAPMV50A'.
      it_bdc_tab-dynpro = '1000'.
      it_bdc_tab-dynbegin = 'X'.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-fnam     = 'LIKP-WADAT_IST'.
      it_bdc_tab-fval     = wa_data.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-fnam     = 'BDC_OKCODE'.
      it_bdc_tab-fval     = '=T\02'.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-program  = 'SAPMV50A'.
      it_bdc_tab-dynpro   = '1000'.
      it_bdc_tab-dynbegin = 'X'.
      append it_bdc_tab.
      clear it_bdc_tab.
      it_bdc_tab-fnam     = 'BDC_OKCODE'.
      it_bdc_tab-fval     = '=WABU_T'.
      append it_bdc_tab.
      describe table it_vbap lines wa_tot.
      loop at it_vbap into wa_vbap.
        add 1 to wa_cont.
        unpack wa_cont to wa_pos.
        if wa_zcd_tb_notas-auart <> 'ZRCD'.
          concatenate 'LIPS-LGORT(' wa_pos ')' into wa_campo1.
          clear it_bdc_tab.
          it_bdc_tab-fnam = wa_campo1.
          it_bdc_tab-fval = wa_lgort.
          append it_bdc_tab.
*        if wa_zcd_tb_notas-auart <> 'ZRCD'.
          concatenate 'LIPSD-PIKMG(' wa_pos ')' into wa_campo2.
          write wa_vbap-kwmeng to wa_valor.
          clear it_bdc_tab.
          it_bdc_tab-fnam = wa_campo2.
          it_bdc_tab-fval = wa_valor.
          append it_bdc_tab.
        endif.
        if wa_cont = 8.
          " Próxima página de produtos
          clear it_bdc_tab.
          it_bdc_tab-fnam = 'BDC_OKCODE'.
          it_bdc_tab-fval = '=NPAG_T'.
          append it_bdc_tab.
          subtract wa_cont from wa_tot.
          if wa_tot >= 8.
            move 0 to wa_cont.
          else.
            subtract wa_tot from wa_cont.
          endif.
        endif.
      endloop.
      clear it_bdcmsg.
      refresh it_bdcmsg.
      wa_ctuparams-dismode  = 'N'.
      wa_ctuparams-updmode  = 'S'.
      wa_ctuparams-defsize  = 'X'.
      wa_ctuparams-racommit = space.
      wa_ctuparams-nobinpt  = 'X'.
      wa_ctuparams-nobiend  = space.
*      set parameter id 'VL' field ''.
      call transaction 'VL01N'  using it_bdc_tab
                                options from wa_ctuparams
                                messages into it_bdcmsg.
      if sy-subrc ne 0.
        cod_retorno = 'E008'.
        concatenate 'Erro no fornecimento da ordem' wa_ordem '(E8)'
                                    into msg_retorno separated by space.
        exit.
      endif.
      describe table it_bdcmsg lines wa_qtmsg.
      read table it_bdcmsg with key msgtyp = 'E'.
      if sy-subrc = 0.
        cod_retorno = 'E009'.
        concatenate 'Erro no fornecimento da ordem' wa_ordem '(E9)'
                                    into msg_retorno separated by space.
        exit.
      else.
        commit work.
        if wa_qtmsg = 0.
*          concatenate 'Erro fornecimento, transação sem erros, mas não'
*          'gerou mensagens' wa_ordem '(E9)'
*                                    into msg_retorno separated by space.
*          exit.
          select single vbeln from vbfa
            into e_vbeln_vl
            where vbelv = e_vbeln and
              ( ( vbtyp_n = 'T' and vbtyp_v = 'H' ) or " remessa da ZRCN
                ( vbtyp_n = 'J' and vbtyp_v = 'C' ) ). " remessa da ZRCM
          if sy-subrc = 0.
            wa_zcd_tb_notas-vbeln_vl = e_vbeln_vl.
          else.
            concatenate 'Erro fornecimento, transação sem erros,'
              'mas não gerou mensagens' wa_ordem '(E10)'
                                    into msg_retorno separated by space.
            exit.
          endif.
        endif.
        wait up to 10 seconds.
        get parameter id 'VL' field wa_fornecimento.
        if wa_fornecimento = ' '.
          concatenate 'Erro no fornecimento da ordem' wa_ordem '(E11)'
                                    into msg_retorno separated by space.
          exit.
        endif.
        e_vbeln_vl = wa_fornecimento.
        wa_zcd_tb_notas-vbeln_vl = e_vbeln_vl.
        modify zcd_tb_notas from wa_zcd_tb_notas.
        commit work and wait.
      endif.
    endif.
  endif.

  if e_vbeln_vl is not initial and i_dados_adc is not initial.
    perform zf_grava_texto_ztra using e_vbeln_vl
                                      i_dados_adc.
  endif.

  if e_vbeln_vf is initial.
    " Verifica se o faturamento foi criado
    select single vbeln from vbfa
      into e_vbeln_vf
      where vbelv = e_vbeln and
        ( ( vbtyp_n = 'O' and vbtyp_v = 'H' ) or " faturamento da ZRCN
          ( vbtyp_n = 'M' and vbtyp_v = 'C' ) ). " faturamento da ZRCM
    if sy-subrc = 0.
      wa_zcd_tb_notas-vbeln_vf = e_vbeln_vf.
      wa_faturamento           = e_vbeln_vf.
      modify zcd_tb_notas from wa_zcd_tb_notas.
      commit work and wait.
    else.
      select * into table it_lips from lips
        where vbeln = wa_fornecimento.
      if sy-subrc ne 0.
        cod_retorno = 'E009'.
        concatenate 'Erro no fornecimento da ordem' wa_fornecimento
                           '(E9)' into msg_retorno separated by space.
        exit.
      endif.
      loop at it_lips into wa_lips.
        select single * from vbak into wa_vbak
          where vbeln = wa_lips-vgbel.
        it_bapivbrk-salesorg   = wa_vbak-vkorg.
        it_bapivbrk-distr_chan = wa_vbak-vtweg.
        it_bapivbrk-division   = wa_vbak-spart.
        it_bapivbrk-doc_type   = wa_vbak-auart.
        it_bapivbrk-bill_date  = wa_vbak-audat.
        it_bapivbrk-sold_to    = wa_vbak-kunnr.
        it_bapivbrk-item_categ = wa_lips-pstyv.
        it_bapivbrk-req_qty    = wa_lips-lgmng.
        it_bapivbrk-sales_unit = wa_lips-vrkme.
        it_bapivbrk-currency   = wa_vbak-waerk.
        it_bapivbrk-plant      = wa_lips-werks.
        it_bapivbrk-ref_doc    = wa_lips-vbeln.
        if wa_vbak-auart = 'ZRCD'.
          it_bapivbrk-ref_doc  = wa_vbak-xblnr.
        endif.
        it_bapivbrk-ref_item   = wa_lips-posnr.
        it_bapivbrk-material   = wa_lips-matnr.
        it_bapivbrk-origindoc  = wa_lips-vgbel.
        if wa_vbak-auart = 'ZRCD'.
          it_bapivbrk-origindoc  = wa_vbak-xblnr.
        endif.
        it_bapivbrk-item       = wa_lips-vgpos.
        it_bapivbrk-ref_doc_ca = 'J'.
        append it_bapivbrk.
      endloop.
      refresh: it_errors_bapi,
               it_result_bapi,
               it_success_bapi.
      call function 'BAPI_BILLINGDOC_CREATEMULTIPLE'
        TABLES
          billingdatain = it_bapivbrk
          errors        = it_errors_bapi
          return        = it_result_bapi
          success       = it_success_bapi.
      loop at it_result_bapi where type eq 'E'.
        cod_retorno = 'E010'.
        concatenate 'Erro no faturamento da ordem' wa_ordem
                           '(E10)' into msg_retorno separated by space.
        exit.
      endloop.
      loop at it_success_bapi.
        if it_success_bapi-ref_doc = wa_fornecimento and
           it_success_bapi-bill_doc is not initial.
          wa_faturamento           = it_success_bapi-bill_doc.
          e_vbeln_vf               = wa_faturamento.
          wa_zcd_tb_notas-vbeln_vf = e_vbeln_vf.
          modify zcd_tb_notas from wa_zcd_tb_notas.
          commit work and wait.
          wait up to 5 seconds.
          exit.
        endif.
      endloop.
    endif.
  endif.

* Inicio Alteração 003 -     30.09.2026 ---------------------
* Após a confirmação do faturamento da ordem (E_VBELN_VF preenchido),
* se o item for MATNR = 'B190' com MARA-RAUBE = '3' ou '03', monta em
* memória o movimento 561 (entrada inicial de estoque) via PERFORM
* interno ZF_MONTA_MOV_561. NÃO faz CALL FUNCTION remoto e NÃO posta
* nem ativa nada no SAP.
  if e_vbeln_vf is not initial.
    refresh it_vbap_561.
    select * from vbap into table it_vbap_561
      where vbeln = wa_ordem
        and matnr = 'B190'.
    loop at it_vbap_561 into wa_vbap_561.
      clear v_raube_561.
      select single raube into v_raube_561 from mara
        where matnr = wa_vbap_561-matnr.
      if v_raube_561 = '3' or v_raube_561 = '03'.
        wa_lgort_561 = wa_lgort.
        if wa_lgort_561 is initial.
          wa_lgort_561 = wa_vbap_561-lgort.
        endif.
        perform zf_monta_mov_561 using wa_vbap_561-matnr
                                       wa_vbap_561-werks
                                       wa_lgort_561
                                       wa_vbap_561-kwmeng
                                       wa_vbap_561-vrkme.
      endif.
    endloop.
  endif.
* Final Alteração  003 -     30.09.2026 ---------------------

  " Baixa de estoque Ordem ZRCN
*  if wa_zcd_tb_notas-auart <> 'ZRCN'.
*    concatenate '0' i_kunnr+6(03) into wa_centro.
*
*    "Testar tabela se vazia ler novamente
*    loop at it_vbap into wa_vbap.
*      clear: wa_labst.
*      select single labst into wa_labst from mard
*        where matnr = wa_vbap-matnr and
*              werks = wa_werks      and
*              lgort = '102'.             "Depósito pátio
*      if wa_vbap-matnr = 'B02' or
*         wa_vbap-matnr = 'B20' or
*         wa_vbap-matnr = 'B45'.
*        if wa_vbap-kwmeng le wa_labst.
*          "Preenche tabela para mandar email
*        else.
*          "compensa estoque
*        endif.
*      else.
*        if
*      endif.
*    endloop.
*    if it_tabemail[] is not initial.
*      "send email
*    endif.
*  endif.

  " Recuperando DOCNUM
  if e_docnum is initial.
    select single docnum from j_1bnflin
      into e_docnum
      where refkey eq e_vbeln_vf.
    if e_docnum is not initial.
      wa_zcd_tb_notas-docnum = e_docnum.
      wa_docnum              = e_docnum.
      modify zcd_tb_notas from wa_zcd_tb_notas.
      clear: r_docnum[], r_docnum.
      r_docnum-option = 'EQ'.
      r_docnum-sign   = 'I'.
      r_docnum-low    = e_docnum.
      append r_docnum.

      " Baixa de estoque Ordem ZRCN
      if it_lips[] is initial.
        select * into table it_lips from lips
          where vbeln = wa_fornecimento.
      endif.
      read table it_lips into wa_lips index 1.
      wa_lgort = wa_lips-lgort.
      if wa_zcd_tb_notas-auart = 'ZRCD'.
        select matnr fkimg from vbrp into table it_itens
          where vbeln = w_faturamento.
*        concatenate '0' i_kunnr+6(03) into wa_centro.
*        CALL FUNCTION 'ZCD_BAIXA_ESTOQUE'
*          EXPORTING
*            I_CLIENTE         = i_kunnr
*            I_ORDEM           = wa_ordem
*            I_DOCNUM          = wa_docnum
*            I_CENTRO          = wa_werks
*            I_DEPOSITO        = wa_lgort
**            I_CRITICA         =
*          IMPORTING
*            COD_RETORNO       = wa_cod_retorno
*            MSG_RETORNO       = wa_msg_retorno
*            MSG_SOLUCAO       = wa_msg_solucao
*          TABLES
*            T_ITENS           = it_itens.
      endif.
    else.
      cod_retorno = 'S001'.
      concatenate 'Ordem:' wa_ordem 'Fornec:' wa_fornecimento
                  'Fatura:' wa_faturamento 'DocNum:' wa_docnum
                                into msg_retorno separated by space.
      return.
    endif.
  endif.
    " Recuperando nº e série da nota de cobertura
  do 3 times.
    " Submit no programa que vai numerar a nota fiscal
    submit j_bnfecallrfc with so_docnm in r_docnum and return.
    wait up to 1 seconds.
    select single nfenum series from j_1bnfdoc
        into (wa_nfenum,wa_series)
      where docnum eq wa_docnum.
    if wa_nfenum is not initial and wa_series is not initial.
      e_nfenum = wa_nfenum.
      e_series = wa_series.
      wa_zcd_tb_notas-nfenum = wa_nfenum.
      wa_zcd_tb_notas-series = wa_series.
      modify zcd_tb_notas from wa_zcd_tb_notas.
      commit work and wait.
      cod_retorno = 'S001'.
      concatenate 'Ordem:' wa_ordem 'Fornec:' wa_fornecimento
                  'Fatura:' wa_faturamento 'DocNum:' wa_docnum
                  'N Fiscal n°' wa_nfenum
                                into msg_retorno separated by space.
      exit.
    endif.
  enddo.
endfunction.


*&---------------------------------------------------------------------*
*&      Form  ZF_GRAVA_TEXTO_ZTRA
*&---------------------------------------------------------------------*
* Grava os dados adicionais da tela 0800 no texto ZTRA da remessa,
* antes do faturamento e da numeração da nota.
*----------------------------------------------------------------------*
form zf_grava_texto_ztra using p_vbeln_vl type vbeln_vl
                               p_dados_adc type string.
  constants: cl_tdid_ztra  type thead-tdid value 'ZTRA',
             cl_tdobj_vbbk type thead-tdobject value 'VBBK',
             cl_tdformat   type tline-tdformat value '*',
             cl_tam_linha  type i value 132.

  data: vl_vbeln_rem type likp-vbeln,
        vl_tdname    type thead-tdname,
        vl_spras     type thead-tdspras,
        vl_texto     type string,
        vl_linha     type string,
        vl_offset    type i,
        vl_resto     type i,
        vl_cr TYPE c LENGTH 1,
        wal_head     type thead,
        wal_line     type tline,
        itl_lines    type standard table of tline,
        itl_quebras  type standard table of string.

  clear: vl_vbeln_rem, vl_tdname, vl_spras, vl_texto, vl_linha,
         vl_offset, vl_resto, wal_head, wal_line, itl_lines, itl_quebras.

  vl_vbeln_rem = p_vbeln_vl.
  call function 'CONVERSION_EXIT_ALPHA_INPUT'
    exporting
      input  = vl_vbeln_rem
    importing
      output = vl_vbeln_rem.

  vl_tdname = vl_vbeln_rem.
  vl_spras  = 'P'.
  vl_texto  = p_dados_adc.

  replace all occurrences of cl_abap_char_utilities=>cr_lf
    in vl_texto with cl_abap_char_utilities=>newline.
  vl_cr = cl_abap_char_utilities=>cr_lf(1).
  replace all occurrences of vl_cr
    in vl_texto with cl_abap_char_utilities=>newline.

  split vl_texto at cl_abap_char_utilities=>newline into table itl_quebras.

  loop at itl_quebras into vl_linha.
    if vl_linha is initial.
      clear wal_line.
      wal_line-tdformat = cl_tdformat.
      append wal_line to itl_lines.
      continue.
    endif.
    vl_offset = 0.
    while vl_offset < strlen( vl_linha ).
      vl_resto = strlen( vl_linha ) - vl_offset.
      if vl_resto > cl_tam_linha.
        vl_resto = cl_tam_linha.
      endif.
      clear wal_line.
      wal_line-tdformat = cl_tdformat.
      wal_line-tdline   = vl_linha+vl_offset(vl_resto).
      append wal_line to itl_lines.
      vl_offset = vl_offset + vl_resto.
    endwhile.
  endloop.
  if itl_lines is initial.
    return.
  endif.
  wal_head-tdobject = cl_tdobj_vbbk.
  wal_head-tdid     = cl_tdid_ztra.
  wal_head-tdspras  = vl_spras.
  wal_head-tdname   = vl_tdname.
  call function 'SAVE_TEXT'
    exporting
      client          = sy-mandt
      header          = wal_head
      savemode_direct = 'X'
    tables
      lines           = itl_lines
    exceptions
      id              = 1
      language        = 2
      name            = 3
      object          = 4
      others          = 5.
  if sy-subrc = 0.
    call function 'COMMIT_TEXT'
      exporting
        object   = cl_tdobj_vbbk
        name     = vl_tdname
        id       = cl_tdid_ztra
        language = vl_spras.
  endif.
endform.


*&---------------------------------------------------------------------*
*&      Form  ZF_MONTA_MOV_561
*&---------------------------------------------------------------------*
* Monta em memória a estrutura de um movimento 561 (entrada inicial de
* estoque) para o item recebido. NÃO faz CALL FUNCTION remoto (nada de
* BAPI_GOODSMVT_CREATE) e NÃO posta nem ativa nada no SAP — o objetivo
* é apenas preparar cabeçalho (BAPI2017_GM_HEAD_01), código de operação
* (BAPI2017_GM_CODE = '05') e item (BAPI2017_GM_ITEM_CREATE com
* MOVE_TYPE = '561') para consumo posterior por outra rotina.
*----------------------------------------------------------------------*
form zf_monta_mov_561 using p_matnr type matnr
                            p_werks type werks_d
                            p_lgort type lgort_d
                            p_menge type kwmeng
                            p_meins type vrkme.

  data: ls_gm_head_01 type bapi2017_gm_head_01,
        ls_gm_code    type bapi2017_gm_code,
        ls_gm_item    type bapi2017_gm_item_create,
        lt_gm_item    type standard table of bapi2017_gm_item_create.

  clear: ls_gm_head_01, ls_gm_code, ls_gm_item, lt_gm_item.

  ls_gm_head_01-pstng_date = sy-datum.
  ls_gm_head_01-doc_date   = sy-datum.
  ls_gm_head_01-pr_uname   = sy-uname.

  ls_gm_code-gm_code = '05'.

  ls_gm_item-material   = p_matnr.
  ls_gm_item-plant      = p_werks.
  ls_gm_item-stge_loc   = p_lgort.
  ls_gm_item-move_type  = '561'.
  ls_gm_item-entry_qnt  = p_menge.
  ls_gm_item-entry_uom  = p_meins.
  append ls_gm_item to lt_gm_item.

endform.
