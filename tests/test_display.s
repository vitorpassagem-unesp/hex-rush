/* ============================================================================
 * tests/test_display.s - Teste isolado do modulo display.s
 *
 * Arquivos do projeto no Monitor Program (criar o projeto na raiz do repo,
 * para o .include "constants.s" achar o arquivo):
 *   tests/test_display.s + display.s + utils.s
 * Este arquivo precisa ser o PRIMEIRO da lista, para o tratador ficar em 0x20.
 *
 * O que deve aparecer, em ordem:
 *   1. "    PLAY"  por 2 s                       (show_play)
 *   2. "GO  0507"  por 2 s                       (show_game_over + to_bcd)
 *   3. "GO  0000"  por 2 s                       (caso do zero)
 *   4. teste original do Gustavo, para sempre:
 *      - HEX0 mostra SW[17:14] continuamente     (set_hex_digit)
 *      - um alvo anda de HEX7 ate HEX1, um display por segundo, e volta em
 *        HEX7 com o proximo valor (0, 1, ..., F, 0, ...)
 *
 * Se TODOS os LEDR acenderem, houve uma excecao (ver TRATADOR_EXCECAO):
 * pause e olhe o registrador ea, que aponta para a instrucao seguinte a
 * que falhou.
 *
 * O timer aqui e lido por polling so para isolar o display; no jogo ele usa
 * interrupcao.
 * ============================================================================ */

.include "constants.s"                  /* traz as constantes do projeto */

.text                                   /* monta na secao de codigo */

/* ----------------------------------------------------------------------------
 * Tratador de excecao so para testes.
 * O Nios II desvia para 0x20 em qualquer excecao. Sem nada aqui, o desvio
 * caia no meio do _start e o teste reiniciava sozinho (foi o que escondeu o
 * divu sem hardware). Agora uma excecao acende todos os LEDR e para tudo.
 * So usa et e r8, para que ea, estatus e os argumentos (r4-r7) continuem
 * mostrando onde e com que valores a excecao aconteceu.
 * ---------------------------------------------------------------------------- */
.org 0x20                               /* posiciona o tratador em 0x20 */
TRATADOR_EXCECAO:
    movia et, LEDR_BASE             /* et = endereco dos LEDR */
    movia r8, 0x3FFFF               /* r8 = 18 bits 1 (LEDR[17:0]) */
    stwio r8, 0(et)                 /* acende todos os LEDR */
.Ltrava_excecao:
    br    .Ltrava_excecao           /* fica parado aqui para sempre */

.global _start                          /* exporta o ponto de entrada */
_start:
    /* Pilha e displays limpos */
    movia sp, STACK_TOP             /* sp = topo da pilha */
    call  clear_hex                 /* apaga os 8 displays */

    /* Timer em modo continuo, sem interrupcao, 1 s por periodo */
    movia r8, TIMER_BASE            /* r8 = endereco do timer */
    movi  r9, TIMER_STOP            /* r9 = comando STOP */
    stwio r9, TIMER_CTRL_REG(r8)    /* para o timer */
    stwio r0, TIMER_STATUS_REG(r8)  /* limpa o bit TO */
    movia r10, PERIODO_INICIAL      /* r10 = 50.000.000 ciclos (1 s) */
    andi  r9, r10, 0xFFFF           /* r9 = 16 bits de baixo do periodo */
    stwio r9, TIMER_PERIODL_REG(r8) /* grava a metade baixa */
    srli  r9, r10, 16               /* r9 = 16 bits de cima do periodo */
    stwio r9, TIMER_PERIODH_REG(r8) /* grava a metade alta */
    movi  r9, TIMER_CONT | TIMER_START /* r9 = CONT | START (sem ITO) */
    stwio r9, TIMER_CTRL_REG(r8)    /* comeca a contar */

    /* 1. Tela PLAY por 2 s */
    call  show_play                 /* mostra "    PLAY" */
    movi  r4, 2                     /* r4 = 2 ticks */
    call  espera_ticks              /* espera 2 s */

    /* 2. Tela GO com numero de 3 digitos: testa os zeros a esquerda */
    movi  r4, 507                   /* r4 = 507 pontos */
    call  show_game_over            /* mostra "GO  0507" */
    movi  r4, 2                     /* r4 = 2 ticks */
    call  espera_ticks              /* espera 2 s */

    /* 3. Tela GO com zero: to_bcd precisa gerar pelo menos um digito */
    mov   r4, r0                    /* r4 = 0 pontos */
    call  show_game_over            /* mostra "GO  0000" */
    movi  r4, 2                     /* r4 = 2 ticks */
    call  espera_ticks              /* espera 2 s */

    /* 4. Teste original: prepara o alvo andando */
    call  clear_hex                 /* apaga os 8 displays */
    movi  r16, 0x0C                 /* r16 = alvo de teste, comeca em C */
    movi  r17, POS_INICIAL          /* r17 = posicao do alvo (HEX7) */
    mov   r4, r17                   /* r4 = display do alvo */
    mov   r5, r16                   /* r5 = valor do alvo */
    call  set_hex_digit             /* desenha o alvo em HEX7 */

