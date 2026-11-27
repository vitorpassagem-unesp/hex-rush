/* ============================================================================
 * tests/test_timer_keys.s - Teste de interrupts.s, timer.s e leds.s
 *
 * Arquivos do projeto no Monitor Program (projeto na raiz do repo):
 *   tests/test_timer_keys.s + interrupts.s + timer.s + leds.s
 *   + display.s + utils.s
 * A RTI fica na secao .exceptions, que o Monitor Program coloca em 0x20
 * sozinho; por isso este teste NAO tem o tratador .org 0x20 dos outros.
 *
 * O que deve acontecer:
 *   - HEX mostra "GO  dddd" com um contador que sobe 1 por segundo
 *     (cada tick do timer, via interrupcao)               -> timer + RTI
 *   - LEDG acende 0, 1, 2, 3 LEDs em ciclo, um passo por tick -> set_ledg_lives
 *   - LEDR mostra SW[17:14] em unario, o tempo todo       -> set_ledr_unary
 *   - KEY1: acelera 6,25% (o contador passa a subir mais rapido a cada
 *     aperto; ~10 apertos = ~2x mais rapido)              -> next_period
 *   - KEY2: pausa o contador; KEY2 de novo continua de onde parou, sem
 *     pular numero                                       -> timer_stop/resume
 *   - KEY1 durante a pausa: acelera e sai da pausa
 *   - todos os LEDR acesos de repente = excecao (olhar ea)
 * ============================================================================ */

.include "constants.s"                  /* traz as constantes do projeto */

/* Flags lidos pela RTI. No jogo eles ficam em main.s; aqui o teste faz o
 * papel do main. */
.global FLAG_TICK                       /* exporta FLAG_TICK para a RTI */
.global FLAG_KEY1                       /* exporta FLAG_KEY1 para a RTI */
.global FLAG_KEY2                       /* exporta FLAG_KEY2 para a RTI */

.data                                   /* passa a montar na secao de dados */
.align 2                                /* alinha em 4 bytes (words) */
FLAG_TICK:  .word 0                     /* 1 = chegou um tick do timer */
FLAG_KEY1:  .word 0                     /* 1 = KEY1 foi apertado */
FLAG_KEY2:  .word 0                     /* 1 = KEY2 foi apertado */

/* Registradores do teste: r16 = contador de ticks, r17 = periodo atual,
 * r18 = 1 se pausado */
.text                                   /* volta a montar na secao de codigo */
.global _start                          /* exporta o ponto de entrada */
_start:
    /* Pilha, displays e LEDs limpos */
    movia sp, STACK_TOP             /* sp = topo da pilha */
    call  clear_hex                 /* apaga os 8 displays */
    call  clear_leds                /* apaga LEDR e LEDG */

    /* Estado inicial do teste */
    mov   r16, r0                   /* r16 = contador = 0 */
    movia r17, PERIODO_INICIAL      /* r17 = periodo = 1 s */
    mov   r18, r0                   /* r18 = nao pausado */
    mov   r4, r16                   /* r4 = contador */
    call  show_game_over            /* mostra "GO  0000" */

    /* Liga o timer e por ultimo as interrupcoes (tudo pronto antes da 1a IRQ) */
    mov   r4, r17                   /* r4 = periodo */
    call  timer_start               /* timer contando com interrupcao */
    call  interrupts_init           /* habilita KEY1/KEY2, IRQs e PIE */

.Lloop:
    /* LEDR acompanha as chaves o tempo todo */
    movia r8, SW_BASE               /* r8 = endereco das chaves */
    ldwio r4, 0(r8)                 /* r4 = SW[17:0] */
    srli  r4, r4, 14                /* traz SW[17:14] para os bits 3:0 */
    andi  r4, r4, 0x0F              /* r4 = SW[17:14] */
    call  set_ledr_unary            /* acende r4 LEDR */

    /* KEY1 (prioridade maxima): acelera e reinicia o timer */
    movia r8, FLAG_KEY1             /* r8 = endereco de FLAG_KEY1 */
    ldw   r9, 0(r8)                 /* r9 = FLAG_KEY1 */
    beq   r9, r0, .Lkey2            /* se nao apertou, testa KEY2 */
    stw   r0, 0(r8)                 /* FLAG_KEY1 = 0 (consome o evento) */
    mov   r4, r17                   /* r4 = periodo atual */
    call  next_period               /* r2 = periodo - periodo/16 */
    mov   r17, r2                   /* r17 = periodo novo */
    mov   r4, r17                   /* r4 = periodo novo */
    call  timer_start               /* reinicia o timer com ele */
    mov   r18, r0                   /* timer_start tambem tira da pausa */
    br    .Lloop                    /* volta ao laco */

.Lkey2:
    /* KEY2: alterna entre pausado e rodando */
    movia r8, FLAG_KEY2             /* r8 = endereco de FLAG_KEY2 */
    ldw   r9, 0(r8)                 /* r9 = FLAG_KEY2 */
    beq   r9, r0, .Ltick            /* se nao apertou, testa o tick */
    stw   r0, 0(r8)                 /* FLAG_KEY2 = 0 (consome o evento) */
    bne   r18, r0, .Ldespausa       /* se ja estava pausado, vai despausar */
    call  timer_stop                /* congela o timer */
    movi  r18, 1                    /* r18 = pausado */
    br    .Lloop                    /* volta ao laco */
.Ldespausa:
    call  timer_resume              /* timer continua de onde parou */
    mov   r18, r0                   /* r18 = nao pausado */
    br    .Lloop                    /* volta ao laco */

.Ltick:
    /* Tick: so conta fora da pausa (um tick pendente espera o despausar) */
    bne   r18, r0, .Lloop           /* se pausado, ignora o flag por enquanto */
    movia r8, FLAG_TICK             /* r8 = endereco de FLAG_TICK */
    ldw   r9, 0(r8)                 /* r9 = FLAG_TICK */
    beq   r9, r0, .Lloop            /* se nao chegou tick, volta ao laco */
    stw   r0, 0(r8)                 /* FLAG_TICK = 0 (consome o evento) */

    /* Avanca o contador e mostra nos displays e nos LEDG */
    addi  r16, r16, 1               /* contador + 1 */
    mov   r4, r16                   /* r4 = contador */
    call  show_game_over            /* mostra "GO  dddd" */
    andi  r4, r16, 0x03             /* r4 = contador mod 4 */
    call  set_ledg_lives            /* acende 0 a 3 LEDG */
    br    .Lloop                    /* volta ao laco */
