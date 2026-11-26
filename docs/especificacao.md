# HexRush – Especificação do jogo

Este documento cobre as etapas 6.1.1 a 6.1.3 do enunciado: as dúvidas levantadas e as decisões tomadas, a máquina de estados e o cronograma (em [`cronograma.md`](cronograma.md)). O modelo formal da máquina de estados em VHDL está em [`hexrush_fsm.vhd`](hexrush_fsm.vhd).

Todas as decisões estão fechadas (as últimas em 26/11).

---

## 1. Decisões tomadas (6.1.1)

### Regras da rodada

| # | Tema | Decisão |
|---|---|---|
| 1 | Quando o erro é detectado | O alvo percorre HEX7 → HEX1 (7 posições). O erro é decidido no passo **seguinte** a HEX1, quando o alvo "chegaria" em HEX0. O jogador tem 7 períodos. |
| 2 | Quando o acerto é verificado | **Somente** quando o alvo chega em HEX0. Não há verificação contínua durante o percurso. |
| 3 | Vidas iniciais | 3, exibidas nos LEDG em unário (`00000111`). |
| 4 | Pontuação | 1 ponto fixo por acerto. Erro não tira pontos. |
| 5 | Início da rodada seguinte | O próximo alvo surge em HEX7 imediatamente. |

### Displays e estados fora da rodada

| # | Tema | Decisão |
|---|---|---|
| 6 | Início | O jogo começa direto ao ligar a placa, sem esperar KEY1. |
| 7 | HEX0 | Mostra **continuamente** o valor de SW[17:14] em hex (regra 3 do enunciado). O valor a ser atingido é o alvo, que anda. |
| 8 | Pausa (KEY2) | Congela todo o programa, inclusive a atualização de HEX0. KEY1 durante a pausa **reinicia** a partida. |
| 8b | KEY2 no fim de jogo | Ignorado; só KEY1 sai do fim de jogo. |
| 9 | Fim de jogo | HEX7–HEX0 mostram `GO  XXXX`, com a pontuação em decimal e **zeros à esquerda** (ex.: `GO  0007`). G = `0x3D`, O = `0x5C` (o minúsculo, para não confundir com o zero). LEDR e LEDG apagados. |

### Velocidade e temporização

| # | Tema | Decisão |
|---|---|---|
| 10 | Período inicial | 1 s por passo = 50.000.000 ciclos a 50 MHz. |
| 11 | Aceleração | A cada acerto, `p = p − p/20` (redução de 5% do valor atual), com a instrução `div`. |
| 12 | Período mínimo | **Sem piso.** Atenção: a regra 7 do enunciado pede um limite mínimo, então isso precisa ser justificado no relatório. Em inteiros, a redução para sozinha quando p < 20 ciclos, mas o jogo fica impraticável muito antes (~77 ms após 50 acertos). |
| 13 | Timer | Como no lab da aula (`part2.s`): o período do timer é o próprio passo do alvo, em modo contínuo, com uma interrupção por passo. A cada acerto o período é reprogramado. |

### Alvos

| # | Tema | Decisão |
|---|---|---|
| 14 | Geração dos números | Lista fixa de 100 valores (abaixo). Todos os 16 dígitos aparecem; há 4 repetições seguidas. |
| 14b | Fim da lista | A lista é **circular**: depois do 100º alvo volta ao primeiro (índice mod 100). |
| 14c | Reinício (KEY1) | Toda partida começa no **primeiro** alvo. Por isso a "Sequencia" da linha final é `lista[0..rodada−1]` (com índice mod 100) e não precisa de buffer de histórico. |

Lista (na ordem):

```
e f 0 5 4 0 3 b 2 5   3 4 c 8 7 5 f 8 6 7
f e c 0 1 d 5 9 3 0   a e c 0 8 3 d 3 1 1
2 0 4 3 1 a c 0 d 2   b 8 6 3 e 1 0 2 b f
7 0 9 9 1 9 8 9 9 8   2 e b 8 3 4 3 b 3 d
4 c b e 6 8 f d 9 9   a 9 3 7 b 9 d a 1 8
```

### UART

| # | Tema | Decisão |
|---|---|---|
| 15 | Formato | O mesmo do exemplo do enunciado: ACERTO mostra `Pontos`, ERRO mostra `Vidas`. |

