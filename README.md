# HexRush

Jogo de conversão binário → hexadecimal para a placa **DE2-115** (Nios II, Altera Monitor Program), feito para o projeto de Microprocessadores 2026.

Um alvo hexadecimal (0–F) aparece em HEX7 e anda um display para a direita a cada período do timer. O jogador monta o mesmo valor em binário nas chaves SW[17:14] (HEX0 mostra o valor das chaves em hex). Quando o alvo chega em HEX0, o valor das chaves é comparado: acerto soma 1 ponto e acelera o jogo em 6,25%; erro tira 1 vida. Com 0 vidas, o jogo termina e mostra a pontuação.

**Grupo:** Gustavo Gomes da Cruz, Gustavo Varjão de Frias, Moisés Nascimento Dearo e Vitor Passagem.

---

## Como montar e rodar

1. No Monitor Program, crie um projeto **na raiz deste repositório** (os arquivos usam `.include "constants.s"`, que é procurado a partir da pasta do projeto).
2. Sistema: **DE2-115 Basic Computer**. Tipo de programa: **Assembly Program**.
3. Adicione os arquivos-fonte **nesta ordem**:

   | # | Arquivo |
   |---|---|
   | 1 | `interrupts.s` ← **obrigatoriamente o primeiro** |
   | 2 | `main.s` |
   | 3 | `display.s` |
   | 4 | `leds.s` |
   | 5 | `timer.s` |
   | 6 | `uart.s` |
   | 7 | `targets.s` |
   | 8 | `utils.s` |

   **Não** adicione `constants.s`: ele entra nos outros arquivos pelo `.include`.
4. **Compile & Load**. Confira no Disassembly que o endereço **0x20** contém `rdctl et, ipending`. Se não contiver, o `interrupts.s` não está em primeiro lugar.
5. Deixe o **terminal do Monitor Program aberto** e rode. A JTAG UART só esvazia a fila de saída quando o terminal está lendo; com ele fechado, o jogo trava ao encher a fila (64 caracteres).

### Controles

| Entrada | Função |
|---|---|
| KEY1 | Inicia a partida; reinicia a qualquer momento (inclusive na pausa e no fim de jogo) |
| KEY2 | Pausa / continua |
| SW[17:14] | Resposta do jogador (binário) |

### Saídas

| Saída | O que mostra |
|---|---|
| HEX7 → HEX1 | O alvo andando |
| HEX0 | Valor atual de SW[17:14] em hex |
| LEDR | O **próximo** alvo, em unário (valor n = n LEDs acesos) |
| LEDG | Vidas restantes, em unário |
| Terminal (JTAG UART) | Uma linha por rodada e uma linha de fim de jogo |

---

## Estrutura do repositório

```
hex-rush/
├── constants.s         constantes de todo o projeto (só .equ)
├── interrupts.s        RTI em 0x20, ISRs do timer e dos botões, interrupts_init
├── main.s              ponto de entrada e máquina de estados do jogo
├── display.s           displays de 7 segmentos
├── leds.s              LEDs vermelhos e verdes
├── timer.s             Interval Timer (passo do alvo, pausa, aceleração)
├── uart.s              mensagens no terminal
├── targets.s           lista fixa dos 100 alvos
├── utils.s             conversão para decimal (usada por display.s e uart.s)
├── tests/
│   ├── test_display.s      teste isolado de display.s e utils.s
│   └── test_timer_keys.s   teste de interrupts.s, timer.s e leds.s
└── docs/
    ├── especificacao.md    decisões, máquina de estados, interfaces
    ├── cronograma.md       cronograma e divisão de tarefas
    └── hexrush_fsm.vhd     modelo da máquina de estados em VHDL
```

---

## O que cada arquivo faz

Todas as rotinas seguem a convenção do Nios II: argumentos em **r4–r7**, retorno em **r2**, **r8–r15** podem ser alterados pela rotina chamada, **r16–r23** são preservados (quem usa salva na pilha e restaura). A tabela completa de interfaces está em [`docs/especificacao.md`](docs/especificacao.md), seção 3.

### `constants.s`

Não gera código nem dados: só define nomes com `.equ`, e é incluído pelos outros arquivos com `.include "constants.s"`. Uma guarda `.ifndef` impede definição dupla se ele for incluído duas vezes no mesmo arquivo. Mudar um parâmetro do jogo é mudar **só aqui**.

