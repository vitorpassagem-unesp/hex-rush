/* ============================================================================
 * timer.s - Controle do Interval Timer (passo do alvo)
 *
 * O periodo do timer e o proprio passo do alvo (como no lab da aula): cada
 * timeout gera uma interrupcao, e a ISR em interrupts.s levanta FLAG_TICK.
 *
 * Rotinas (convencao Nios II):
 *   timer_start    r4 = periodo em ciclos -> programa e comeca do zero
 *   timer_stop     pausa, guardando o tempo restante
 *   timer_resume   continua de onde parou
 *   next_period    r4 = periodo -> r2 = periodo - (periodo >> ACEL_SHIFT)
 *
 * Usam so r8-r9 e nao chamam ninguem: nao precisam de pilha.
 * ============================================================================ */

.include "constants.s"

.global timer_start
.global timer_stop
.global timer_resume
.global next_period

/* Controle com o timer contando: interrupcao no timeout (ITO) e recarga
 * automatica do periodo (CONT), para os passos ficarem regulares sem o
 * software precisar reiniciar o timer a cada tick. */
.equ CTRL_RODANDO, TIMER_ITO | TIMER_CONT | TIMER_START
.equ CTRL_PARADO,  TIMER_ITO | TIMER_CONT | TIMER_STOP

.text

/* ----------------------------------------------------------------------------
 * timer_start
 * Usada no INICIO e depois de cada acerto (periodo novo). Para o timer antes
 * de mexer no periodo e limpa um TO antigo, para que um timeout da
 * configuracao anterior nao vire um tick falso logo apos o reinicio.
 * ---------------------------------------------------------------------------- */
timer_start:
    movia r8, TIMER_BASE
    movi  r9, TIMER_STOP
    stwio r9, TIMER_CTRL_REG(r8)
    stwio r0, TIMER_STATUS_REG(r8)

    andi  r9, r4, 0xFFFF            /* o periodo e escrito em duas metades */
    stwio r9, TIMER_PERIODL_REG(r8)
    srli  r9, r4, 16
    stwio r9, TIMER_PERIODH_REG(r8)

    movi  r9, CTRL_RODANDO
    stwio r9, TIMER_CTRL_REG(r8)
    ret

/* ----------------------------------------------------------------------------
 * timer_stop
 * Pausa (KEY2). STOP congela o contador no valor atual, entao o alvo nao
 * ganha nem perde tempo com a pausa. Mantem ITO e CONT ligados para o
 * timer_resume so precisar trocar STOP por START.
 * Um tick que ja tenha chegado continua no FLAG_TICK e e processado ao
 * despausar (decisao do grupo).
 * ---------------------------------------------------------------------------- */
timer_stop:
    movia r8, TIMER_BASE
    movi  r9, CTRL_PARADO
    stwio r9, TIMER_CTRL_REG(r8)
    ret

/* ----------------------------------------------------------------------------
 * timer_resume
 * Despausa: START retoma a contagem do valor em que o contador parou, e nao
 * de um periodo inteiro.
 * ---------------------------------------------------------------------------- */
timer_resume:
    movia r8, TIMER_BASE
    movi  r9, CTRL_RODANDO
    stwio r9, TIMER_CTRL_REG(r8)
    ret

/* ----------------------------------------------------------------------------
 * next_period
 * Aceleracao apos um acerto: tira 1/16 (6,25%) do periodo atual. O
 * processador nao tem div nem mul, entao o divisor e potencia de 2 e a
 * conta vira um deslocamento. Sem piso (decisao do grupo): abaixo de 16
 * ciclos p >> 4 vale 0 e o periodo para de cair sozinho.
 * ---------------------------------------------------------------------------- */
next_period:
    srli  r2, r4, ACEL_SHIFT
    sub   r2, r4, r2
    ret
