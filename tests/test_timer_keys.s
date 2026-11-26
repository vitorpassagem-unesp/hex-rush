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

.include "constants.s"

/* Flags lidos pela RTI. No jogo eles ficam em main.s; aqui o teste faz o
 * papel do main. */
.global FLAG_TICK
.global FLAG_KEY1
.global FLAG_KEY2

.data
.align 2
FLAG_TICK:  .word 0
FLAG_KEY1:  .word 0
FLAG_KEY2:  .word 0

/* r16 = contador de ticks, r17 = periodo atual, r18 = 1 se pausado */
.text
.global _start
_start:
    movia sp, STACK_TOP

    call  clear_hex
    call  clear_leds

    mov   r16, r0
    movia r17, PERIODO_INICIAL
    mov   r18, r0

    mov   r4, r16
    call  show_game_over

    mov   r4, r17
    call  timer_start
    call  interrupts_init           /* por ultimo: tudo pronto antes da 1a IRQ */

.Lloop:
    /* LEDR acompanha as chaves o tempo todo */
    movia r8, SW_BASE
    ldwio r4, 0(r8)
    srli  r4, r4, 14
    andi  r4, r4, 0x0F
    call  set_ledr_unary

    /* Prioridade KEY1 > KEY2 > tick, igual ao jogo */
    movia r8, FLAG_KEY1
    ldw   r9, 0(r8)
    beq   r9, r0, .Lkey2
    stw   r0, 0(r8)                 /* consome o evento */

    mov   r4, r17
    call  next_period
    mov   r17, r2
    mov   r4, r17
    call  timer_start               /* aplica o periodo novo */
    mov   r18, r0                   /* timer_start tambem tira da pausa */
    br    .Lloop

.Lkey2:
    movia r8, FLAG_KEY2
    ldw   r9, 0(r8)
    beq   r9, r0, .Ltick
    stw   r0, 0(r8)

    bne   r18, r0, .Ldespausa
    call  timer_stop
    movi  r18, 1
    br    .Lloop
.Ldespausa:
    call  timer_resume
    mov   r18, r0
    br    .Lloop

.Ltick:
    /* Pausado: o tick que talvez ja tenha chegado espera o despausar
     * (decisao do grupo), entao nem olha o flag. */
    bne   r18, r0, .Lloop

    movia r8, FLAG_TICK
    ldw   r9, 0(r8)
    beq   r9, r0, .Lloop
    stw   r0, 0(r8)

    addi  r16, r16, 1
    mov   r4, r16
    call  show_game_over
    andi  r4, r16, 0x03             /* 0..3 LEDs verdes, em ciclo */
    call  set_ledg_lives
    br    .Lloop
