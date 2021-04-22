library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity slidingBlurFilterV1 is
generic (PIXELSIZE, IMAGEWIDTH, IMAGEHEIGHT: integer);
port (
    clk : in std_logic;
    rst : in std_logic;

    m_axi_valid : in std_logic;
    m_axi_ready : in std_logic;
    m_axi_data : std_logic_vector(PIXELSIZE-1 downto 0);
    m_axi_last : in std_logic;

    s_axi_valid : out std_logic := '0';
    --s_axi_data : out row := (others => '0'); -- maybe make a package for a row
    s_axi_ready : out std_logic := '0');
end entity;


architecture rtl of slidingBlurFilterV1 is

    type typeState is (RECEIVE, SIDE, MIDDLE); -- Filter FSM States
    type row is array(0 to IMAGEWIDTH-1) of unsigned(PIXELSIZE-1 downto 0); -- Maybe unsigned
    type rectangle is array(0 to 2) of row;

    signal s_axi_data : row := (others => (others => '0')); -- temporary instead of out declaration
    signal state : typeState := RECEIVE;
    signal buffered : rectangle := (others => (others => (others => '0')));
    signal heightPointer : integer range 0 to IMAGEHEIGHT-1 := 0;

begin

    process (clk) begin

        if rising_edge(clk) then

            if rst = '1' then
                state <= RECEIVE;
                s_axi_ready <= '0';
                s_axi_valid <= '0';
                s_axi_data <= (others => (others => '0'));
                heightPointer <= 0;
                buffered <= (others => (others => (others => '0')));

            else
                -- Filter FSM
                case state is
                    when RECEIVE =>
                        s_axi_ready <= '1';

                        if m_axi_ready = '1' then
                            buffered <= buffered(1 to 2) & m_axi_data;
                            state <= SIDE;
                        end if;

                    when SIDE =>
                        -- Leftside corner pixel 2x2
                        s_axi_data(0) <= (buffered(1)(0) + buffered(1)(1)
                                       + buffered(2)(0) + buffered(2)(1)) / 4;

                        -- Side pixel 2x3
                        for i in 1 to IMAGEWIDTH-2 loop -- Not sure if it synthesises
                            s_axi_data(i) <= (buffered(1)(i-1) + buffered(1)(i) + buffered(1)(i+1)
                                           + buffered(2)(i-1) + buffered(2)(i) + buffered(2)(i+1)) / 6;
                        end loop;

                        -- Rightside corner pixel 2x2
                        s_axi_data(IMAGEWIDTH-1) <= (buffered(1)(IMAGEWIDTH-2) + buffered(1)(IMAGEWIDTH-1)
                                                  + buffered(2)(IMAGEWIDTH-2) + buffered(2)(IMAGEWIDTH-1)) / 4;

                        buffered <= buffered(1 to 2) & m_axi_data; -- Should shift out a row, maybe incorrect type
                        heightPointer <= heightPointer + 1;
                        s_axi_valid <= '1'; -- Starts stream

                        if heightPointer = IMAGEHEIGHT-2 then -- 2xM image probably won't happen, maybe remove
                            state <= SIDE;
                        elsif heightPointer = IMAGEHEIGHT-1 then
                            s_axi_valid <= '0'; -- Ends stream
                        else
                            state <= MIDDLE;
                        end if;

                    when MIDDLE =>
                        -- Leftside pixel 3x2
                        s_axi_data(0) <= (buffered(0)(0) + buffered(0)(1)
                                       + buffered(1)(0) + buffered(1)(1)
                                       + buffered(2)(0) + buffered(2)(0)) / 6;

                        -- Middle pixel 3x3
                        for i in 1 to IMAGEWIDTH-2 loop -- Not sure if it synthesises
                            s_axi_data(i) <= (buffered(0)(i-1) + buffered(0)(i) + buffered(0)(i+1)
                                           + buffered(1)(i-1) + buffered(1)(i) + buffered(1)(i+1)
                                           + buffered(2)(i-1) + buffered(2)(i) + buffered(2)(i+1)) / 9;
                        end loop;

                        -- Rightside pixel 3x2
                        s_axi_data(IMAGEWIDTH-1) <= (buffered(0)(IMAGEWIDTH-2) + buffered(0)(IMAGEWIDTH-1)
                                                  + buffered(1)(IMAGEWIDTH-2) + buffered(1)(IMAGEWIDTH-1)
                                                  + buffered(2)(IMAGEWIDTH-2) + buffered(2)(IMAGEWIDTH-1)) / 6;

                        buffered <= buffered(1 to 2) & m_axi_data; -- Should shift out a row, maybe incorrect type
                        heightPointer <= heightPointer + 1;

                        if heightPointer = IMAGEHEIGHT-2 then
                            s_axi_ready <= '0';
                            state <= SIDE;
                        else
                            state <= MIDDLE;
                        end if;

                end case;
                
            end if;
            
        end if;
        
    end process;
    
end architecture;
