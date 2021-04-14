library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;


entity slidingWindowMaximum is
generic (WINDOWSIZE, DATAWIDTH: integer);
port (
    -- Inputs
    clk : in std_logic;
    rst : in std_logic;
    inputNumber : in std_logic_vector(DATAWIDTH-1 downto 0);
    -- Outputs
    max : out std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');
    maxValid : out std_logic := '0');
end entity;


architecture rtl of slidingWindowMaximum is

    type mem is array(WINDOWSIZE-1 downto 0) of std_logic_vector(DATAWIDTH-1 downto 0);
    signal countInput : integer range 0 to WINDOWSIZE-1 := 0;
    signal internalValid : std_logic := '0';
    signal memory: mem;

begin

    maxValid <= internalValid; -- Assign to output signal

    memory <= memory(WINDOWSIZE-2 downto 0) & inputNumber; -- Shift the window

    process (clk)

        variable tempMax : std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');

    begin

        if rising_edge(clk) then

            if rst = '1' then
                internalValid <= '0';
                max <= (others => '0');
            else
                if countInput = WINDOWSIZE or internalValid = '1' then
                    internalValid <= '1'; -- Set maximum valid
                    for i in 0 to WINDOWSIZE-1 loop
                        if memory(i) > tempMax then
                            tempMax := memory(i);
                        end if;
                    end loop;
                else
                    countInput <= countInput + 1; -- Increment counter
                end if;
                max <= tempMax; -- Assign to output signal
            end if;

        end if;

    end process;

end architecture;
