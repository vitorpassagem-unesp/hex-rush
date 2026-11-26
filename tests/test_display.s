/* ============================================================================
 * tests/test_display.s - Teste isolado do modulo display.s
 *
 * Arquivos do projeto no Monitor Program (criar o projeto na raiz do repo,
 * para o .include "constants.s" achar o arquivo):
 *   tests/test_display.s + display.s + utils.s
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
 * Se travar no passo 2, a instrucao divu (usada em to_bcd) provavelmente nao
 * existe no processador da placa.
 *
 * O timer aqui e lido por polling so para isolar o display; no jogo ele usa
 * interrupcao.
 * ============================================================================ */

.include "constants.s"

.text
.global _start
_start:
    movia sp, STACK_TOP

    call  clear_hex

    /* Timer em modo continuo, sem interrupcao, 1 s por periodo */
    movia r8, TIMER_BASE
    movi  r9, TIMER_STOP
    stwio r9, TIMER_CTRL_REG(r8)
    stwio r0, TIMER_STATUS_REG(r8)
    movia r10, PERIODO_INICIAL
    andi  r9, r10, 0xFFFF
    stwio r9, TIMER_PERIODL_REG(r8)
    srli  r9, r10, 16
    stwio r9, TIMER_PERIODH_REG(r8)
    movi  r9, TIMER_CONT | TIMER_START
    stwio r9, TIMER_CTRL_REG(r8)

    /* 1. PLAY */
    call  show_play
    movi  r4, 2
    call  espera_ticks

    /* 2. GO com numero de 3 digitos: testa os zeros a esquerda */
    movi  r4, 507
    call  show_game_over
    movi  r4, 2
    call  espera_ticks

    /* 3. GO com zero: to_bcd precisa gerar pelo menos um digito */
    mov   r4, r0
    call  show_game_over
    movi  r4, 2
    call  espera_ticks

    /* 4. Teste original: alvo andando + HEX0 com as chaves */
    call  clear_hex
    movi  r16, 0x0C                 /* alvo de teste: comeca com C */
    movi  r17, POS_INICIAL          /* posicao do alvo */

    mov   r4, r17
    mov   r5, r16
    call  set_hex_digit

.Lloop:
    movia r8, SW_BASE
    ldwio r9, 0(r8)
    srli  r9, r9, 14
    andi  r5, r9, 0x0F              /* SW[17:14] */
    mov   r4, r0                    /* HEX0 */
    call  set_hex_digit

    movia r8, TIMER_BASE
    ldwio r9, TIMER_STATUS_REG(r8)
    andi  r9, r9, 0x01              /* TO */
    beq   r9, r0, .Lloop
    stwio r0, TIMER_STATUS_REG(r8)

    mov   r4, r17                   /* apaga a posicao atual */
    movi  r5, HEX_APAGA
    call  set_hex_digit

    subi  r17, r17, 1
    movi  r8, POS_FINAL
    bge   r17, r8, .Ldesenha

    movi  r17, POS_INICIAL          /* passou de HEX1: proximo alvo */
    addi  r16, r16, 1
    andi  r16, r16, 0x0F

.Ldesenha:
    mov   r4, r17
    mov   r5, r16
    call  set_hex_digit
    br    .Lloop

/* ----------------------------------------------------------------------------
 * espera_ticks (so do teste): espera r4 timeouts do timer por polling.
 * ---------------------------------------------------------------------------- */
espera_ticks:
    movia r8, TIMER_BASE
.Lespera:
    ldwio r9, TIMER_STATUS_REG(r8)
    andi  r9, r9, 0x01
    beq   r9, r0, .Lespera
    stwio r0, TIMER_STATUS_REG(r8)
    subi  r4, r4, 1
    bne   r4, r0, .Lespera
    ret
