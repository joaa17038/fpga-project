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
    constant MAXIMAGEWIDTH : integer := 128;
    constant MAXIMAGEHEIGHT : integer := 2160;

    signal clk : std_logic := '1';
    signal rst : std_logic := '1';

    signal sim_data : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
    signal sim_data2 : std_logic_vector(23 downto 0);
    signal assertRow : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
    signal sim_valid: std_logic;
    signal sim_valid2 : std_logic;
    signal sim_ready : std_logic;
    signal sim_ready2 : std_logic;
    signal sim_last : std_logic;

    signal module_data : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
    signal module_valid : std_logic;
    signal module_ready : std_logic;
    signal module_ready2 : std_logic;
    signal module_last : std_logic;

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
            sim_data <= (others => '0');
            sim_data2 <= (others => '0');
            assertRow <= (others => '0');
            sim_valid <= '0';
            sim_valid2 <= '0';
            module_ready <= '0';
            module_ready2 <= '1';
            sim_last <= '0';

        else
            -- Second Stream
            sim_data2 <= X"000000";
            sim_valid2 <= '0';
            module_ready2 <= '0';
            if sim_ready2 = '1' and module_ready2 = '1' then
                sim_data2 <= X"040040"; -- HEIGHT:WIDTH
                sim_valid2 <= '1';
                module_ready2 <= '1';
                module_ready <= '1';
            end if;
            
            -- First Stream
            --module_ready <= not module_ready;
            sim_last <= '0';
            if not endfile(simulationFile) and module_ready = '1' and sim_ready = '1' then
                readline(simulationFile, line_v);
                hread(line_v, simulation);
                sim_data <= simulation;
                sim_valid <= '1';
                if endfile(simulationFile) then
                    sim_last <= '1';
                end if;
            elsif endfile(simulationFile) then
                sim_valid <= '0';
                sim_data <= (others => '0');
            end if;

            if not endfile(assertionFile) and module_ready = '1' and sim_ready = '0' then
                readline(assertionFile, line_v2);
                hread(line_v2, assertion);
                assertRow <= assertion;
                assert module_data = assertRow report "Incorrect " & integer'image(to_integer(unsigned(module_data))) & " /= " & integer'image(to_integer(unsigned(assertRow)));
            elsif endfile(assertionFile) then
                assertRow <= (others => '0');
            end if;

        end if;

    end process;

    i_SlidingBlurFilterV1 : entity work.slidingBlurFilterV1(rtl)
    generic map (
        PIXELSIZE => PIXELSIZE,
        PACKETSIZE => PACKETSIZE,
        MAXIMAGEWIDTH => MAXIMAGEWIDTH,
        MAXIMAGEHEIGHT => MAXIMAGEHEIGHT)
    port map (
        clk => clk,
        rst => rst,
        s_axi_valid => sim_valid,
        s_axi_ready => sim_ready,
        s_axi_data => sim_data,
        s_axi_last => sim_last,
        m_axi_valid => module_valid,
        m_axi_ready => module_ready,
        m_axi_last => module_last,
        m_axi_data => module_data,
        s_axi_valid2 => sim_valid2,
        s_axi_ready2 => sim_ready2,
        s_axi_data2 => sim_data2,
        m_axi_ready2 => module_ready2);

end architecture;
