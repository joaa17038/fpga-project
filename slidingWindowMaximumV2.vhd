library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;


entity slidingWindowMaximumV2 is
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


architecture rtl of slidingWindowMaximumV2 is

    type mem is array(0 to WINDOWSIZE-1) of std_logic_vector(DATAWIDTH-1 downto 0);
    signal firstMax : std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');
    signal secondMax : std_logic_vector(DATAWIDTH-1 downto 0) := (others => '0');
    signal count : integer range 0 to WINDOWSIZE-1 := 0;
    signal internalValid : std_logic := '0';
    signal memory: mem;

begin

    max <= firstMax when internalValid = '1';
    
    maxValid <= internalValid;

    process (clk) begin

        if rising_edge(clk) then

            if rst = '1' then
                firstMax <= (others => '0');
                secondMax <= (others => '0');
            else
                memory <= memory(1 to WINDOWSIZE-1) & inputNumber;
                
                if inputNumber > firstMax then
                    secondMax <= firstMax;
                    firstMax <= inputNumber;
                elsif inputNumber > secondMax then
                    secondMax <= inputNumber;
                end if;

                if secondMax = memory(0) then
                    secondMax <= (others => '0');
                elsif firstMax = memory(0) then
                    firstMax <= secondMax;
                    secondMax <= (others => '0');
                end if;

                if count = WINDOWSIZE then
                    internalValid <= '1';
                else
                    count <= count + 1;
                end if;
            end if;

        end if;

    end process;

end architecture;
