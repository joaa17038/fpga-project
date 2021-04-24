library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity slidingBlurFilterV1 is
generic (PIXELSIZE, IMAGEWIDTH, IMAGEHEIGHT: integer);
port (
    clk : in std_logic;
    rst : in std_logic;

    s_axi_valid : in std_logic;
    s_axi_ready : out std_logic := '1';
    s_axi_data : in std_logic_vector(PIXELSIZE*IMAGEWIDTH-1 downto 0);
    s_axi_last : in std_logic;

    m_axi_valid : out std_logic := '0';
    m_axi_ready : in std_logic;
    m_axi_last : out std_logic := '0';
    m_axi_data : out std_logic_vector(PIXELSIZE*IMAGEWIDTH-1 downto 0) := (others => '0'));
end entity;


architecture rtl of slidingBlurFilterV1 is

    type typeState is (RECEIVE, SIDE, MIDDLE);
    type threeRows is array(0 to 1) of std_logic_vector(PIXELSIZE*IMAGEWIDTH-1 downto 0); --2  before
    
    signal state : typeState := RECEIVE;
    signal buffered : threeRows := (others => (others => '0'));
    signal heightPointer : integer range 0 to IMAGEHEIGHT-1 := 0;

begin

    process (clk) begin

        if rising_edge(clk) then

            if rst = '1' then
                state <= RECEIVE;
                s_axi_ready <= '1';
                m_axi_valid <= '0';
                m_axi_data <= (others => '0');
                heightPointer <= 0;
                buffered <= (others => (others =>'0'));

            else
                case state is
                    when RECEIVE =>
                        if s_axi_valid = '1' then
                            buffered <= buffered(1) & s_axi_data;
                            state <= SIDE;
                        else
                            m_axi_last <= '0';
                            s_axi_ready <= '1';
                            heightPointer <= 0;
                            m_axi_valid <= '0';
                            m_axi_data <= (others => '0');
                            buffered <= (others => (others => '0'));
                        end if;

                    when SIDE =>
                        if s_axi_valid = '1' then
                            -- Leftside corner pixel 2x2
                            m_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(1)(PIXELSIZE-1 downto 0)), PIXELSIZE*2-1)
                                  + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                  + unsigned(s_axi_data(PIXELSIZE-1 downto 0))
                                  + unsigned(s_axi_data(PIXELSIZE*2-1 downto PIXELSIZE))) / 4, PIXELSIZE));
    
                            -- Side pixel 2x3
                            for i in 2 to IMAGEWIDTH-1 loop
                                m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize((
                                        resize(unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                      + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                      + unsigned(s_axi_data(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                      + unsigned(s_axi_data(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(s_axi_data(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))) / 6, PIXELSIZE));
                            end loop;
    
                            -- Rightside corner pixel 2x2
                            m_axi_data(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(1)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                  + unsigned(buffered(1)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))
                                  + unsigned(s_axi_data(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE))
                                  + unsigned(s_axi_data(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))) / 4, PIXELSIZE));
    
                            buffered <= buffered(1) & s_axi_data;
                            heightPointer <= heightPointer + 1;
                            m_axi_valid <= '1';
                            state <= MIDDLE;
                        
                        elsif heightPointer = IMAGEHEIGHT-1 then
                             -- Leftside corner pixel 2x2
                            m_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(1)(PIXELSIZE-1 downto 0)), PIXELSIZE*2-1)
                                  + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                  + unsigned(buffered(0)(PIXELSIZE-1 downto 0))
                                  + unsigned(buffered(0)(PIXELSIZE*2-1 downto PIXELSIZE))) / 4, PIXELSIZE));
    
                            -- Side pixel 2x3
                            for i in 2 to IMAGEWIDTH-1 loop
                                m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize((
                                        resize(unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                      + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                      + unsigned(buffered(0)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                      + unsigned(buffered(0)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(0)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))) / 6, PIXELSIZE));
                            end loop;
    
                            -- Rightside corner pixel 2x2
                            m_axi_data(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(1)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                  + unsigned(buffered(1)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))
                                  + unsigned(buffered(0)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE))
                                  + unsigned(buffered(0)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))) / 4, PIXELSIZE));
                            
                            m_axi_last <= '1';
                            buffered <= buffered(1) & s_axi_data;
                            heightPointer <= heightPointer + 1;
                            m_axi_valid <= '1';
                            state <= RECEIVE;
                        end if;

                    when MIDDLE =>
                        if s_axi_valid = '1' then
                            -- Leftside pixel 3x2
                            m_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(0)(PIXELSIZE-1 downto 0)), PIXELSIZE*2-1)
                                  + unsigned(buffered(0)(PIXELSIZE*2-1 downto PIXELSIZE))
                                  + unsigned(buffered(1)(PIXELSIZE-1 downto 0))
                                  + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                  + unsigned(s_axi_data(PIXELSIZE-1 downto 0))
                                  + unsigned(s_axi_data(PIXELSIZE*2-1 downto PIXELSIZE))) / 6, PIXELSIZE));
    
                            -- Middle pixel 3x3
                            for i in 2 to IMAGEWIDTH-1 loop
                                m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize((
                                        resize(unsigned(buffered(0)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                      + unsigned(buffered(0)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(0)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                      + unsigned(s_axi_data(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                      + unsigned(s_axi_data(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(s_axi_data(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))) / 9, PIXELSIZE));
                            end loop;
    
                            -- Rightside pixel 3x2
                            m_axi_data(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(0)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                  + unsigned(buffered(0)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))
                                  + unsigned(buffered(1)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE))
                                  + unsigned(buffered(1)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))
                                  + unsigned(s_axi_data(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE))
                                  + unsigned(s_axi_data(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE))) / 6, PIXELSIZE));
    
                            buffered <= buffered(1) & s_axi_data;
                            heightPointer <= heightPointer + 1;
                            m_axi_valid <= '1';
                        end if;

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