| Grupo | Constantes |
|---|---|
| Endereços dos periféricos | `LEDR_BASE`, `LEDG_BASE`, `HEX3_HEX0_BASE`, `HEX7_HEX4_BASE`, `SW_BASE`, `KEY_BASE`, `JTAG_UART_BASE`, `TIMER_BASE` |
| Registradores dos botões | `KEY_MASK_REG` (+0x8), `KEY_EDGE_REG` (+0xC), `KEY1_BIT`, `KEY2_BIT` |
| Registradores da UART | `UART_DATA_REG` (+0x0), `UART_CTRL_REG` (+0x4) |
| Registradores do timer | `TIMER_STATUS_REG`, `TIMER_CTRL_REG`, `TIMER_PERIODL_REG`, `TIMER_PERIODH_REG`, `TIMER_SNAPL_REG`, `TIMER_SNAPH_REG` |
| Bits de controle do timer | `TIMER_ITO`, `TIMER_CONT`, `TIMER_START`, `TIMER_STOP` |
| Linhas de interrupção | `IRQ_TIMER` (IRQ0), `IRQ_KEY` (IRQ1) |
| Memória | `STACK_TOP` = `0x01000000` |
| Parâmetros do jogo | `PERIODO_INICIAL` (50.000.000 ciclos = 1 s), `ACEL_SHIFT` (4 → reduz 1/16 = 6,25%), `VIDAS_INICIAIS` (3), `POS_INICIAL` (7 = HEX7), `POS_FINAL` (1 = HEX1), `NUM_ALVOS` (100) |
| 7 segmentos | `HEX_APAGA` (código de "apagar" para `set_hex_digit`), `SEG_APAGADO`, e as letras `SEG_G`, `SEG_O`, `SEG_P`, `SEG_L`, `SEG_A`, `SEG_Y` |

### `interrupts.s`

Contém a **RTI** (rotina de tratamento de interrupções) e a rotina que liga as interrupções. **Precisa ser o primeiro arquivo do projeto**: a RTI é posicionada com `.org 0x20`, igual aos labs, e o `.org` conta a partir do início do `.text` deste arquivo.

| Rotina | Entrada | Saída | O que faz |
|---|---|---|---|
| `RTI` (em 0x20) | — | — | Lê `ipending`. Se for interrupção: ajusta `ea`, salva `ra`, r8, r9, r10 na pilha, chama `TIMER_IRQ` se a IRQ0 estiver pendente e `KEY_IRQ` se a IRQ1 estiver, restaura os registradores e faz `eret`. Se **não** for interrupção (qualquer outra exceção, que no jogo é sempre bug), acende os 18 LEDR e trava num laço, deixando `ea` apontando para a instrução seguinte à que falhou. |
| `TIMER_IRQ` | — | — | Limpa o bit TO do timer (senão a IRQ fica pendente para sempre) e faz `FLAG_TICK = 1`. |
| `KEY_IRQ` | — | — | Lê o edgecapture dos botões, limpa-o, e faz `FLAG_KEY1 = 1` e/ou `FLAG_KEY2 = 1` conforme os botões apertados. Os dois podem subir juntos; quem decide a prioridade é o `main.s`. |
| `interrupts_init` | — | — | Limpa o edgecapture, habilita interrupção só de KEY1 e KEY2 (máscara), habilita IRQ0 e IRQ1 em `ienable` e liga o PIE, nessa ordem. |

As ISRs **só levantam flags** (0 ou 1): todo o trabalho fica no laço principal. Os flags são declarados em `main.s`.

### `main.s`

Ponto de entrada (`_start`) e **máquina de estados** do jogo. Declara os três flags (`FLAG_TICK`, `FLAG_KEY1`, `FLAG_KEY2`) na seção `.data`, com `.global` para a RTI enxergá-los. Cada estado é um trecho com rótulo próprio; mudar de estado é desviar (`br`/`beq`/`bne`) para o rótulo.

**Mapa de registradores** (valem durante todo o jogo):

| Registrador | Variável |
|---|---|
| r16 | pontos |
| r17 | vidas |
| r18 | número da rodada |
| r19 | posição do alvo (7 = HEX7 … 1 = HEX1) |
| r20 | índice do alvo atual na lista (0–99) |
| r21 | período atual do timer, em ciclos |
| r22, r23 | temporários do laço principal (resposta e alvo, no FIM_RODADA) |

O alvo atual e o próximo não são guardados: são sempre `get_target(r20)` e `get_target(r20 + 1)`.

