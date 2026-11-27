/* ============================================================================
 * main.s - Programa principal do HexRush: inicializacao e maquina de estados
 *
 * Ordem dos arquivos no projeto do Monitor Program (interrupts.s PRIMEIRO,
 * por causa do .org 0x20 da RTI):
 *   interrupts.s, main.s, display.s, leds.s, timer.s, uart.s, targets.s,
 *   utils.s
 *
 * Estados (docs/especificacao.md, secao 2). Cada estado e um trecho com
 * rotulo proprio; mudar de estado e desviar para ele:
 *   ESTADO_AGUARDANDO  -> so ao ligar: "PLAY", espera KEY1
 *   ESTADO_INICIO      -> zera a partida e liga o timer (passagem)
 *   ESTADO_JOGANDO     -> HEX0 = SW; trata KEY1 > KEY2 > tick
 *   ESTADO_PAUSADO     -> tudo congelado; KEY2 volta, KEY1 reinicia
 *   ESTADO_FIM_RODADA  -> compara, pontua/tira vida, UART (passagem)
 *   ESTADO_FIM_JOGO    -> "GO  dddd", linha final; KEY1 reinicia
 *
 * Mapa de registradores (preservados por todas as sub-rotinas):
 *   r16 = pontos      r17 = vidas      r18 = rodada
 *   r19 = pos (display do alvo, 7..1)  r20 = indice na lista (0..99)
 *   r21 = periodo do timer (ciclos)
 *   r22, r23 = livres para o laco principal
 * Flags (na memoria, levantados pela RTI): FLAG_TICK, FLAG_KEY1, FLAG_KEY2.
 * ============================================================================ */

.include "constants.s"                  /* traz as constantes do projeto */

/* Flags visiveis para a RTI (interrupts.s) */
.global FLAG_TICK                       /* exporta FLAG_TICK */
.global FLAG_KEY1                       /* exporta FLAG_KEY1 */
.global FLAG_KEY2                       /* exporta FLAG_KEY2 */

.data                                   /* passa a montar na secao de dados */
.align 2                                /* alinha em 4 bytes (words) */
FLAG_TICK:  .word 0                     /* 1 = chegou um tick do timer */
FLAG_KEY1:  .word 0                     /* 1 = KEY1 foi apertado */
FLAG_KEY2:  .word 0                     /* 1 = KEY2 foi apertado */

.text                                   /* volta a montar na secao de codigo */
.global _start                          /* exporta o ponto de entrada */
_start:
    movia sp, STACK_TOP             /* sp = topo da pilha */

/* ============================================================================
 * AGUARDANDO: so ao ligar a placa. "PLAY" nos displays, LEDs apagados,
 * timer parado e mensagem na UART. Espera KEY1; KEY2 e ignorado.
 * ============================================================================ */
ESTADO_AGUARDANDO:
    /* Timer parado: o Monitor Program nao reinicia os perifericos ao
     * carregar, entao ele pode estar rodando de um programa anterior */
    call  timer_stop                /* para o timer */

    /* Telas do estado */
    call  show_play                 /* "    PLAY" nos displays */
    call  clear_leds                /* apaga LEDR e LEDG */
    call  uart_print_wait           /* "Pressione KEY1 para iniciar" */

    /* Liga as interrupcoes (botoes passam a levantar flags) */
    call  interrupts_init           /* KEY1/KEY2, IRQs e PIE */

.Laguarda_laco:
    /* KEY1: comeca a partida */
    movia r8, FLAG_KEY1             /* r8 = endereco de FLAG_KEY1 */
    ldw   r9, 0(r8)                 /* r9 = FLAG_KEY1 */
    bne   r9, r0, ESTADO_INICIO     /* se apertou, vai para o INICIO */

    /* KEY2: ignorado neste estado (descarta o aperto) */
    movia r8, FLAG_KEY2             /* r8 = endereco de FLAG_KEY2 */
    stw   r0, 0(r8)                 /* FLAG_KEY2 = 0 */
    br    .Laguarda_laco            /* continua esperando */

