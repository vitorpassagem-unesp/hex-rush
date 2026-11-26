-------------------------------------------------------------------------------
-- HexRush - Maquina de estados finitos do jogo (modelo de referencia)
--
-- O jogo e implementado em assembly Nios II; este VHDL descreve a mesma FSM
-- de forma formal, para documentar o comportamento no relatorio. Cada sinal
-- de entrada corresponde a algo que o software observa:
--   key1, key2 -> flags levantados pela ISR dos push buttons
--   tick       -> flag levantado pela ISR do timer (1 por periodo de passo)
--   sw         -> leitura (polling) de SW[17:14]
--   alvo       -> valor atual da lista de alvos
-- Cada saida de controle corresponde a uma sub-rotina que o laco principal
-- chama naquele estado.
--
-- Decisoes ainda PENDENTES estao marcadas com "PENDENTE".
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hexrush_fsm is
  generic (
    G_VIDAS_INICIAIS : natural := 3;      -- decidido: 3 vidas
    G_POS_INICIAL    : natural := 7;      -- alvo nasce em HEX7
    -- PENDENTE (pergunta 1): KEY1 reinicia durante a pausa?
    G_KEY1_NA_PAUSA  : boolean := false
  );
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;                     -- ligar a placa
    key1          : in  std_logic;                     -- pulso de 1 ciclo
    key2          : in  std_logic;                     -- pulso de 1 ciclo
    tick          : in  std_logic;                     -- pulso de 1 ciclo
    sw            : in  std_logic_vector(3 downto 0);  -- SW[17:14]
    alvo          : in  std_logic_vector(3 downto 0);  -- alvo atual

    -- estado e registradores do jogo (para exibicao)
    estado_dbg    : out std_logic_vector(2 downto 0);
    pos_alvo      : out unsigned(2 downto 0);   -- 7..1 = HEX7..HEX1
    vidas         : out unsigned(3 downto 0);   -- LEDG em unario
    pontos        : out unsigned(13 downto 0);  -- ate 9999 (GO  XXXX)
    rodada        : out unsigned(13 downto 0);

    -- comandos para o "datapath" (sub-rotinas no software)
    timer_run     : out std_logic;  -- timer contando
    timer_reload  : out std_logic;  -- (re)programa o periodo no timer
    reduz_periodo : out std_logic;  -- p := p - p/20 (antes do reload)
    proximo_alvo  : out std_logic;  -- alvo := proximo; proximo := lista[i++]
    reinicia_lista: out std_logic;  -- PENDENTE (D): KEY1 volta ao inicio?
    mostra_sw     : out std_logic;  -- HEX0 acompanha SW continuamente
    uart_rodada   : out std_logic;  -- imprime "Rodada XX | Alvo ..."
    uart_fim      : out std_logic;  -- imprime "=== FIM DE JOGO ==="
    mostra_go     : out std_logic;  -- HEX7..HEX0 = "GO  XXXX"
    acerto_dbg    : out std_logic
  );
end entity hexrush_fsm;

architecture rtl of hexrush_fsm is

  type t_estado is (S_INICIO, S_JOGANDO, S_PAUSADO, S_FIM_RODADA, S_FIM_JOGO);
  signal estado, prox : t_estado;

  signal r_pos    : unsigned(2 downto 0);
  signal r_vidas  : unsigned(3 downto 0);
  signal r_pontos : unsigned(13 downto 0);
  signal r_rodada : unsigned(13 downto 0);
  signal acerto   : std_logic;