```
Rodada 05 | Alvo: C | Resposta: C | ACERTO | Pontos: 50
Rodada 06 | Alvo: 7 | Resposta: 3 | ERRO   | Vidas: 2
=== FIM DE JOGO === Pontuacao final: 80 | Sequencia: 4A9bC73
```

| 16 | Números | Rodada e pontos em **decimal** (reaproveita a conversão da tela `GO  XXXX`). |

### Técnica de acesso aos periféricos

Modelo geral: as ISRs (timer e KEY) **só levantam flags**, e o laço principal faz todo o trabalho. Assim a ISR fica curta (como pede a seção 6.2) e a rotina da UART, que é lenta, nunca roda dentro de uma interrupção.

| Periférico | Técnica | Por quê |
|---|---|---|
| Timer | Interrupção | Evita espera ativa (seção 6.2) e separa temporização da lógica. Custo: salvar e restaurar registradores na ISR. |
| KEY1 / KEY2 | Interrupção | Resposta imediata; a pausa vira só um flag. O edgecapture também guardaria o aperto em polling, mas o laço teria que testar em todos os pontos. |
| SW | Polling | Única opção: a porta das chaves não gera interrupção no Basic Computer. Lida a cada volta do laço (HEX0) e na comparação. |
| JTAG UART | Polling do WSPACE | A FIFO tem 64 posições e cada linha tem ~55 caracteres, então quase nunca espera. Interrupção exigiria um buffer circular só para saída. |
| LEDR, LEDG, HEX | Escrita direta | Só saída; não há o que esperar. |

### Logística

| # | Tema | Decisão |
|---|---|---|
| 17 | Grupo | Gustavo Gomes da Cruz, Gustavo Varjão de Frias, Moisés Nascimento Dearo, Vitor Passagem. |
| 18 | Entrega | 03/12/2026 (3 semanas a partir de 12/11). |
| 19 | Testes | Primariamente na placa física; emulador se necessário. |
| 20 | Placa | **DE2-115** (128 MB de SDRAM; a pilha em `0x01000000` é válida). |

---

## 2. Máquina de estados (6.1.2)

```mermaid
stateDiagram-v2
    direction LR

    [*] --> INICIO : T0 - ligar a placa

    INICIO --> JOGANDO : T1 - sempre

    JOGANDO --> JOGANDO : T2 - tick e pos > 1 / apaga HEX[pos], pos--, escreve HEX[pos]
    JOGANDO --> FIM_RODADA : T3 - tick e pos = 1
    JOGANDO --> PAUSADO : T4 - KEY2 e não KEY1 / STOP timer
    JOGANDO --> INICIO : T6 - KEY1

    PAUSADO --> JOGANDO : T5 - KEY2 / START timer
    PAUSADO --> INICIO : T10 - KEY1

    FIM_RODADA --> JOGANDO : T7 - acerto ou vidas > 0 / novo alvo em HEX7
    FIM_RODADA --> FIM_JOGO : T8 - erro e vidas = 0

    FIM_JOGO --> INICIO : T9 - KEY1

    note left of INICIO
        Passagem (sem espera)
        pontos=0, rodada=1, vidas=3
        período=50.000.000 (1 s)
        alvo=lista[0], próximo=lista[1]
        pos=7, limpa flags
        HEX7=alvo, LEDG=111, LEDR=próximo
        programa timer + START
    end note

    note right of JOGANDO
        Prioridade KEY1 > KEY2 > tick
        Todo laço: HEX0 = SW[17:14]
    end note

    note right of PAUSADO
        Tudo congelado (HEX0 incluso)
        Timer guarda o tempo restante
    end note

    note right of FIM_RODADA
        Passagem (sem espera)
        1. apaga HEX1
        2. lê SW e compara com alvo
        3. acerto: pontos++, p = p - p/20, reprograma timer
           erro: vidas--, atualiza LEDG
        4. UART: linha da rodada
        5. rodada++
        6. alvo=próximo, próximo=lista[i++ mod 100], LEDR, pos=7
    end note

    note right of FIM_JOGO
        STOP timer
        HEX = "GO  dddd" (zeros à esquerda)
        UART: linha FIM DE JOGO
        LEDR e LEDG apagados
        KEY2 ignorado
    end note
```

### Estados

