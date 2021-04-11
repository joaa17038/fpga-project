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
    max_valid : out std_logic);
end entity;


architecture rtl of generic_maximum is

    signal idx : integer range 0 to WINDOWSIZE-1 := 0;
    signal internal_valid : std_logic;

begin

    process (clk)
    
        variable tempMax : std_logic_vector(7 downto 0) := (others => '0');
        type mem is array(WINDOWSIZE-1 downto 0) of std_logic_vector(7 downto 0);
        variable memory : mem;
    
    begin

        if rising_edge(clk) then
        
            if rst = '1' then
                idx <= 0;
                internal_valid <= '0';
                max <= (others => '0');
                max_valid <= '0';
            else   
                memory(idx) := inputNumber;
                if idx = WINDOWSIZE-2 then
                    idx <= 1;
                    internal_valid <= '1';
                else
                    idx <= idx + 1;
                end if;
                
                if internal_valid = '1' then
                    tempMax := (others => '0');
                    for i in 0 to WINDOWSIZE-1 loop
                        if memory(i) > tempMax then
                            tempMax := memory(i);
                        end if;
                    end loop;
                end if;
                max <= tempMax;
                max_valid <= internal_valid;
            end if;

        end if;

    end process;

end architecture;