.Lloop:
    /* HEX0 mostra SW[17:14] a cada volta */
    movia r8, SW_BASE               /* r8 = endereco das chaves */
    ldwio r9, 0(r8)                 /* r9 = SW[17:0] */
    srli  r9, r9, 14                /* traz SW[17:14] para os bits 3:0 */
    andi  r5, r9, 0x0F              /* r5 = SW[17:14] (valor do jogador) */
    mov   r4, r0                    /* r4 = display 0 (HEX0) */
    call  set_hex_digit             /* mostra o valor em HEX0 */

    /* Espera o timeout do timer sem travar o laco */
    movia r8, TIMER_BASE            /* r8 = endereco do timer */
    ldwio r9, TIMER_STATUS_REG(r8)  /* r9 = status do timer */
    andi  r9, r9, 0x01              /* r9 = bit TO */
    beq   r9, r0, .Lloop            /* se nao estourou, volta ao laco */
    stwio r0, TIMER_STATUS_REG(r8)  /* limpa o bit TO */

    /* Apaga o alvo da posicao atual */
    mov   r4, r17                   /* r4 = display atual do alvo */
    movi  r5, HEX_APAGA             /* r5 = codigo de apagar */
    call  set_hex_digit             /* apaga o display */

    /* Anda uma posicao; se passou de HEX1, recomeca com o proximo valor */
    subi  r17, r17, 1               /* posicao - 1 (anda para a direita) */
    movi  r8, POS_FINAL             /* r8 = 1 (HEX1) */
    bge   r17, r8, .Ldesenha        /* se ainda esta em HEX1 ou antes, desenha */
    movi  r17, POS_INICIAL          /* senao, volta para HEX7 */
    addi  r16, r16, 1               /* proximo valor de alvo */
    andi  r16, r16, 0x0F            /* mantem entre 0 e F */

.Ldesenha:
    /* Desenha o alvo na posicao nova */
    mov   r4, r17                   /* r4 = display do alvo */
    mov   r5, r16                   /* r5 = valor do alvo */
    call  set_hex_digit             /* desenha o alvo */
    br    .Lloop                    /* volta ao laco */

/* ----------------------------------------------------------------------------
 * espera_ticks (so do teste): espera r4 timeouts do timer por polling.
 * ---------------------------------------------------------------------------- */
espera_ticks:
    movia r8, TIMER_BASE            /* r8 = endereco do timer */
.Lespera:
    /* Espera um timeout e o descarta */
    ldwio r9, TIMER_STATUS_REG(r8)  /* r9 = status do timer */
    andi  r9, r9, 0x01              /* r9 = bit TO */
    beq   r9, r0, .Lespera          /* se nao estourou, continua esperando */
    stwio r0, TIMER_STATUS_REG(r8)  /* limpa o bit TO */

    /* Conta os ticks que faltam */
    subi  r4, r4, 1                 /* um tick a menos */
    bne   r4, r0, .Lespera          /* se ainda falta, espera de novo */
    ret                             /* retorna */
