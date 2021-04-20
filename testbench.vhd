library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;


entity testbench is
end entity;

architecture sim of testbench is

    constant WINDOWSIZE : integer := 4;
    constant DATAWIDTH : integer := 8;

    signal clk : std_logic := '1';
    signal rst: std_logic := '1';

    signal m_axi_data : std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');
    signal m_axi_valid: std_logic := '0';
    signal m_axi_ready: std_logic := '0';
    signal m_axi_last: std_logic := '0';

    signal s_axi_data : std_logic_vector(DATAWIDTH-1 downto 0);
    signal s_axi_valid : std_logic;
    signal s_axi_ready : std_logic;

    signal assertion : std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');

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

        file read_file : text is in "./simulation.in";
        variable line_v : line;
        variable input_from_file : std_logic_vector(DATAWIDTH-1 downto 0);

        file read_file2 : text is in "./assertion.in";
        variable line_v2 : line;
        variable input_from_file2 : std_logic_vector(DATAWIDTH-1 downto 0);

        variable start : integer := 1;
        variable count : integer := 0;

    begin

        wait until clk'event and clk='1';

        if rst = '1' then
            m_axi_data <= (others => '0');
            m_axi_valid <= '0';
            m_axi_ready <= '0';
            m_axi_last <= '0';

        else
            if start = 1 then
                start := 0;
                m_axi_ready <= '1';
            end if;

            if not endfile(read_file) and s_axi_ready = '1' then
                m_axi_valid <= '1';
                readline(read_file, line_v);
                hread(line_v, input_from_file);
                m_axi_data <= input_from_file;
                count := count + 1; -- testing m_axi_last
            elsif endfile(read_file) then
                count := 0;
                m_axi_ready <= '0';
                m_axi_last <= '0';
                m_axi_valid <= '0';
                m_axi_data <= (others => '0');
            end if;

            if count = 25 then
                m_axi_last <= '1';
            end if;

            if not endfile(read_file2) then
                readline(read_file2, line_v2);
                hread(line_v2, input_from_file2);
                assertion <= input_from_file2;
                assert s_axi_data = input_from_file2 report "Max Value Incorrect " & integer'image(to_integer(unsigned(s_axi_data))) & " /= " & integer'image(to_integer(unsigned(assertion)));
            else
                assertion <= (others => '0');
            end if;

        end if;

    end process;

    i_SlidingWindowMaximumV3 : entity work.slidingWindowMaximumV3(rtl)
    generic map (
        WINDOWSIZE => WINDOWSIZE,
        DATAWIDTH => DATAWIDTH)
    port map (
        clk => clk,
        rst => rst,
        m_axi_data => m_axi_data,
        m_axi_valid => m_axi_valid,
        m_axi_ready => m_axi_ready,
        m_axi_last => m_axi_last,
        s_axi_data => s_axi_data,
        s_axi_valid => s_axi_valid,
        s_axi_ready => s_axi_ready);

--    i_SlidingWindowMaximum1 : entity work.slidingWindowMaximum(rtl)
--    generic map (
--        WINDOWSIZE => WINDOWSIZE,
--        DATAWIDTH => DATAWIDTH)
--    port map (
--        clk => clk,
--        rst => rst,
--        inputNumber => m_axi_data,
--        max => s_axi_data,
--        maxValid => s_axi_valid);

--    i_SlidingWindowMaximumV2 : entity work.slidingWindowMaximumV2(rtl)
--    generic map (
--        WINDOWSIZE => WINDOWSIZE,
--        DATAWIDTH => DATAWIDTH)
--    port map (
--        clk => clk,
--        rst => rst,
--        inputNumber => m_axi_data,
--        max => s_axi_data,
--        maxValid => s_axi_valid);

--    i_CountBits1 : entity work.countBits(rtl)
--    generic map (
--        DATAWIDTH => DATAWIDTH)
--    port map (
--        clk => clk,
--        rst => rst,
--        inputNumber => m_axi_data,
--        ones => s_axi_data);

end architecture;
