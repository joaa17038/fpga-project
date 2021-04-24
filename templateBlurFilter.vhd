library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity slidingBlurFilterV1 is
generic (PIXELSIZE, PACKETSIZE: integer);
port (
    clk : in std_logic;
    rst : in std_logic;

    s_axi_valid : in std_logic;
    s_axi_ready : out std_logic := '1';
    s_axi_data : in std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0);
    s_axi_dim : in std_logic_vector(23 downto 0);
    s_axi_last : in std_logic;

    m_axi_valid : out std_logic := '0';
    m_axi_ready : in std_logic;
    m_axi_last : out std_logic := '0';
    m_axi_data : out std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0) := (others => '0'));
end entity;


architecture rtl of slidingBlurFilterV1 is

    type typeState is (RECEIVE, SIDE, MIDDLE);
    type threeRows is array(0 to 2) of std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0);

    signal state : typeState := RECEIVE;
    signal buffered : threeRows := (others => (others => '0'));
    signal IMAGEHEIGHT : unsigned(11 downto 0) := (others => '0');
    signal IMAGEWIDTH : unsigned(11 downto 0) := (others => '0');
    signal heightPointer : unsigned(11 downto 0) := (others => '0');
    signal widthPointer : unsigned(11 downto 0) := (others => '0');

begin

    process (clk) begin

        if rising_edge(clk) then

            if rst = '1' then
                state <= RECEIVE;
                s_axi_ready <= '1';
                m_axi_valid <= '0';
                m_axi_data <= (others => '0');
                heightPointer <= (others => '0');
                widthPointer <= (others => '0');
                buffered <= (others => (others =>'0'));

            else
                case state is
                    when RECEIVE =>
                        if s_axi_valid = '1' then
                            buffered <= buffered(1 to 2) & s_axi_data;
                            IMAGEHEIGHT <= unsigned(s_axi_dim(23 downto 12));
                            IMAGEWIDTH <= unsigned(s_axi_dim(11 downto 0));
                            heightPointer <= heightPointer + 1;
                            if heightPointer = 1 then
                                heightPointer <= (others => '0');
                                state <= SIDE;
                            end if;
                        else
                            m_axi_last <= '0';
                            s_axi_ready <= '1';
                            heightPointer <= (others => '0');
                            IMAGEHEIGHT <= (others => '0');
                            IMAGEWIDTH <= (others => '0');
                            m_axi_valid <= '0';
                            m_axi_data <= (others => '0');
                            buffered <= (others => (others => '0'));
                        end if;

                    when SIDE =>
                        if s_axi_valid = '1' or heightPointer = IMAGEHEIGHT-1 then
                            -- Leftside corner pixel 2x2
                            m_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(1)(PIXELSIZE-1 downto 0)), PIXELSIZE*2-1)
                                  + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                  + unsigned(buffered(2)(PIXELSIZE-1 downto 0))
                                  + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE))) / 4, PIXELSIZE));

                            -- Side pixel 2x3
                            for i in 2 to PACKETSIZE-1 loop
                                m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize((
                                        resize(unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                      + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))) / 6, PIXELSIZE));
                            end loop;

                            -- Rightside corner pixel 2x2
                            m_axi_data(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(1)(PIXELSIZE*(PACKETSIZE-1)-1 downto PIXELSIZE*(PACKETSIZE-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                  + unsigned(buffered(1)(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE))
                                  + unsigned(buffered(2)(PIXELSIZE*(PACKETSIZE-1)-1 downto PIXELSIZE*(PACKETSIZE-1)-PIXELSIZE))
                                  + unsigned(buffered(2)(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE))) / 4, PIXELSIZE));

                            buffered <= buffered(1 to 2) & s_axi_data;
                            heightPointer <= heightPointer + 1;
                            m_axi_valid <= '1';
                            state <= MIDDLE;
                        end if;

                        if heightPointer = IMAGEHEIGHT-1 then
                            m_axi_last <= '1';
                            buffered <= buffered(1 to 2) & s_axi_data;
                            heightPointer <= heightPointer + 1;
                            m_axi_valid <= '1';
                            state <= RECEIVE;
                        end if;

                    when MIDDLE =>
                        if s_axi_valid = '1' or heightPointer = IMAGEHEIGHT-2 then
                            -- Leftside pixel 3x2
                            m_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(0)(PIXELSIZE-1 downto 0)), PIXELSIZE*2-1)
                                  + unsigned(buffered(0)(PIXELSIZE*2-1 downto PIXELSIZE))
                                  + unsigned(buffered(1)(PIXELSIZE-1 downto 0))
                                  + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                  + unsigned(buffered(2)(PIXELSIZE-1 downto 0))
                                  + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE))) / 6, PIXELSIZE));

                            -- Middle pixel 3x3
                            for i in 2 to PACKETSIZE-1 loop
                                m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize((
                                        resize(unsigned(buffered(0)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                      + unsigned(buffered(0)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(0)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))) / 9, PIXELSIZE));
                            end loop;

                            -- Rightside pixel 3x2
                            m_axi_data(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(0)(PIXELSIZE*(PACKETSIZE-1)-1 downto PIXELSIZE*(PACKETSIZE-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                  + unsigned(buffered(0)(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE))
                                  + unsigned(buffered(1)(PIXELSIZE*(PACKETSIZE-1)-1 downto PIXELSIZE*(PACKETSIZE-1)-PIXELSIZE))
                                  + unsigned(buffered(1)(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE))
                                  + unsigned(buffered(2)(PIXELSIZE*(PACKETSIZE-1)-1 downto PIXELSIZE*(PACKETSIZE-1)-PIXELSIZE))
                                  + unsigned(buffered(2)(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE))) / 6, PIXELSIZE));

                            buffered <= buffered(1 to 2) & s_axi_data;
                            heightPointer <= heightPointer + 1;
                            m_axi_valid <= '1';
                        end if;

                        if s_axi_last = '1' then
                            s_axi_ready <= '0';
                        elsif heightPointer = IMAGEHEIGHT-2 then
                            buffered <= buffered;
                            state <= SIDE;
                        end if;

                end case;

            end if;

        end if;

    end process;

end architecture;