begin

  -- A comparacao so tem efeito em S_FIM_RODADA (alvo chegou em HEX0):
  -- e o unico instante em que o valor das chaves conta como resposta.
  acerto <= '1' when sw = alvo else '0';

  -----------------------------------------------------------------------------
  -- Logica de proximo estado
  -- Prioridade KEY1 > KEY2 > tick: reiniciar deve vencer qualquer outro
  -- evento que chegue no mesmo instante.
  -----------------------------------------------------------------------------
  p_prox : process (estado, key1, key2, tick, r_pos, r_vidas, acerto)
  begin
    prox <= estado;
    case estado is

      when S_INICIO =>
        prox <= S_JOGANDO;                 -- jogo comeca sem esperar KEY1

      when S_JOGANDO =>
        if key1 = '1' then
          prox <= S_INICIO;
        elsif key2 = '1' then
          prox <= S_PAUSADO;
        elsif tick = '1' and r_pos = 1 then
          prox <= S_FIM_RODADA;            -- leitura (a): passo apos HEX1
        end if;

      when S_PAUSADO =>
        if key1 = '1' and G_KEY1_NA_PAUSA then
          prox <= S_INICIO;
        elsif key2 = '1' then
          prox <= S_JOGANDO;
        end if;

      when S_FIM_RODADA =>
        -- r_vidas ainda e o valor antigo: errar com 1 vida = fim de jogo
        if acerto = '0' and r_vidas = 1 then
          prox <= S_FIM_JOGO;
        else
          prox <= S_JOGANDO;               -- novo alvo surge imediatamente
        end if;

      when S_FIM_JOGO =>
        if key1 = '1' then                 -- KEY2 ignorado (PENDENTE, pergunta 2)
          prox <= S_INICIO;
        end if;

    end case;
  end process p_prox;

  -----------------------------------------------------------------------------
  -- Registradores de estado e do jogo
  -----------------------------------------------------------------------------
  p_regs : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        estado   <= S_INICIO;
        r_pos    <= to_unsigned(G_POS_INICIAL, 3);
        r_vidas  <= to_unsigned(G_VIDAS_INICIAIS, 4);
        r_pontos <= (others => '0');
        r_rodada <= to_unsigned(1, 14);
      else
        estado <= prox;

        case estado is
          when S_INICIO =>
            r_pos    <= to_unsigned(G_POS_INICIAL, 3);
            r_vidas  <= to_unsigned(G_VIDAS_INICIAIS, 4);
            r_pontos <= (others => '0');
            r_rodada <= to_unsigned(1, 14);

          when S_JOGANDO =>
            -- so anda se nenhum botao tem prioridade neste ciclo
            if key1 = '0' and key2 = '0' and tick = '1' and r_pos > 1 then
              r_pos <= r_pos - 1;
            end if;

          when S_FIM_RODADA =>
            if acerto = '1' then
              r_pontos <= r_pontos + 1;    -- decidido: 1 ponto por acerto
            else
              r_vidas  <= r_vidas - 1;
            end if;
            r_rodada <= r_rodada + 1;
            r_pos    <= to_unsigned(G_POS_INICIAL, 3);

          when others =>
            null;                          -- PAUSADO e FIM_JOGO congelam tudo
        end case;
      end if;
    end if;
  end process p_regs;

  -----------------------------------------------------------------------------
  -- Saidas
  -----------------------------------------------------------------------------
  timer_run      <= '1' when estado = S_JOGANDO or estado = S_FIM_RODADA else '0';
  timer_reload   <= '1' when estado = S_INICIO
                         or (estado = S_FIM_RODADA and acerto = '1') else '0';
  reduz_periodo  <= '1' when estado = S_FIM_RODADA and acerto = '1' else '0';
  proximo_alvo   <= '1' when estado = S_FIM_RODADA else '0';
  reinicia_lista <= '1' when estado = S_INICIO else '0';
  -- Na pausa HEX0 congela (decidido); no fim de jogo HEX0 vira digito do placar.
  mostra_sw      <= '1' when estado = S_JOGANDO or estado = S_FIM_RODADA else '0';
  -- A linha da UART usa pontos/vidas ja atualizados: o modulo da UART
  -- amostra os registradores no ciclo seguinte (no software: atualizar
  -- antes de imprimir).
  uart_rodada    <= '1' when estado = S_FIM_RODADA else '0';
  uart_fim       <= '1' when estado = S_FIM_RODADA and prox = S_FIM_JOGO else '0';
  mostra_go      <= '1' when estado = S_FIM_JOGO else '0';
  acerto_dbg     <= acerto;

  with estado select estado_dbg <=
    "000" when S_INICIO,
    "001" when S_JOGANDO,
    "010" when S_PAUSADO,
    "011" when S_FIM_RODADA,
    "100" when S_FIM_JOGO;

  pos_alvo <= r_pos;
  vidas    <= r_vidas;
  pontos   <= r_pontos;
  rodada   <= r_rodada;

end architecture rtl;
