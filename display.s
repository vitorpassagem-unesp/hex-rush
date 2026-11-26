/* ============================================================================
 * display.s - Modulo dos displays de 7 segmentos (HEX7..HEX0)
 *
 * Criado a partir do teste visual do Gustavo Gomes (set_hex_digit). O teste
 * isolado esta em tests/test_display.s.
 *
 * Rotinas (convencao Nios II: argumentos em r4-r7, retorno em r2):
 *   set_hex_raw     r4 = display 0..7, r5 = padrao de 7 segmentos
 *   set_hex_digit   r4 = display 0..7, r5 = digito 0..15 ou HEX_APAGA
 *   clear_hex       apaga HEX7..HEX0
 *   show_play       HEX7..HEX4 apagados, HEX3..HEX0 = "PLAY"
 *   show_game_over  r4 = pontos -> "GO  dddd" (4 digitos, zeros a esquerda)
 *
 * Nenhuma rotina usa r16-r23, entao nao precisam salva-los. Todas podem
 * alterar r8-r15 (caller-saved).
 * ============================================================================ */

.include "constants.s"

/* Padroes montados de uma vez para escrever 4 displays com um so stwio. */
.equ PADRAO_PLAY, (SEG_P << 24) | (SEG_L << 16) | (SEG_A << 8) | SEG_Y
.equ PADRAO_GO,   (SEG_G << 24) | (SEG_O << 16)     /* HEX5 e HEX4 apagados */

.global set_hex_raw
.global set_hex_digit
.global clear_hex
.global show_play
.global show_game_over

/* Tabela 7 segmentos (0..F) conforme Tabela 2 do enunciado.
 * Fica em .data (e nao em .rodata) porque e a secao que o Monitor Program
 * sempre posiciona na memoria em projetos so de assembly. */
.data
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
    .byte 0x7C  /* b: cdefg   (minusculo para nao confundir com 8) */
    .byte 0x39  /* C: adef    */
    .byte 0x5E  /* d: bcdeg   (minusculo para nao confundir com 0) */
    .byte 0x79  /* E: adefg   */
    .byte 0x71  /* F: aefg    */

.text

/* ----------------------------------------------------------------------------
 * set_hex_raw
 * Escreve um padrao de 7 segmentos qualquer no display r4 (0..7).
 * Usada direto para as letras (G, O, P, L, Y) que nao estao na tabela.
 *
 * Os 4 displays de cada grupo dividem um mesmo registrador de 32 bits, entao
 * e preciso ler, trocar so o byte do display e escrever de volta; senao um
 * display apagaria os outros tres.
 * ---------------------------------------------------------------------------- */
set_hex_raw:
    andi  r8, r4, 0x07              /* indice 0..7 (protege contra lixo) */
    andi  r9, r5, 0xFF              /* padrao ocupa so um byte */

    movia r10, HEX3_HEX0_BASE       /* HEX0..HEX3 */
    movi  r11, 4
    blt   r8, r11, .Lraw_escreve
    subi  r8, r8, 4                 /* HEX4..HEX7: posicao dentro do outro word */
    movia r10, HEX7_HEX4_BASE

.Lraw_escreve:
    slli  r8, r8, 3                 /* deslocamento = 8 bits por display */
    movi  r11, 0xFF
    sll   r11, r11, r8
    nor   r11, r11, r11             /* mascara que zera so o byte deste display */
    sll   r9, r9, r8

    ldwio r12, 0(r10)               /* estado atual dos 4 displays do grupo */
    and   r12, r12, r11
    or    r12, r12, r9
    stwio r12, 0(r10)
    ret

/* ----------------------------------------------------------------------------
 * set_hex_digit
 * Escreve um digito hexadecimal (0..15) no display r4 (0..7).
 * r5 == HEX_APAGA apaga o display, para quem chama nao precisar saber o
 * padrao de 7 segmentos.
 * ---------------------------------------------------------------------------- */
set_hex_digit:
    subi  sp, sp, 4
    stw   ra, 0(sp)                 /* chama set_hex_raw: precisa guardar ra */

    movi  r8, HEX_APAGA
    beq   r5, r8, .Ldig_apaga

    andi  r8, r5, 0x0F
    movia r9, HEX7SEG_TABLE
    add   r9, r9, r8
    ldbu  r5, 0(r9)                 /* ldbu: padrao e byte sem sinal */
    br    .Ldig_escreve

.Ldig_apaga:
    movi  r5, SEG_APAGADO

.Ldig_escreve:
    call  set_hex_raw               /* r4 continua sendo o indice do display */

    ldw   ra, 0(sp)
    addi  sp, sp, 4
    ret

/* ----------------------------------------------------------------------------
 * clear_hex
 * Apaga os 8 displays. Escreve os dois words inteiros: mais simples e mais
 * rapido que apagar display por display.
 * ---------------------------------------------------------------------------- */
clear_hex:
    movia r8, HEX3_HEX0_BASE
    stwio r0, 0(r8)
    movia r8, HEX7_HEX4_BASE
    stwio r0, 0(r8)
    ret

/* ----------------------------------------------------------------------------
 * show_play
 * Tela do estado AGUARDANDO: HEX7..HEX4 apagados e "PLAY" em HEX3..HEX0.
 * ---------------------------------------------------------------------------- */
show_play:
    movia r8, HEX7_HEX4_BASE
    stwio r0, 0(r8)
    movia r8, HEX3_HEX0_BASE
    movia r9, PADRAO_PLAY
    stwio r9, 0(r8)
    ret

/* ----------------------------------------------------------------------------
 * show_game_over
 * Tela do estado FIM_JOGO: "GO  dddd" com os pontos (r4) em decimal.
 * Mostra sempre 4 digitos, com zeros a esquerda (decisao do grupo); acima de
 * 9999 aparecem so os 4 digitos de baixo.
 * ---------------------------------------------------------------------------- */
show_game_over:
    subi  sp, sp, 4
    stw   ra, 0(sp)

    call  to_bcd                    /* r2 = pontos em BCD, 1 digito por nibble */

    movia r8, HEX7_HEX4_BASE
    movia r9, PADRAO_GO
    stwio r9, 0(r8)

    /* Converte os 4 nibbles de baixo em padroes e monta HEX3..HEX0 num word
     * so (mesma ideia do LOOP_HEX do lab 5). */
    movia r10, HEX7SEG_TABLE
    mov   r11, r0                   /* word montado */
    mov   r12, r0                   /* deslocamento: 0, 8, 16, 24 */
    movi  r13, 4                    /* 4 displays */

.Lgo_digito:
    andi  r9, r2, 0x0F              /* digito decimal atual */
    add   r9, r10, r9
    ldbu  r9, 0(r9)
    sll   r9, r9, r12
    or    r11, r11, r9
    srli  r2, r2, 4                 /* proximo digito */
    addi  r12, r12, 8               /* proximo display */
    subi  r13, r13, 1
    bne   r13, r0, .Lgo_digito

    movia r8, HEX3_HEX0_BASE
    stwio r11, 0(r8)

    ldw   ra, 0(sp)
    addi  sp, sp, 4
    ret