/* ============================================================================
 * INICIO: zera a partida, desenha o primeiro alvo e liga o timer.
 * Estado de passagem: termina caindo no JOGANDO.
 * ============================================================================ */
ESTADO_INICIO:
    /* Variaveis da partida */
    mov   r16, r0                   /* pontos = 0 */
    movi  r17, VIDAS_INICIAIS       /* vidas = 3 */
    movi  r18, 1                    /* rodada = 1 */
    movi  r19, POS_INICIAL          /* pos = 7 (HEX7) */
    mov   r20, r0                   /* indice = 0 (primeiro alvo da lista) */
    movia r21, PERIODO_INICIAL      /* periodo = 1 s */

    /* Limpa os flags: um aperto antigo nao pode vazar para a partida nova */
    movia r8, FLAG_TICK             /* r8 = endereco de FLAG_TICK */
    stw   r0, 0(r8)                 /* FLAG_TICK = 0 */
    movia r8, FLAG_KEY1             /* r8 = endereco de FLAG_KEY1 */
    stw   r0, 0(r8)                 /* FLAG_KEY1 = 0 */
    movia r8, FLAG_KEY2             /* r8 = endereco de FLAG_KEY2 */
    stw   r0, 0(r8)                 /* FLAG_KEY2 = 0 */

    /* Primeiro alvo em HEX7 */
    call  clear_hex                 /* apaga os 8 displays */
    mov   r4, r20                   /* r4 = indice do alvo */
    call  get_target                /* r2 = alvo */
    mov   r4, r19                   /* r4 = display do alvo (HEX7) */
    mov   r5, r2                    /* r5 = alvo */
    call  set_hex_digit             /* desenha o alvo */

    /* LEDs: vidas e proximo alvo */
    mov   r4, r17                   /* r4 = vidas */
    call  set_ledg_lives            /* acende 3 LEDG */
    addi  r4, r20, 1                /* r4 = indice do proximo alvo */
    call  get_target                /* r2 = proximo alvo */
    mov   r4, r2                    /* r4 = proximo alvo */
    call  set_ledr_unary            /* mostra o proximo alvo em unario */

    /* Timer com o periodo inicial */
    mov   r4, r21                   /* r4 = periodo */
    call  timer_start               /* comeca a contar os passos */
    /* (cai direto no JOGANDO) */

/* ============================================================================
 * JOGANDO: a cada volta mostra SW em HEX0 e trata os eventos na ordem
 * KEY1 > KEY2 > tick (reiniciar vence qualquer outro evento).
 * ============================================================================ */
ESTADO_JOGANDO:
    /* HEX0 mostra o valor atual das chaves */
    call  ler_resposta              /* r2 = SW[17:14] */
    mov   r4, r0                    /* r4 = display 0 (HEX0) */
    mov   r5, r2                    /* r5 = valor das chaves */
    call  set_hex_digit             /* mostra em HEX0 */

    /* KEY1: reinicia a partida */
    movia r8, FLAG_KEY1             /* r8 = endereco de FLAG_KEY1 */
    ldw   r9, 0(r8)                 /* r9 = FLAG_KEY1 */
    bne   r9, r0, ESTADO_INICIO     /* se apertou, reinicia (INICIO limpa o flag) */

    /* KEY2: pausa */
    movia r8, FLAG_KEY2             /* r8 = endereco de FLAG_KEY2 */
    ldw   r9, 0(r8)                 /* r9 = FLAG_KEY2 */
    beq   r9, r0, .Ljogando_tick    /* se nao apertou, testa o tick */
    stw   r0, 0(r8)                 /* FLAG_KEY2 = 0 (consome o evento) */
    br    ESTADO_PAUSADO            /* vai para a pausa */

