library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;


entity slidingWindowMaximumV3 is
generic (WINDOWSIZE, DATAWIDTH: integer);
port (
    clk : in std_logic;
    rst : in std_logic;

    m_axi_valid : in std_logic;
    m_axi_ready : in std_logic;
    m_axi_data : in std_logic_vector(DATAWIDTH-1 downto 0);
    m_axi_last : in std_logic;

    s_axi_valid : out std_logic := '0';
    s_axi_data : out std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');
    s_axi_ready : out std_logic := '0');
end entity;


architecture rtl of slidingWindowMaximumV3 is

    type typeState is (idle, receive, send);
    type typeMemory is array(0 to WINDOWSIZE-1) of std_logic_vector(DATAWIDTH-1 downto 0);

    signal firstMax : std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');
    signal secondMax : std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');
    signal s_axi_last1 : std_logic := '0';
    signal s_axi_last2 : std_logic := '0';
    signal count : integer range 0 to WINDOWSIZE-1 := 0;
    signal state : typeState := IDLE;
    signal memory: typeMemory;

begin

    process (clk)

            procedure evaluateMaximum is
            begin
                if secondMax = memory(0) and m_axi_data < firstMax and firstMax /= memory(0) then
                    secondMax <= m_axi_data;
                elsif secondMax <= memory(0) then
                    secondMax <= (others => '0');
                end if;

                if firstMax = memory(0) then
                    if secondMax > m_axi_data and secondMax /= memory(0) then
                        firstMax <= secondMax;
                    else
                        firstMax <= m_axi_data;
                    end if;
                elsif firstMax /= memory(0) and m_axi_data > firstMax then
                    if firstMax > secondMax then
                        secondMax <= firstMax;
                        firstMax <= m_axi_data;
                    else
                        firstMax <= m_axi_data;
                    end if;
                end if;
            end procedure;

    begin

        if rising_edge(clk) then

            if rst = '1' then
                state <= IDLE;
                s_axi_ready <= '0';
                s_axi_valid <= '0';
                s_axi_data <= (others => '0');

            else
                case state is
                    when IDLE =>
                        s_axi_ready <= '1';
                        -- maybe reset signals
                        if m_axi_ready = '1' then --and count /= WINDOWSIZE then
                            state <= RECEIVE;
--                        elsif m_axi_valid = '1' and m_axi_ready = '1' and count = WINDOWSIZE then
--                            state <= SEND;
--                        else
--                            state <= IDLE;
                        end if;

                    when RECEIVE =>
                        memory <= memory(1 to WINDOWSIZE-1) & m_axi_data;
                        evaluateMaximum;

                        if count = WINDOWSIZE-1 then
                            state <= SEND;
                        else
                            count <= count + 1;
                        end if;

                    when SEND =>
                        memory <= memory(1 to WINDOWSIZE-1) & m_axi_data;
                        evaluateMaximum;
                        
                        if m_axi_last = '1' then
                            s_axi_data <= firstMax;
                            s_axi_ready <= '0';
                            s_axi_last1 <= '1';
                        elsif s_axi_last1 = '1' then
                            s_axi_data <= firstMax;
                            s_axi_ready <= '0';
                            s_axi_last1 <= '0';
                            s_axi_last2 <= '1';
                        elsif s_axi_last2 = '1' then
                            s_axi_last2 <= '0';
                            s_axi_valid <= '0';
                            s_axi_data <= (others => '0');
                            state <= IDLE;
                        else
                            s_axi_valid <= '1';
                            s_axi_data <= firstMax;
                        end if;

                end case;

            end if;

        end if;

    end process;

end architecture;
