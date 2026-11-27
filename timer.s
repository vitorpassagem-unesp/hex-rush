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

.include "constants.s"                  /* traz endereco e bits do timer */

/* Rotinas visiveis para os outros arquivos */
.global timer_start                     /* exporta timer_start */
.global timer_stop                      /* exporta timer_stop */
.global timer_resume                    /* exporta timer_resume */
.global next_period                     /* exporta next_period */

/* Controle com o timer contando: interrupcao no timeout (ITO) e recarga
 * automatica do periodo (CONT), para os passos ficarem regulares sem o
 * software precisar reiniciar o timer a cada tick. */
.equ CTRL_RODANDO, TIMER_ITO | TIMER_CONT | TIMER_START   /* contando */
.equ CTRL_PARADO,  TIMER_ITO | TIMER_CONT | TIMER_STOP    /* parado, mesma config */

.text                                   /* monta na secao de codigo */

/* ----------------------------------------------------------------------------
 * timer_start
 * Usada no INICIO e depois de cada acerto (periodo novo). Para o timer antes
 * de mexer no periodo e limpa um TO antigo, para que um timeout da
 * configuracao anterior nao vire um tick falso logo apos o reinicio.
 * ---------------------------------------------------------------------------- */
timer_start:
    /* Para o timer e descarta um timeout antigo */
    movia r8, TIMER_BASE            /* r8 = endereco do timer */
    movi  r9, TIMER_STOP            /* r9 = comando STOP */
    stwio r9, TIMER_CTRL_REG(r8)    /* para o timer */
    stwio r0, TIMER_STATUS_REG(r8)  /* limpa o bit TO */

    /* Escreve o periodo novo (o registrador tem 16 bits por metade) */
    andi  r9, r4, 0xFFFF            /* r9 = 16 bits de baixo do periodo */
    stwio r9, TIMER_PERIODL_REG(r8) /* grava a metade baixa */
    srli  r9, r4, 16                /* r9 = 16 bits de cima do periodo */
    stwio r9, TIMER_PERIODH_REG(r8) /* grava a metade alta */

    /* Liga o timer com interrupcao e recarga automatica */
    movi  r9, CTRL_RODANDO          /* r9 = ITO | CONT | START */
    stwio r9, TIMER_CTRL_REG(r8)    /* comeca a contar */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * timer_stop
 * Pausa (KEY2). STOP congela o contador no valor atual, entao o alvo nao
 * ganha nem perde tempo com a pausa. Mantem ITO e CONT ligados para o
 * timer_resume so precisar trocar STOP por START.
 * Um tick que ja tenha chegado continua no FLAG_TICK e e processado ao
 * despausar (decisao do grupo).
 * ---------------------------------------------------------------------------- */
timer_stop:
    movia r8, TIMER_BASE            /* r8 = endereco do timer */
    movi  r9, CTRL_PARADO           /* r9 = ITO | CONT | STOP */
    stwio r9, TIMER_CTRL_REG(r8)    /* congela o contador */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * timer_resume
 * Despausa: START retoma a contagem do valor em que o contador parou, e nao
 * de um periodo inteiro.
 * ---------------------------------------------------------------------------- */
timer_resume:
    movia r8, TIMER_BASE            /* r8 = endereco do timer */
    movi  r9, CTRL_RODANDO          /* r9 = ITO | CONT | START */
    stwio r9, TIMER_CTRL_REG(r8)    /* volta a contar de onde parou */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * next_period
 * Aceleracao apos um acerto: tira 1/16 (6,25%) do periodo atual. O
 * processador nao tem div nem mul, entao o divisor e potencia de 2 e a
 * conta vira um deslocamento. Sem piso (decisao do grupo): abaixo de 16
 * ciclos p >> 4 vale 0 e o periodo para de cair sozinho.
 * ---------------------------------------------------------------------------- */
next_period:
    srli  r2, r4, ACEL_SHIFT        /* r2 = periodo / 16 */
    sub   r2, r4, r2                /* r2 = periodo - periodo / 16 */
    ret                             /* retorna com o periodo novo em r2 */
