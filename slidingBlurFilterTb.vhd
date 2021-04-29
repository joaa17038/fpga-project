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
    constant MAXIMAGEWIDTH : integer := 3840; -- supports 64, 128, 192, 256, 320, 3840
    constant MAXIMAGEHEIGHT : integer := 2160;

    signal clk : std_logic := '1';
    signal rst : std_logic := '1';

    signal sim_pixels_data : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
    signal sim_pixels_valid: std_logic;
    signal sim_pixels_ready : std_logic;
    signal sim_pixels_last : std_logic;

    signal one_pixels_data : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
    signal filterTruth1 : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
    signal one_pixels_valid : std_logic;
    signal one_pixels_ready : std_logic;
    signal one_pixels_last : std_logic;

    signal two_pixels_data : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
    signal filterTruth2 : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
    signal two_pixels_valid: std_logic;
    signal two_pixels_last : std_logic;
    signal two_pixels_ready : std_logic;

    signal sim_dimensions_data : std_logic_vector(23 downto 0);
    signal sim_dimensions_ready_one : std_logic;
    signal sim_dimensions_ready_two : std_logic;
    signal one_dimensions_ready : std_logic;
    signal sim_dimensions_valid : std_logic;

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

        file assertionFileOne : text is in "./assertionOne.in";
        variable line_v2 : line;
        variable assertionOne : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);
        
        file assertionFileTwo : text is in "./assertionTwo.in";
        variable line_v3 : line;
        variable assertionTwo : std_logic_vector(PACKETSIZE*PIXELSIZE-1 downto 0);

    begin

        wait until clk'event and clk='1';

        if rst = '1' then
            sim_pixels_data <= (others => '0');
            sim_dimensions_data <= (others => '0');
            filterTruth1 <= (others => '0');
            filterTruth2 <= (others => '0');
            sim_pixels_valid <= '0';
            sim_dimensions_valid <= '0';
            two_pixels_ready <= '0';
            --one_pixels_ready <= '0'; -- changed by module instance 2
            one_dimensions_ready <= '1';
            sim_pixels_last <= '0';

        else
            -- Second Stream
            sim_dimensions_data <= X"000000";
            sim_dimensions_valid <= '0';
            one_dimensions_ready <= '0';
            if (sim_dimensions_ready_one = '1' and one_dimensions_ready = '1' and sim_dimensions_ready_two = '1') then
                sim_dimensions_data <= X"080080"; -- HEIGHT:WIDTH, 040040, 080080, 0C00C0, 100100, 140140, F00F00
                sim_dimensions_valid <= '1';
                one_dimensions_ready <= '1';
                two_pixels_ready <= '1';
                --one_pixels_ready <= '1'; -- changed by module instance 2
            end if;

            -- First Stream
            --one_ready <= not one_ready; -- changed by module instance 2
            --two_pixels_ready <= not two_pixels_ready;
            if not endfile(simulationFile) and one_pixels_ready = '1' and sim_pixels_ready = '1' then
                readline(simulationFile, line_v);
                hread(line_v, simulation);
                sim_pixels_data <= simulation;
                sim_pixels_valid <= '1';
                if endfile(simulationFile) then
                    sim_pixels_last <= '1';
                end if;
            elsif endfile(simulationFile) and one_pixels_ready = '1' and sim_pixels_ready = '1' then
                sim_pixels_valid <= '0';
                sim_pixels_data <= (others => '0');
                sim_pixels_last <= '0';
            end if;

            if not endfile(assertionFileOne) and one_pixels_ready = '1' and sim_pixels_ready = '0' then
                readline(assertionFileOne, line_v2);
                hread(line_v2, assertionOne);
                filterTruth1 <= assertionOne;
                assert one_pixels_data = filterTruth1 report "Incorrect " & integer'image(to_integer(unsigned(one_pixels_data))) & " /= " & integer'image(to_integer(unsigned(filterTruth1)));
            elsif endfile(assertionFileOne) and one_pixels_ready = '1' and sim_pixels_ready = '1' then
                filterTruth1 <= (others => '0');
            end if;
            
            if not endfile(assertionFileTwo) and two_pixels_ready = '1' and one_pixels_ready = '0' and sim_pixels_ready = '1' then
                readline(assertionFileTwo, line_v3);
                hread(line_v3, assertionTwo);
                filterTruth2 <= assertionTwo;
                assert two_pixels_data = filterTruth2 report "Incorrect " & integer'image(to_integer(unsigned(two_pixels_data))) & " /= " & integer'image(to_integer(unsigned(filterTruth2)));
            elsif endfile(assertionFileTwo) and two_pixels_ready = '1' and one_pixels_ready = '1' then
                filterTruth2 <= (others => '0');
            end if;

        end if;

    end process;

    i_SlidingBlurFilter1 : entity work.slidingBlurFilterV1(rtl)
    generic map (
        PIXELSIZE => PIXELSIZE,
        PACKETSIZE => PACKETSIZE,
        MAXIMAGEWIDTH => MAXIMAGEWIDTH,
        MAXIMAGEHEIGHT => MAXIMAGEHEIGHT)
    port map (
        clk => clk,
        rst => rst,
        s_axi_pixels_valid => sim_pixels_valid,
        s_axi_pixels_ready => sim_pixels_ready,
        s_axi_pixels_data => sim_pixels_data,
        s_axi_pixels_last => sim_pixels_last,

        m_axi_pixels_valid => one_pixels_valid,
        m_axi_pixels_ready => one_pixels_ready,
        m_axi_pixels_last => one_pixels_last,
        m_axi_pixels_data => one_pixels_data,

        s_axi_dimensions_valid => sim_dimensions_valid,
        s_axi_dimensions_ready => sim_dimensions_ready_one,
        s_axi_dimensions_data => sim_dimensions_data,
        m_axi_dimensions_ready => one_dimensions_ready);

    i_SlidingBlurFilter2 : entity work.slidingBlurFilterV1(rtl)
    generic map (
        PIXELSIZE => PIXELSIZE,
        PACKETSIZE => PACKETSIZE,
        MAXIMAGEWIDTH => MAXIMAGEWIDTH,
        MAXIMAGEHEIGHT => MAXIMAGEHEIGHT)
    port map (
        clk => clk,
        rst => rst,
        s_axi_pixels_valid => one_pixels_valid,
        s_axi_pixels_ready => one_pixels_ready,
        s_axi_pixels_data => one_pixels_data,
        s_axi_pixels_last => one_pixels_last,

        m_axi_pixels_valid => two_pixels_valid,
        m_axi_pixels_ready => two_pixels_ready,
        m_axi_pixels_last => two_pixels_last,
        m_axi_pixels_data => two_pixels_data,

        s_axi_dimensions_valid => sim_dimensions_valid,
        s_axi_dimensions_ready => sim_dimensions_ready_two,
        s_axi_dimensions_data => sim_dimensions_data,
        m_axi_dimensions_ready => one_dimensions_ready);

end architecture;
