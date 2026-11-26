/* ============================================================================
 * constants.s - Todas as constantes do HexRush em um unico lugar
 *
 * Incluido pelos demais arquivos com  .include "constants.s"
 * Contem apenas .equ (nao gera codigo nem dados), por isso pode ser incluido
 * em qualquer arquivo sem duplicar simbolos.
 *
 * Placa: DE2-115 (Basic/Media Computer no Altera Monitor Program), 50 MHz.
 * ============================================================================ */

.ifndef _HEXRUSH_CONSTANTS_
.equ _HEXRUSH_CONSTANTS_, 1

/* --------------------------------------------------------------------------
 * Enderecos dos perifericos
 * -------------------------------------------------------------------------- */
.equ LEDR_BASE,         0x10000000   /* LEDR[17:0] */
.equ LEDG_BASE,         0x10000010   /* LEDG[7:0]  */
.equ HEX3_HEX0_BASE,    0x10000020   /* HEX3 (31:24) HEX2 (23:16) HEX1 (15:8) HEX0 (7:0) */
.equ HEX7_HEX4_BASE,    0x10000030   /* HEX7 (31:24) HEX6 (23:16) HEX5 (15:8) HEX4 (7:0) */
.equ SW_BASE,           0x10000040   /* SW[17:0]   */
.equ KEY_BASE,          0x10000050   /* KEY[3:0]   */
.equ JTAG_UART_BASE,    0x10001000
.equ TIMER_BASE,        0x10002000   /* Interval Timer */

/* Push buttons: offsets dos registradores a partir de KEY_BASE */
.equ KEY_MASK_REG,      0x08         /* habilita interrupcao por botao */
.equ KEY_EDGE_REG,      0x0C         /* edgecapture: escrever limpa */
.equ KEY1_BIT,          0x02         /* KEY1 = iniciar / reiniciar */
.equ KEY2_BIT,          0x04         /* KEY2 = pausar / despausar  */

/* JTAG UART: offsets a partir de JTAG_UART_BASE */
.equ UART_DATA_REG,     0x00
.equ UART_CTRL_REG,     0x04         /* bits 31:16 = WSPACE */

/* Interval Timer: offsets a partir de TIMER_BASE */
.equ TIMER_STATUS_REG,  0x00         /* bit 0 = TO; escrever limpa */
.equ TIMER_CTRL_REG,    0x04
.equ TIMER_PERIODL_REG, 0x08         /* 16 bits baixos do periodo */
.equ TIMER_PERIODH_REG, 0x0C         /* 16 bits altos do periodo  */
.equ TIMER_SNAPL_REG,   0x10
.equ TIMER_SNAPH_REG,   0x14

/* Bits do registrador de controle do timer */
.equ TIMER_ITO,         0x01         /* gera interrupcao no timeout */
.equ TIMER_CONT,        0x02         /* recarrega e continua contando */
.equ TIMER_START,       0x04
.equ TIMER_STOP,        0x08

/* Linhas de interrupcao (bits de ienable / ipending) */
.equ IRQ_TIMER,         0x01         /* IRQ0 */
.equ IRQ_KEY,           0x02         /* IRQ1 */

/* Topo da pilha: a DE2-115 tem 128 MB de SDRAM a partir de 0x0, entao
 * 16 MB fica bem longe do codigo e dos dados do programa. */
.equ STACK_TOP,         0x01000000

/* --------------------------------------------------------------------------
 * Parametros do jogo (ajustar aqui, e so aqui)
 * -------------------------------------------------------------------------- */
.equ PERIODO_INICIAL,   50000000     /* 1 s por passo a 50 MHz */
.equ DIVISOR_ACEL,      20           /* p = p - p/20 -> reduz 5% por acerto */
.equ VIDAS_INICIAIS,    3
.equ POS_INICIAL,       7            /* alvo nasce em HEX7 */
.equ POS_FINAL,         1            /* ultima posicao visivel (HEX1) */
.equ NUM_ALVOS,         100          /* tamanho da lista em targets.s */

/* --------------------------------------------------------------------------
 * Displays de 7 segmentos (bit 0 = a ... bit 6 = g; 1 = aceso)
 * Os digitos 0-F estao na tabela de display.s; aqui ficam as letras extras.
 * -------------------------------------------------------------------------- */
.equ HEX_APAGA,         0xFF         /* valor especial de set_hex_digit */
.equ SEG_APAGADO,       0x00
.equ SEG_G,             0x3D         /* a c d e f   */
.equ SEG_O,             0x5C         /* c d e g (o minusculo, nao confunde com 0) */
.equ SEG_P,             0x73         /* a b e f g   */
.equ SEG_L,             0x38         /* d e f       */
.equ SEG_A,             0x77         /* a b c e f g */
.equ SEG_Y,             0x6E         /* b c d f g   */

.endif