| Estado | O que faz | Sai para |
|---|---|---|
| `ESTADO_AGUARDANDO` | Só ao ligar. Para o timer, mostra `PLAY` em HEX3–HEX0, apaga os LEDs, imprime `Pressione KEY1 para iniciar` e chama `interrupts_init`. Fica esperando; descarta apertos de KEY2. | INICIO (KEY1) |
| `ESTADO_INICIO` | Pontos = 0, vidas = 3, rodada = 1, posição = 7, índice = 0, período = 1 s. Limpa os três flags. Apaga os displays, desenha o primeiro alvo em HEX7, acende 3 LEDG, mostra o próximo alvo em LEDR e liga o timer. Não espera nada. | JOGANDO |
| `ESTADO_JOGANDO` | A cada volta, mostra SW[17:14] em HEX0. Depois testa, nesta prioridade: **KEY1** (reinicia), **KEY2** (pausa), **tick** (o alvo anda um display; se já estava em HEX1, a rodada termina). | INICIO, PAUSADO, FIM_RODADA |
| `ESTADO_PAUSADO` | Para o timer (que guarda o tempo restante) e não atualiza nada, nem HEX0. KEY2 retoma o timer de onde parou; KEY1 reinicia a partida. Um tick que já tinha chegado é tratado ao voltar. | JOGANDO (KEY2), INICIO (KEY1) |
| `ESTADO_FIM_RODADA` | Apaga HEX1, lê as chaves e compara com o alvo. **Acerto:** pontos + 1, período − período/16 e reinicia o timer com o período novo. **Erro:** vidas − 1 e atualiza os LEDG. Imprime a linha da rodada, faz rodada + 1 e, se ainda há vidas, avança o índice (voltando a 0 depois do 99), desenha o novo alvo em HEX7 e atualiza o LEDR. Não espera nada. | JOGANDO, FIM_JOGO (vidas = 0) |
| `ESTADO_FIM_JOGO` | Para o timer, mostra `GO  dddd` com os pontos, apaga os LEDs e imprime a linha final com a sequência de alvos. Espera KEY1; descarta KEY2. | INICIO (KEY1) |

Rotina local: `ler_resposta` devolve em r2 o valor de SW[17:14]. É usada para HEX0 e para a comparação, para as duas lerem as chaves do mesmo jeito.

### `display.s`

Tudo que escreve nos displays de 7 segmentos. Contém a tabela `HEX7SEG_TABLE` (padrões de 0 a F, com `b` e `d` minúsculos, conforme a Tabela 2 do enunciado), na seção `.data`.

| Rotina | Entrada | Saída | O que faz |
|---|---|---|---|
| `set_hex_raw` | r4 = display (0–7), r5 = padrão de 7 segmentos | — | Escolhe o registrador do grupo (HEX3–0 ou HEX7–4), lê os 4 displays, troca só o byte do display pedido e escreve de volta, para não apagar os outros três. Usada para as letras. |
| `set_hex_digit` | r4 = display (0–7), r5 = dígito (0–15) ou `HEX_APAGA` | — | Converte o dígito no padrão pela tabela (ou usa o padrão apagado) e chama `set_hex_raw`. |
| `clear_hex` | — | — | Zera os dois registradores dos displays (apaga os 8). |
| `show_play` | — | — | HEX7–HEX4 apagados e `PLAY` em HEX3–HEX0, com um `stwio` em cada grupo. |
| `show_game_over` | r4 = pontos | — | Converte os pontos com `to_bcd`, escreve `GO` + dois apagados em HEX7–HEX4 e os 4 dígitos de baixo, com zeros à esquerda, em HEX3–HEX0 (ex.: `GO  0007`). |

Usa: `to_bcd` (`utils.s`).

### `leds.s`

| Rotina | Entrada | Saída | O que faz |
|---|---|---|---|
| `set_ledr_unary` | r4 = n (0–15) | — | Escreve `(1 << n) − 1` nos LEDR: acende os n primeiros (n = 0 apaga todos). Usada para o próximo alvo. |
| `set_ledg_lives` | r4 = vidas | — | Mesma conta nos LEDG: um LED verde por vida. |
| `clear_leds` | — | — | Apaga LEDR e LEDG. |

### `timer.s`

Controla o Interval Timer. O período do timer é o próprio passo do alvo: cada timeout gera uma interrupção (IRQ0), e a `TIMER_IRQ` levanta `FLAG_TICK`.

| Rotina | Entrada | Saída | O que faz |
|---|---|---|---|
| `timer_start` | r4 = período em ciclos | — | Para o timer, limpa um TO antigo, grava o período em duas metades de 16 bits e liga com ITO (interrupção) + CONT (recarga automática) + START. |
| `timer_stop` | — | — | Escreve STOP mantendo ITO e CONT: o contador congela no valor atual (pausa). |
| `timer_resume` | — | — | Escreve START mantendo ITO e CONT: o contador continua de onde parou. |
| `next_period` | r4 = período | r2 = novo período | Devolve `período − (período >> 4)`, ou seja, 6,25% menor. Sem piso: abaixo de 16 ciclos o período para de cair sozinho. |

### `uart.s`

Escreve no terminal pela JTAG UART, só saída, por **polling do WSPACE** (igual ao `part1.s` do lab 6). Contém na `.data` a tabela `DIGITOS_HEX` (`"0123456789ABCDEF"`) e os textos fixos das mensagens.

