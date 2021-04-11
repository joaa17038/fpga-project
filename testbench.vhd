library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;


entity testbench is
end entity;

architecture behavioral of testbench is

    signal clk : std_logic := '1';
    signal rst: std_logic := '1';
    signal inputNumber : std_logic_vector(7 downto 0) := (others => '0');
    signal max : std_logic_vector(7 downto 0) := (others => '0');
    signal ones : std_logic_vector(7 downto 0) := (others => '0');
    signal maxValid : std_logic := '0';

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
        variable input_from_file : std_logic_vector(7 downto 0);

    begin

        wait until clk'event and clk='1';

        if rst = '1' then
            inputNumber <= (others => '0');
        else
            if not endfile(read_file) then
                readline(read_file, line_v);
                hread(line_v, input_from_file);
                inputNumber <= input_from_file;
            end if;
        end if;

    end process;

    i_SlidingWindowMaximum : entity work.slidingWindowMaximum(rtl)
    generic map(WINDOWSIZE => 4)
    port map (
        clk => clk,
        rst => rst,
        inputNumber => inputNumber,
        max => max,
        maxValid => maxValid);

    i_CountBits : entity work.countBits(rtl)
    port map (
        clk => clk,
        rst => rst,
        inputNumber => inputNumber,
        ones => ones);

end architecture;
