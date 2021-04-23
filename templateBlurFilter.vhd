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
    m_axi_data : std_logic_vector(IMAGEWIDTH*PIXELSIZE-1 downto 0);
    m_axi_last : in std_logic;

    s_axi_valid : out std_logic := '0';
    s_axi_data : out std_logic_vector := (others => '0');
    s_axi_ready : out std_logic := '0');
end entity;


architecture rtl of slidingBlurFilterV1 is

    type typeState is (RECEIVE, SIDE, MIDDLE); -- Filter FSM States
    type threeRows is array(0 to 2) of std_logic_vector(IMAGEWIDTH*PIXELSIZE-1 downto 0);
    signal state : typeState := RECEIVE;
    signal buffered : threeRows := (others => (others =>'0'));
    signal heightPointer : integer range 0 to IMAGEHEIGHT-1 := 0;

begin

    process (clk) begin

        if rising_edge(clk) then

            if rst = '1' then
                state <= RECEIVE;
                s_axi_ready <= '0';
                s_axi_valid <= '0';
                s_axi_data <= (others => '0');
                heightPointer <= 0;
                buffered <= (others => (others =>'0'));

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
                        s_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector((
                                                  unsigned(buffered(1)(PIXELSIZE-1 downto 0))
                                                + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                                + unsigned(buffered(2)(PIXELSIZE-1 downto 0))
                                                + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE))
                                                ) / 4);

                        -- Side pixel 2x3
                        for i in 1 to IMAGEWIDTH-2 loop
                            s_axi_data(PIXELSIZE*i*2-1 downto PIXELSIZE*i) <= std_logic_vector((
                                             unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                           + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                           + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                           + unsigned(buffered(2)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                           + unsigned(buffered(2)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                           + unsigned(buffered(2)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                           ) / 6);
                        end loop;

                        -- Rightside corner pixel 2x2
                        s_axi_data(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE) <= std_logic_vector((
                                                              unsigned(buffered(1)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE))
                                                            + unsigned(buffered(1)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))
                                                            + unsigned(buffered(2)((IMAGEWIDTH-1)*PIXELSIZE-1 downto (IMAGEWIDTH-1)*PIXELSIZE-IMAGEWIDTH))
                                                            + unsigned(buffered(2)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))
                                                            ) / 4);

                        buffered <= buffered(1 to 2) & m_axi_data;
                        heightPointer <= heightPointer + 1;
                        s_axi_valid <= '1'; -- Starts stream

                        if heightPointer = IMAGEHEIGHT-1 then
                            s_axi_valid <= '0'; -- Ends stream
                        else
                            state <= MIDDLE;
                        end if;

                    when MIDDLE =>
                        -- Leftside pixel 3x2
                        s_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector((unsigned(buffered(1)(PIXELSIZE-1 downto 0)) + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                                + unsigned(buffered(2)(PIXELSIZE-1 downto 0)) + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE))
                                                + unsigned(buffered(2)(PIXELSIZE-1 downto 0)) + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE))) / 6);

                        -- Middle pixel 3x3
                        for i in 1 to IMAGEWIDTH-2 loop
                            s_axi_data(PIXELSIZE*i*2-1 downto PIXELSIZE*i) <= std_logic_vector((
                                             unsigned(buffered(0)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                           + unsigned(buffered(0)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                           + unsigned(buffered(0)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                           + unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                           + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                           + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                           + unsigned(buffered(2)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                           + unsigned(buffered(2)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                           + unsigned(buffered(2)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                           ) / 9);
                        end loop;

                        -- Rightside pixel 3x2
                        s_axi_data(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE) <= std_logic_vector((
                                                              unsigned(buffered(0)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE))
                                                            + unsigned(buffered(0)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))
                                                            + unsigned(buffered(1)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE))
                                                            + unsigned(buffered(1)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))
                                                            + unsigned(buffered(2)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE))
                                                            + unsigned(buffered(2)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))
                                                            ) / 6);

                        buffered <= buffered(1 to 2) & m_axi_data;
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
