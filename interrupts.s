/* ============================================================================
 * interrupts.s - Rotina de tratamento de interrupcoes (RTI) e inicializacao
 *
 * !!! ESTE ARQUIVO PRECISA SER O PRIMEIRO DA LISTA DE ARQUIVOS DO PROJETO !!!
 * A RTI e posicionada com .org 0x20, igual aos labs: o .org conta a partir
 * do inicio do .text DESTE arquivo, entao so cai no endereco 0x20 de verdade
 * se este arquivo for o primeiro a ser ligado. Fora de ordem, o projeto
 * monta sem erro, mas as interrupcoes vao para o lugar errado.
 *
 * Modelo do projeto: as ISRs so LEVANTAM FLAGS na memoria; todo o trabalho
 * (mover alvo, comparar, UART) fica no laco principal. Assim a RTI e curta
 * e nunca chama a UART, que pode demorar.
 *
 * Flags (declarados em main.s, ou no arquivo de teste):
 *   FLAG_TICK  <- timeout do timer (IRQ0)
 *   FLAG_KEY1  <- borda em KEY1   (IRQ1)
 *   FLAG_KEY2  <- borda em KEY2   (IRQ1)
 * Cada um vale 0 ou 1 (decisao do grupo: um tick extra antes de o laco
 * consumir o anterior se perde, em vez de acumular).
 *
 * Estrutura igual a do lab 5 (RTI -> call da ISR -> END_HANDLER -> eret),
 * com duas diferencas exigidas pela secao 6.2 do enunciado: a RTI salva os
 * registradores que usa e o ra (no lab, o call dentro da RTI sobrescrevia o
 * ra do codigo interrompido).
 *
 * Rotina publica:
 *   interrupts_init   habilita KEY1/KEY2, IRQ0/IRQ1 e o PIE
 * O timer ja liga o proprio ITO em timer_start (timer.s).
 * ============================================================================ */

.include "constants.s"                  /* traz enderecos, bits e IRQs */

.global interrupts_init                 /* exporta interrupts_init */

.text                                   /* monta na secao de codigo */
.org 0x20                               /* endereco da RTI (igual aos labs) */

/* ----------------------------------------------------------------------------
 * RTI
 * O codigo interrompido pode estar usando qualquer registrador, entao a RTI
 * salva na pilha tudo o que ela e as ISRs usam alem de et: ra, r8, r9, r10.
 * As ISRs nao podem alterar et, que guarda as IRQs pendentes.
 * ---------------------------------------------------------------------------- */
RTI:
    /* Separa interrupcao de outras excecoes */
    rdctl et, ipending              /* et = interrupcoes pendentes */
    beq   et, r0, OTHER_EXCEPTIONS  /* se nenhuma, e outra excecao */
    subi  ea, ea, 4                 /* volta ea para a instrucao interrompida */

    /* Salva os registradores usados pela RTI e pelas ISRs */
    subi  sp, sp, 16                /* reserva 4 words na pilha */
    stw   ra, 0(sp)                 /* salva ra (os calls abaixo o alteram) */
    stw   r8, 4(sp)                 /* salva r8 */
    stw   r9, 8(sp)                 /* salva r9 */
    stw   r10, 12(sp)               /* salva r10 */

    /* IRQ0 = timer */
    andi  r8, et, IRQ_TIMER         /* r8 = bit da IRQ do timer */
    beq   r8, r0, CHECK_KEY_IRQ     /* se o timer nao pediu, vai para os botoes */
    call  TIMER_IRQ                 /* trata o timer */

CHECK_KEY_IRQ:
    /* IRQ1 = push buttons */
    andi  r8, et, IRQ_KEY           /* r8 = bit da IRQ dos botoes */
    beq   r8, r0, OTHER_INTERRUPTS  /* se os botoes nao pediram, termina */
    call  KEY_IRQ                   /* trata os botoes */

OTHER_INTERRUPTS:
    /* Restaura os registradores salvos */
    ldw   ra, 0(sp)                 /* restaura ra */
    ldw   r8, 4(sp)                 /* restaura r8 */
    ldw   r9, 8(sp)                 /* restaura r9 */
    ldw   r10, 12(sp)               /* restaura r10 */
    addi  sp, sp, 16                /* libera os 4 words da pilha */
    br    END_HANDLER               /* vai para o eret */