| Rotina | Entrada | Saída | O que faz |
|---|---|---|---|
| `uart_putc` | r4 = caractere | — | Espera haver espaço na fila de escrita e envia o caractere. |
| `uart_puts` | r4 = endereço de string terminada em 0 | — | Envia caractere por caractere até o 0. |
| `uart_put_dec` | r4 = valor | — | Converte com `to_bcd`, pula os zeros da esquerda (mantendo sempre o das unidades) e envia os dígitos. |
| `uart_put_hex_digit` | r4 = 0–15 | — | Envia o dígito como caractere maiúsculo (`A`–`F`). |
| `uart_print_wait` | — | — | Envia `Pressione KEY1 para iniciar`. |
| `uart_print_round` | r4 = rodada, r5 = alvo, r6 = resposta, r7 = pontos (acerto) ou vidas (erro) | — | Envia a linha da rodada. Decide ACERTO/ERRO comparando r5 com r6. |
| `uart_print_end` | r4 = pontos, r5 = rodadas jogadas | — | Envia a linha final; a sequência é `get_target(0)` … `get_target(rodadas − 1)`. |

Formato das linhas:

```
Pressione KEY1 para iniciar
Rodada 5 | Alvo: C | Resposta: C | ACERTO | Pontos: 5
Rodada 6 | Alvo: 7 | Resposta: 3 | ERRO   | Vidas: 2
=== FIM DE JOGO === Pontuacao final: 5 | Sequencia: EF054032
```

Usa: `to_bcd` (`utils.s`), `get_target` (`targets.s`).

### `targets.s`

A lista fixa dos **100 alvos** escolhidos pelo grupo (no lugar de um gerador aleatório), em `.byte`, no estilo da `TABELA_HEX` do lab 5. A lista é circular, e toda partida começa no primeiro alvo.

| Rotina | Entrada | Saída | O que faz |
|---|---|---|---|
| `get_target` | r4 = índice | r2 = alvo (0–15) | Reduz o índice a 0–99 subtraindo 100 enquanto puder (o processador não tem `div`) e lê o byte da lista. |

### `utils.s`

Rotinas usadas por mais de um módulo.

| Rotina | Entrada | Saída | O que faz |
|---|---|---|---|
| `to_bcd` | r4 = valor | r2 = valor em BCD compactado | Para cada potência de 10 (10.000.000 até 1), conta quantas vezes ela cabe no valor, subtraindo, e guarda a contagem como um nibble. Ex.: 507 → `0x00000507`. Valores acima de 99.999.999 são limitados a esse máximo. Não usa `div` nem `mul`, que o processador da placa não tem. |

### `tests/test_display.s`

Programa de teste isolado de `display.s` e `utils.s` (projeto: este arquivo **primeiro**, depois `display.s` e `utils.s`). Tem um tratador próprio em `.org 0x20` (acende os LEDR e trava) e usa o timer **por polling**, sem interrupções. Mostra `PLAY` por 2 s, `GO  0507` por 2 s, `GO  0000` por 2 s e, depois, um alvo de teste andando de HEX7 a HEX1 enquanto HEX0 acompanha as chaves.

### `tests/test_timer_keys.s`

Programa de teste de `interrupts.s`, `timer.s` e `leds.s` (projeto: `interrupts.s` **primeiro**, depois este arquivo, `timer.s`, `leds.s`, `display.s`, `utils.s`). Declara os próprios flags, fazendo o papel do `main.s`. Mostra em `GO  dddd` um contador que sobe 1 por tick, cicla os LEDG de 0 a 3, mostra SW[17:14] em unário nos LEDR, acelera com KEY1 e pausa/continua com KEY2.

### `docs/especificacao.md`

Todas as decisões do grupo (regras, displays, velocidade, alvos, UART, técnica de acesso a cada periférico, placa e processador), a máquina de estados em Mermaid com a descrição de cada estado e transição, a organização do código (arquivos, convenção de chamada, mapa de registradores, regra de comentários) e a tabela de interfaces de todas as sub-rotinas.

### `docs/cronograma.md`

Cronograma de 3 semanas com as tarefas, responsáveis, datas, dependências e critério de pronto de cada uma.

### `docs/hexrush_fsm.vhd`

Modelo de referência da máquina de estados em VHDL, para documentação: cada entrada corresponde a algo que o software observa (flags, chaves) e cada saída, a uma sub-rotina que o laço principal chama naquele estado. Não faz parte do programa da placa.

---

## Observações importantes

- **O processador não tem `div` nem `mul`.** Nenhum arquivo usa essas instruções: a aceleração é um deslocamento e a conversão decimal é por subtração.
- **Qualquer exceção acende todos os LEDR e trava.** Pause e olhe o registrador `ea`: ele aponta para a instrução seguinte à que causou a exceção.
- **Comentários:** toda linha de instrução tem um comentário com o que ela faz, e todo trecho pequeno tem um comentário de bloco com o que o trecho faz.
