library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;


entity testbench is
end entity;

architecture sim of testbench is

    constant PIXELSIZE : integer := 8;
    constant PACKETSIZE : integer := 64;

    signal clk : std_logic := '1';
    signal rst: std_logic := '1';

    signal m_axi_data : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0) := (others => '0');
    signal m_axi_dim : std_logic_vector(23 downto 0) := (others => '0');
    signal assertRow : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0) := (others => '0');
    signal m_axi_valid: std_logic := '0';
    signal m_axi_ready: std_logic;
    signal m_axi_last: std_logic := '0';

    signal s_axi_data : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
    signal s_axi_valid : std_logic;
    signal s_axi_ready : std_logic := '1';
    signal s_axi_last : std_logic;

begin

    process begin
        clk <= not clk;
        wait for 10ns;
    end process;

    process begin
        wait for 40ns;
        rst <= '0';
    end process;

    process

        file simulationFile : text is in "./simulation.in";
        variable line_v : line;
        variable simulation : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);

        file assertionFile : text is in "./assertion.in";
        variable line_v2 : line;
        variable assertion : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);

    begin

        wait until clk'event and clk='1';

        if rst = '1' then
            m_axi_data <= (others => '0');
            m_axi_valid <= '0';
            s_axi_ready <= '1';
            m_axi_last <= '0';

        else
            if not endfile(simulationFile) and m_axi_ready = '1' then
                readline(simulationFile, line_v);
                hread(line_v, simulation);
                m_axi_data <= simulation;
                m_axi_valid <= '1';
                m_axi_dim <= X"040040"; -- HEIGHT:WIDTH
                if endfile(simulationFile) then
                    m_axi_last <= '1';
                end if;
            else
                m_axi_valid <= '0';
                m_axi_last <= '0';
                m_axi_dim <= (others => '0');
                m_axi_data <= (others => '0');
            end if;

            if not endfile(assertionFile) then
                readline(assertionFile, line_v2);
                hread(line_v2, assertion);
                assertRow <= assertion;
            else
                assertRow <= (others => '0');
            end if;

        end if;

    end process;

    i_SlidingBlurFilterV1 : entity work.slidingBlurFilterV1(rtl)
    generic map (
        PIXELSIZE => PIXELSIZE,
        PACKETSIZE => PACKETSIZE)
    port map (
        clk => clk,
        rst => rst,
        s_axi_valid => m_axi_valid,
        s_axi_ready => m_axi_ready,
        s_axi_data => m_axi_data,
        s_axi_dim => m_axi_dim,
        s_axi_last => m_axi_last,
        m_axi_valid => s_axi_valid,
        m_axi_ready => s_axi_ready,
        m_axi_last => s_axi_last,
        m_axi_data => s_axi_data);

end architecture;