.Ljogando_tick:
    /* Tick: o alvo anda um display (ou chega em HEX0) */
    movia r8, FLAG_TICK             /* r8 = endereco de FLAG_TICK */
    ldw   r9, 0(r8)                 /* r9 = FLAG_TICK */
    beq   r9, r0, ESTADO_JOGANDO    /* se nao chegou tick, volta ao laco */
    stw   r0, 0(r8)                 /* FLAG_TICK = 0 (consome o evento) */
    movi  r8, POS_FINAL             /* r8 = 1 (HEX1) */
    beq   r19, r8, ESTADO_FIM_RODADA /* se estava em HEX1, chegou em HEX0 */

    /* Apaga o alvo da posicao atual */
    mov   r4, r19                   /* r4 = display atual do alvo */
    movi  r5, HEX_APAGA             /* r5 = codigo de apagar */
    call  set_hex_digit             /* apaga o display */

    /* Desenha o alvo uma posicao a direita */
    subi  r19, r19, 1               /* pos = pos - 1 */
    mov   r4, r20                   /* r4 = indice do alvo */
    call  get_target                /* r2 = alvo */
    mov   r4, r19                   /* r4 = display novo */
    mov   r5, r2                    /* r5 = alvo */
    call  set_hex_digit             /* desenha o alvo */
    br    ESTADO_JOGANDO            /* volta ao laco */

/* ============================================================================
 * PAUSADO: timer congelado, nada e atualizado (nem HEX0). KEY2 volta ao
 * jogo de onde parou; KEY1 reinicia a partida. Um tick que ja tenha
 * chegado fica no flag e e tratado ao voltar (decisao do grupo).
 * ============================================================================ */
ESTADO_PAUSADO:
    call  timer_stop                /* congela o contador do timer */

.Lpausado_laco:
    /* KEY1: reinicia a partida */
    movia r8, FLAG_KEY1             /* r8 = endereco de FLAG_KEY1 */
    ldw   r9, 0(r8)                 /* r9 = FLAG_KEY1 */
    bne   r9, r0, ESTADO_INICIO     /* se apertou, reinicia (INICIO religa o timer) */

    /* KEY2: despausa */
    movia r8, FLAG_KEY2             /* r8 = endereco de FLAG_KEY2 */
    ldw   r9, 0(r8)                 /* r9 = FLAG_KEY2 */
    beq   r9, r0, .Lpausado_laco    /* se nao apertou, continua pausado */
    stw   r0, 0(r8)                 /* FLAG_KEY2 = 0 (consome o evento) */
    call  timer_resume              /* timer continua de onde parou */
    br    ESTADO_JOGANDO            /* volta ao jogo */

/* ============================================================================
 * FIM_RODADA: o alvo chegou em HEX0. Compara com as chaves, pontua ou tira
 * vida, imprime a linha da rodada e prepara a proxima (ou termina o jogo).
 * Estado de passagem.
 * r22 = resposta do jogador, r23 = alvo da rodada.
 * ============================================================================ */
ESTADO_FIM_RODADA:
    /* 1. Tira o alvo de HEX1 */
    mov   r4, r19                   /* r4 = display do alvo (HEX1) */
    movi  r5, HEX_APAGA             /* r5 = codigo de apagar */
    call  set_hex_digit             /* apaga HEX1 */

    /* 2. Le a resposta e o alvo */
    call  ler_resposta              /* r2 = SW[17:14] */
    mov   r22, r2                   /* r22 = resposta */
    mov   r4, r20                   /* r4 = indice do alvo */
    call  get_target                /* r2 = alvo */
    mov   r23, r2                   /* r23 = alvo */

    /* 3. Compara */
    bne   r22, r23, .Lrodada_erro   /* se diferentes, e erro */

    /* Acerto: +1 ponto e acelera 6,25% */
    addi  r16, r16, 1               /* pontos + 1 */
    mov   r4, r21                   /* r4 = periodo atual */
    call  next_period               /* r2 = periodo - periodo/16 */
    mov   r21, r2                   /* r21 = periodo novo */
    mov   r4, r21                   /* r4 = periodo novo */
    call  timer_start               /* reinicia o timer com ele */
    mov   r7, r16                   /* r7 = pontos (vai para a UART) */
    br    .Lrodada_uart             /* pula o caso de erro */

