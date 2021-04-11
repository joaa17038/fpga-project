library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;


entity countBits is
port (
    clk : in std_logic;
    rst : in std_logic;
    inputNumber : in std_logic_vector(7 downto 0);
    ones : out std_logic_vector(7 downto 0));
end entity;


architecture rtl of ones is

begin

    process (clk)

        variable count : std_logic_vector(7 downto 0);

    begin
    
        if rising_edge(clk) then
        
            if rst = '1' then
                ones <= (others => '0');
            else
                count := (others => '0');
                for i in 0 to 7 loop
                    count := count + ("0000000" & inputNumber(i));
                end loop;
                ones <= std_logic_vector(count);
            end if;
            
        end if;
        
    end process;

end architecture;
