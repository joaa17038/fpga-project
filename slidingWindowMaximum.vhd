library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;


entity slidingWindowMaximum is
generic(WINDOWSIZE: Integer);
port (
    -- Inputs
    clk : in std_logic;
    rst : in std_logic;
    inputNumber : in std_logic_vector(7 downto 0);
    -- Output
    max : out std_logic_vector(7 downto 0);
    maxValid : out std_logic);
end entity;


architecture rtl of slidingWindowMaximum is

    signal countInput : integer range 0 to WINDOWSIZE-1 := 0;
    signal internalValid : std_logic;

begin

    process (clk)

        variable tempMax : std_logic_vector(7 downto 0) := (others => '0');
        type mem is array(WINDOWSIZE-1 downto 0) of std_logic_vector(7 downto 0);
        variable memory : mem;

    begin

        if rising_edge(clk) then

            if rst = '1' then
                internalValid <= '0';
                max <= (others => '0');
                maxValid <= '0';
            else
                memory := memory(WINDOWSIZE-2 downto 0) & inputNumber;

                if countInput = WINDOWSIZE then
                    internalValid <= '1';
                    for i in 0 to WINDOWSIZE-1 loop
                        if memory(i) > tempMax then
                            tempMax := memory(i);
                        end if;
                    end loop;
                else
                    countInput <= countInput + 1;
                end if;

                if internalValid = '1' and inputNumber > tempMax then
                    tempMax := inputNumber;
                end if;

                max <= tempMax;
                maxValid <= internalValid;
            end if;

        end if;

    end process;

end architecture;