.Lrodada_erro:
    /* Erro: -1 vida */
    subi  r17, r17, 1               /* vidas - 1 */
    mov   r4, r17                   /* r4 = vidas */
    call  set_ledg_lives            /* atualiza os LEDG */
    mov   r7, r17                   /* r7 = vidas (vai para a UART) */

.Lrodada_uart:
    /* 4. Linha da rodada na UART */
    mov   r4, r18                   /* r4 = rodada */
    mov   r5, r23                   /* r5 = alvo */
    mov   r6, r22                   /* r6 = resposta */
    call  uart_print_round          /* "Rodada N | Alvo: ... " */

    /* 5. Proxima rodada (ou fim de jogo, se acabaram as vidas) */
    addi  r18, r18, 1               /* rodada + 1 */
    beq   r17, r0, ESTADO_FIM_JOGO  /* se vidas = 0, fim de jogo */

    /* 6. Proximo alvo: indice + 1, circular em 100 */
    addi  r20, r20, 1               /* indice + 1 */
    movi  r8, NUM_ALVOS             /* r8 = 100 */
    bne   r20, r8, .Lrodada_alvo    /* se nao chegou a 100, segue */
    mov   r20, r0                   /* senao, volta ao primeiro alvo */

.Lrodada_alvo:
    /* Novo alvo em HEX7 */
    movi  r19, POS_INICIAL          /* pos = 7 (HEX7) */
    mov   r4, r20                   /* r4 = indice do alvo */
    call  get_target                /* r2 = alvo */
    mov   r4, r19                   /* r4 = display do alvo (HEX7) */
    mov   r5, r2                    /* r5 = alvo */
    call  set_hex_digit             /* desenha o alvo */

    /* LEDR com o proximo alvo */
    addi  r4, r20, 1                /* r4 = indice do proximo alvo */
    call  get_target                /* r2 = proximo alvo (get_target faz o mod 100) */
    mov   r4, r2                    /* r4 = proximo alvo */
    call  set_ledr_unary            /* mostra em unario */
    br    ESTADO_JOGANDO            /* volta ao jogo */

/* ============================================================================
 * FIM_JOGO: timer parado, "GO  dddd", LEDs apagados e linha final na UART.
 * KEY1 comeca uma partida nova direto; KEY2 e ignorado.
 * ============================================================================ */
ESTADO_FIM_JOGO:
    /* Para o jogo e mostra o placar */
    call  timer_stop                /* para o timer */
    mov   r4, r16                   /* r4 = pontos */
    call  show_game_over            /* "GO  dddd" */
    call  clear_leds                /* apaga LEDR e LEDG */

    /* Linha final: rodadas jogadas = rodada - 1 (ja foi incrementada) */
    mov   r4, r16                   /* r4 = pontos */
    subi  r5, r18, 1                /* r5 = rodadas jogadas */
    call  uart_print_end            /* "=== FIM DE JOGO === ..." */

.Lfim_laco:
    /* KEY1: partida nova */
    movia r8, FLAG_KEY1             /* r8 = endereco de FLAG_KEY1 */
    ldw   r9, 0(r8)                 /* r9 = FLAG_KEY1 */
    bne   r9, r0, ESTADO_INICIO     /* se apertou, vai para o INICIO */

    /* KEY2: ignorado neste estado (descarta o aperto) */
    movia r8, FLAG_KEY2             /* r8 = endereco de FLAG_KEY2 */
    stw   r0, 0(r8)                 /* FLAG_KEY2 = 0 */
    br    .Lfim_laco                /* continua esperando */

/* ----------------------------------------------------------------------------
 * ler_resposta (so do main): r2 = SW[17:14], o valor que o jogador montou.
 * Usada para HEX0 e para a comparacao, para as duas lerem do mesmo jeito.
 * ---------------------------------------------------------------------------- */
ler_resposta:
    movia r8, SW_BASE               /* r8 = endereco das chaves */
    ldwio r2, 0(r8)                 /* r2 = SW[17:0] */
    srli  r2, r2, 14                /* traz SW[17:14] para os bits 3:0 */
    andi  r2, r2, 0x0F              /* r2 = SW[17:14] */
    ret                             /* retorna com o valor em r2 */
