/* ============================================================================
 * visual_test.s - Teste visual isolado:
 *   - SW[17:14] exibido continuamente em HEX0
 *   - Alvo (0..F) surge em HEX7 e avanca um display por tick ate HEX1
 * ============================================================================ */

/* --- Enderecos base (DE2-115 Media Computer / Altera Monitor Program) --- */
.equ HEX3_HEX0_BASE,    0x10000020   /* HEX3 (31:24), HEX2 (23:16), HEX1 (15:8), HEX0 (7:0) */
.equ HEX7_HEX4_BASE,    0x10000030   /* HEX7 (31:24), HEX6 (23:16), HEX5 (15:8), HEX4 (7:0) */
.equ SW_BASE,           0x10000040   /* Chaves SW[17:0] */

/* --- Interval Timer (50 MHz) --- */
.equ TIMER_BASE,        0x10002000
.equ TIMER_STATUS_REG,  0x00         /* bit 0 = TO (timeout) */
.equ TIMER_CTRL_REG,    0x04         /* bit 1 = CONT, bit 2 = START, bit 3 = STOP */
.equ TIMER_PERIODL,     0x08
.equ TIMER_PERIODH,     0x0C

/* 500 ms @ 50 MHz = 25.000.000 ciclos (0x017D7840).
 * Altere para 0x02FAF080 (1 s) se quiser acompanhar com mais calma. */
.equ STEP_PERIOD,       0x017D7840

/* Tabela 7-segmentos (0..F) conforme Tabela 2 do enunciado */
.section .rodata
.align 2
HEX7SEG_TABLE:
    .byte 0x3F  /* 0: abcdef  */
    .byte 0x06  /* 1: bc      */
    .byte 0x5B  /* 2: abdeg   */
    .byte 0x4F  /* 3: abcdg   */
    .byte 0x66  /* 4: bcfg    */
    .byte 0x6D  /* 5: acdfg   */
    .byte 0x7D  /* 6: acdefg  */
    .byte 0x07  /* 7: abc     */
    .byte 0x7F  /* 8: abcdefg */
    .byte 0x6F  /* 9: abcdfg  */
    .byte 0x77  /* A: abcefg  */
    .byte 0x7C  /* b: cdefg   */
    .byte 0x39  /* C: adef    */
    .byte 0x5E  /* d: bcdeg   */
    .byte 0x79  /* E: abdefg  */
    .byte 0x71  /* F: aefg    */

.text
.global _start
_start:
    movia sp, 0x01000000

    /* Limpa todos os displays HEX7..HEX0 */
    movia r8, HEX7_HEX4_BASE
    stwio r0, 0(r8)
    movia r8, HEX3_HEX0_BASE
    stwio r0, 0(r8)

    /* Configura e inicia o timer em modo continuo */
    movia r8, TIMER_BASE
    movi  r9, 0x08                  /* STOP */
    stwio r9, TIMER_CTRL_REG(r8)
    stwio r0, TIMER_STATUS_REG(r8)

    movia r10, STEP_PERIOD
    andi  r9, r10, 0xFFFF
    stwio r9, TIMER_PERIODL(r8)
    srli  r9, r10, 16
    andi  r9, r9, 0xFFFF
    stwio r9, TIMER_PERIODH(r8)

    movi  r9, 0x06                  /* CONT | START */
    stwio r9, TIMER_CTRL_REG(r8)

    /* Estado inicial do teste visual:
     * r16 = alvo atual (0..15)
     * r17 = posicao do alvo (7 = HEX7 ate 1 = HEX1) */
    movi  r16, 0x0C                 /* comeca com 'C' */
    movi  r17, 7

    /* Desenha o alvo inicial em HEX7 */
    mov   r4, r17
    mov   r5, r16
    call  set_hex_digit

_main_loop:
    /* 1. Le SW[17:14] e exibe continuamente em HEX0 */
    movia r8, SW_BASE
    ldwio r9, 0(r8)
    srli  r9, r9, 14
    andi  r9, r9, 0x0F              /* valor atual do jogador (0..F) */

    movi  r4, 0                     /* HEX0 */
    mov   r5, r9
    call  set_hex_digit

    /* 2. Verifica se o timer estourou */
    movia r8, TIMER_BASE
    ldwio r9, TIMER_STATUS_REG(r8)
    andi  r9, r9, 0x01
    beq   r9, r0, _main_loop

    /* Limpa flag TO do timer */
    stwio r0, TIMER_STATUS_REG(r8)

    /* Apaga a posicao atual antes de avancar */
    mov   r4, r17
    movi  r5, 0xFF                  /* 0xFF = apagar display */
    call  set_hex_digit

    /* Avanca uma casa para a direita (HEX7 -> HEX6 -> ... -> HEX1) */
    subi  r17, r17, 1
    movi  r8, 1
    blt   r17, r8, _restart_target

    /* Desenha o alvo na nova posicao */
    mov   r4, r17
    mov   r5, r16
    call  set_hex_digit
    br    _main_loop

_restart_target:
    /* Ao passar de HEX1, reinicia em HEX7 com proximo alvo de teste */
    movi  r17, 7
    addi  r16, r16, 1
    andi  r16, r16, 0x0F

    mov   r4, r17
    mov   r5, r16
    call  set_hex_digit
    br    _main_loop

/* ----------------------------------------------------------------------------
 * set_hex_digit
 * Escreve um digito (0..15) no display r4 (0..7).
 * Se r5 == 0xFF, apaga o display (escreve 0x00 nos 7 segmentos).
 * Preserva os demais displays do mesmo registrador de 32 bits.
 * ---------------------------------------------------------------------------- */
set_hex_digit:
    subi  sp, sp, 12
    stw   ra, 8(sp)
    stw   r16, 4(sp)
    stw   r17, 0(sp)

    mov   r16, r4                   /* indice do display (0..7) */
    mov   r17, r5                   /* digito (0..15) ou 0xFF para apagar */

    movi  r8, 0xFF
    beq   r17, r8, _blank_pattern

    andi  r17, r17, 0x0F
    movia r8, HEX7SEG_TABLE
    add   r8, r8, r17
    ldb   r2, 0(r8)                 /* padrao 7-seg */
    br    _select_reg

_blank_pattern:
    movi  r2, 0x00

_select_reg:
    andi  r16, r16, 0x07
    movi  r8, 4
    blt   r16, r8, _hex3_0

    subi  r9, r16, 4                /* deslocamento dentro de HEX7_HEX4 */
    movia r10, HEX7_HEX4_BASE
    br    _write_byte

_hex3_0:
    mov   r9, r16                   /* deslocamento dentro de HEX3_HEX0 */
    movia r10, HEX3_HEX0_BASE

_write_byte:
    slli  r9, r9, 3                 /* bit shift = 8 * indice_no_word */
    movi  r11, 0xFF
    sll   r11, r11, r9
    nor   r11, r11, r11             /* mascara para zerar apenas o byte alvo */

    sll   r2, r2, r9
    ldwio r8, 0(r10)
    and   r8, r8, r11
    or    r8, r8, r2
    stwio r8, 0(r10)

    ldw   r17, 0(sp)
    ldw   r16, 4(sp)
    ldw   ra, 8(sp)
    addi  sp, sp, 12
    ret