OTHER_EXCEPTIONS:
    /* Outra excecao (o jogo nao usa nenhuma): e bug. Acende todos os LEDR
     * e trava, para aparecer na placa; ea aponta para a instrucao seguinte
     * a que causou a excecao. */
    movia et, LEDR_BASE             /* et = endereco dos LEDR */
    movia r8, 0x3FFFF               /* r8 = 18 bits 1 (LEDR[17:0]) */
    stwio r8, 0(et)                 /* acende todos os LEDR */
TRAVA_EXCECAO:
    br    TRAVA_EXCECAO             /* fica parado aqui para sempre */

END_HANDLER:
    eret                            /* retorna ao codigo interrompido */

/* ----------------------------------------------------------------------------
 * TIMER_IRQ
 * Timeout do timer = um passo do alvo. Usa so r8 e r9 (salvos pela RTI).
 * ---------------------------------------------------------------------------- */
TIMER_IRQ:
    /* Confirma o timeout no timer */
    movia r8, TIMER_BASE            /* r8 = endereco do timer */
    stwio r0, TIMER_STATUS_REG(r8)  /* limpa TO (senao a IRQ fica pendente para sempre) */

    /* Avisa o laco principal */
    movi  r9, 1                     /* r9 = 1 */
    movia r8, FLAG_TICK             /* r8 = endereco de FLAG_TICK */
    stw   r9, 0(r8)                 /* FLAG_TICK = 1 */
    ret                             /* volta para a RTI */

/* ----------------------------------------------------------------------------
 * KEY_IRQ
 * Le e limpa o edgecapture (mesma ordem do lab 5: le ANTES de limpar) e
 * levanta o flag de cada botao apertado. Usa so r8, r9 e r10.
 * ---------------------------------------------------------------------------- */
KEY_IRQ:
    /* Descobre quais botoes tiveram borda e limpa o edgecapture */
    movia r8, KEY_BASE              /* r8 = endereco dos botoes */
    ldwio r9, KEY_EDGE_REG(r8)      /* r9 = quais botoes tiveram borda */
    stwio r0, KEY_EDGE_REG(r8)      /* limpa o edgecapture (depois de ler) */
    movi  r10, 1                    /* r10 = 1, valor para levantar flags */

    /* KEY1: levanta FLAG_KEY1 */
    andi  r8, r9, KEY1_BIT          /* r8 = bit do KEY1 */
    beq   r8, r0, KEY_IRQ2          /* se KEY1 nao foi apertado, pula */
    movia r8, FLAG_KEY1             /* r8 = endereco de FLAG_KEY1 */
    stw   r10, 0(r8)                /* FLAG_KEY1 = 1 */

KEY_IRQ2:
    /* KEY2: levanta FLAG_KEY2 (os dois podem subir juntos; o laco
     * principal decide pela prioridade KEY1 > KEY2) */
    andi  r8, r9, KEY2_BIT          /* r8 = bit do KEY2 */
    beq   r8, r0, FIM_KEY_IRQ       /* se KEY2 nao foi apertado, pula */
    movia r8, FLAG_KEY2             /* r8 = endereco de FLAG_KEY2 */
    stw   r10, 0(r8)                /* FLAG_KEY2 = 1 */

FIM_KEY_IRQ:
    ret                             /* volta para a RTI */

/* ----------------------------------------------------------------------------
 * interrupts_init
 * Mesma ordem dos labs: 3. bits do dispositivo, 2. ienable, 1. PIE por
 * ultimo, para que nenhuma interrupcao chegue antes de tudo estar
 * configurado. Limpa o edgecapture antes, para que um aperto feito antes do
 * jogo nao vire evento.
 * ---------------------------------------------------------------------------- */
interrupts_init:
    /* 3. Dispositivo: botoes KEY1 e KEY2 geram interrupcao */
    movia r8, KEY_BASE              /* r8 = endereco dos botoes */
    stwio r0, KEY_EDGE_REG(r8)      /* limpa apertos antigos do edgecapture */
    movi  r9, KEY1_BIT | KEY2_BIT   /* r9 = mascara de KEY1 e KEY2 */
    stwio r9, KEY_MASK_REG(r8)      /* habilita interrupcao so desses dois */

    /* 2. ienable: aceita IRQ0 (timer) e IRQ1 (botoes) */
    movi  r9, IRQ_TIMER | IRQ_KEY   /* r9 = bits das IRQs 0 e 1 */
    wrctl ienable, r9               /* habilita essas IRQs no processador */

    /* 1. PIE: liga as interrupcoes de forma global */
    movi  r9, 1                     /* r9 = 1 (bit PIE) */
    wrctl status, r9                /* PIE = 1 */
    ret                             /* retorna */
