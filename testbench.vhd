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
    signal inputNumber : std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');

    signal max : std_logic_vector(DATAWIDTH-1 downto 0);
    --signal ones : std_logic_vector(DATAWIDTH-1 downto 0);
    signal maxValid : std_logic;
    
    signal assertNumber : std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');

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

    begin

        wait until clk'event and clk='1';

        if rst = '1' then
            inputNumber <= (others => '0');
        else
            if not endfile(read_file) then
                readline(read_file, line_v);
                hread(line_v, input_from_file);
                inputNumber <= input_from_file;
            else
                inputNumber <= (others => '0');
            end if;
            
            if not endfile(read_file2) then
                readline(read_file2, line_v2);
                hread(line_v2, input_from_file2);
                assertNumber <= input_from_file2;
                assert max = input_from_file2 report "Max Value Incorrect " & integer'image(to_integer(unsigned(max))) & " /= " & integer'image(to_integer(unsigned(input_from_file2)));
            else
                assertNumber <= (others => '0');
            end if;
        end if;

    end process;

--    i_SlidingWindowMaximum1 : entity work.slidingWindowMaximum(rtl)
--    generic map (
--        WINDOWSIZE => WINDOWSIZE,
--        DATAWIDTH => DATAWIDTH)
--    port map (
--        clk => clk,
--        rst => rst,
--        inputNumber => inputNumber,
--        max => max,
--        maxValid => maxValid);

    i_SlidingWindowMaximumV2 : entity work.slidingWindowMaximumV2(rtl)
    generic map (
        WINDOWSIZE => WINDOWSIZE,
        DATAWIDTH => DATAWIDTH)
    port map (
        clk => clk,
        rst => rst,
        inputNumber => inputNumber,
        max => max,
        maxValid => maxValid);

--    i_CountBits1 : entity work.countBits(rtl)
--    generic map (
--        DATAWIDTH => DATAWIDTH)
--    port map (
--        clk => clk,
--        rst => rst,
--        inputNumber => inputNumber,
--        ones => ones);

end architecture;