#### INICIO (passagem, sem espera)
**Entra:** ao ligar a placa ou com KEY1 (vindo de JOGANDO, PAUSADO ou FIM_JOGO).
**Ações de entrada, nesta ordem:**
1. pontos ← 0, rodada ← 1, vidas ← 3
2. período ← 50.000.000 (1 s)
3. índice da lista ← 0 (toda partida começa no primeiro alvo); alvo ← lista[0], próximo ← lista[1]
4. pos ← 7
5. limpa os flags de KEY1, KEY2 e tick, para que um aperto antigo não vaze para a partida nova
6. apaga HEX7–HEX1 e escreve o alvo em HEX7
7. LEDG ← `00000111` e LEDR ← unário do próximo
8. programa o timer com o período e dá START

**Periféricos:** Timer, HEX, LEDG, LEDR.

#### JOGANDO
**Enquanto está nele:** a cada volta do laço, lê SW[17:14] e escreve em HEX0.
**Eventos, nesta prioridade:** KEY1 → KEY2 → tick.
**Periféricos:** SW (polling), HEX, Timer (IRQ), KEY (IRQ).

#### PAUSADO
**Entrada:** STOP no timer (o contador guarda o tempo restante).
**Enquanto está nele:** nada; HEX0 não atualiza e o alvo não anda.
**Saída:** START no timer (continua do tempo restante).
**Periféricos:** Timer, KEY (IRQ).

#### FIM_RODADA (passagem, sem espera)
**Entra:** o alvo estava em HEX1 e chegou o tick.
**Ações, nesta ordem:**
1. apaga o alvo de HEX1
2. lê SW[17:14] → resposta
3. compara a resposta com o alvo
   - acerto: pontos ← pontos + 1; período ← período − período/20; reprograma o timer
   - erro: vidas ← vidas − 1; atualiza LEDG
4. imprime a linha da rodada na UART (já com pontos e vidas atualizados)
5. rodada ← rodada + 1
6. *(só se o jogo continua)* alvo ← próximo; próximo ← lista[(i++) mod 100]; LEDR ← unário do próximo; pos ← 7; escreve o alvo em HEX7

**Periféricos:** SW, Timer, LEDG, LEDR, HEX, UART (polling).

#### FIM_JOGO
**Ações de entrada:**
1. STOP no timer
2. HEX7–HEX0 ← `G O _ _ d d d d`
3. UART: `=== FIM DE JOGO === Pontuacao final: … | Sequencia: …`
4. apaga LEDR e LEDG

**Enquanto está nele:** nada; HEX0 deixa de mostrar SW.
**Periféricos:** HEX, Timer, UART, LEDR, LEDG, KEY (IRQ).

### Transições

| # | De → Para | Condição | Ação |
|---|---|---|---|
| T0 | ● → INICIO | ligar a placa | — |
| T1 | INICIO → JOGANDO | sempre | — |
| T2 | JOGANDO → JOGANDO | tick e pos > 1 | apaga HEX[pos]; pos ← pos − 1; escreve o alvo em HEX[pos] |
| T3 | JOGANDO → FIM_RODADA | tick e pos = 1 | — |
| T4 | JOGANDO → PAUSADO | KEY2 e não KEY1 | STOP no timer |
| T5 | PAUSADO → JOGANDO | KEY2 | START no timer |
| T6 | JOGANDO → INICIO | KEY1 | — |
| T7 | FIM_RODADA → JOGANDO | acerto, ou vidas > 0 depois do erro | novo alvo em HEX7 |
| T8 | FIM_RODADA → FIM_JOGO | erro e vidas = 0 depois do erro | — |
| T9 | FIM_JOGO → INICIO | KEY1 | — |
| T10 | PAUSADO → INICIO | KEY1 | — (o INICIO refaz tudo, inclusive o START do timer) |

Observações:
- T7 e T8 são complementares: uma das duas sempre acontece ao sair de FIM_RODADA.
- O alvo faz T2 seis vezes (7 → 1) e depois T3: são 7 períodos para o jogador acertar.
- No PAUSADO o tick nem chega, porque o timer está parado; KEY1 reinicia (T10). No FIM_JOGO, KEY2 e tick são ignorados.

---

## 3. Cronograma (6.1.3)

Ver [`cronograma.md`](cronograma.md).
