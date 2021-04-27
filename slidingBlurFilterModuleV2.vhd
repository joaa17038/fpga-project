library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity slidingBlurFilterV1 is
generic (PIXELSIZE, PACKETSIZE, MAXIMAGEWIDTH, MAXIMAGEHEIGHT: integer);
port (
    clk : in std_logic;
    rst : in std_logic;

    s_axi_valid : in std_logic;
    s_axi_valid2 : in std_logic;
    s_axi_ready : out std_logic;
    s_axi_ready2 : out std_logic;
    s_axi_data : in std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0);
    s_axi_data2 : in std_logic_vector(23 downto 0);
    s_axi_last : in std_logic;
    m_axi_valid : out std_logic;
    m_axi_ready : in std_logic;
    m_axi_ready2 : in std_logic;
    m_axi_last : out std_logic;
    m_axi_data : out std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0));
end entity;


architecture rtl of slidingBlurFilterV1 is
    
    type typeState is (DIM, RECEIVE, FILTER);
    type threeRows is array(0 to 2) of std_logic_vector(PIXELSIZE*PACKETSIZE*(MAXIMAGEWIDTH/PACKETSIZE)-1 downto 0);

    constant ZERO : std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0) := (others => '0');
    signal state : typeState := RECEIVE;
    signal buffered : threeRows := (others => (others => '0'));
    
    signal restart : std_logic := '0';
    signal heightPointer : unsigned(11 downto 0) := (others => '0');
    signal widthPointer : integer range 1 to MAXIMAGEWIDTH/PACKETSIZE := 1;
    signal bWidthPointer : integer range 0 to MAXIMAGEWIDTH/PACKETSIZE := 0;
    signal bHeightPointer : integer range 0 to 2 := 1;
    signal IMAGEHEIGHT : integer range 0 to MAXIMAGEHEIGHT := 0;
    signal IMAGEWIDTHRATIO : integer range 0 to MAXIMAGEWIDTH/PACKETSIZE := 0;
    signal divisorSide : unsigned(3 downto 0) := (others => '0');
    signal divisorMiddle : unsigned(3 downto 0) := (others => '0');

begin

    process (clk) begin

        if rising_edge(clk) then

            if rst = '1' then
                s_axi_ready <= '0';
                s_axi_ready2 <= '1'; 
                m_axi_last <= '0';
                m_axi_valid <= '0';
                m_axi_data <= (others => '0'); 

                state <= DIM;
                restart <= '0';
                buffered <= (others => (others =>'0'));
                bHeightPointer <= 0;
                bWidthPointer <= 0;
                heightPointer <= (others => '0');
                widthPointer <= 1;
                IMAGEHEIGHT <= 0;
                IMAGEWIDTHRATIO <= 0;
                divisorSide <= X"4";
                divisorMiddle <= X"6";

            else
                if m_axi_ready = '1' then
                    m_axi_last <= '0';
                    m_axi_valid <= '0';

                    case state is
                        when DIM =>
                            if m_axi_ready2 = '1' and s_axi_valid2 = '1' then
                                IMAGEHEIGHT <= to_integer(unsigned(s_axi_data2(23 downto 12)));
                                IMAGEWIDTHRATIO <= to_integer(unsigned(s_axi_data2(11 downto 0)))/PACKETSIZE;
                                s_axi_ready2 <= '0';
                                s_axi_ready <= '1';
                                state <= RECEIVE;
                            end if;
                    
                        when RECEIVE =>
                            if s_axi_valid = '1' then
                                buffered(bHeightPointer)(PACKETSIZE*PIXELSIZE*(bWidthPointer+1)-1 downto PACKETSIZE*PIXELSIZE*bWidthPointer) <= s_axi_data;
                                bWidthPointer <= bWidthPointer + 1;
                            elsif heightPointer = IMAGEHEIGHT-1 or heightPointer = IMAGEHEIGHT-2 then
                                buffered(bHeightPointer)(PACKETSIZE*PIXELSIZE*(bWidthPointer+1)-1 downto PACKETSIZE*PIXELSIZE*bWidthPointer) <= ZERO;
                                bWidthPointer <= bWidthPointer + 1;
                            end if;
                            
                            if bWidthPointer = IMAGEWIDTHRATIO-1 then
                                bHeightPointer <= bHeightPointer + 1;
                                bWidthPointer <= 0;
                            end if;
                            
                            if bHeightPointer = 2 then
                                state <= FILTER;
                                bHeightPointer <= 0;
                                s_axi_ready <= '0';
                            elsif heightPointer > 0 then
                                state <= FILTER;
                                s_axi_ready <= '0';
                            end if;

                        when FILTER =>
--                            if widthPointer = 1 then
                                -- Leftside pixel 2x2, 2x3
                                m_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize((
                                        resize(unsigned(buffered(0)(PIXELSIZE-1 downto 0)), PIXELSIZE*2-1)
                                      + unsigned(buffered(0)(PIXELSIZE*2-1 downto PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE-1 downto 0))
                                      + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE-1 downto 0))
                                      + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE))) / divisorSide, PIXELSIZE));
--                            end if;           

--                            if IMAGEWIDTHRATIO = 1 then
                                -- Middle pixel 2x3, 3x3
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
                                          + unsigned(buffered(2)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))) / divisorMiddle, PIXELSIZE));
                                end loop;
--                            elsif widthPointer = 1 then
--                                -- Middle pixel 2x3, 3x3
--                                for i in 2 to PACKETSIZE loop
--                                    m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize((
--                                            resize(unsigned(buffered(0)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE)), PIXELSIZE*2-1)
--                                          + unsigned(buffered(0)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
--                                          + unsigned(buffered(0)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
--                                          + unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
--                                          + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
--                                          + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))
--                                          + unsigned(buffered(2)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE))
--                                          + unsigned(buffered(2)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE))
--                                          + unsigned(buffered(2)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE))) / divisorMiddle, PIXELSIZE));
--                                end loop;
--                            elsif widthPointer = IMAGEWIDTHRATIO then
--                                -- Middle pixel 2x3, 3x3
--                                for i in 1 to PACKETSIZE-1 loop
--                                    m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize((
--                                            resize(unsigned(buffered(0)(PIXELSIZE*(i-1)*widthPointer-1 downto PIXELSIZE*(i-1)*widthPointer-PIXELSIZE)), PIXELSIZE*2-1)
--                                          + unsigned(buffered(0)(PIXELSIZE*(i)*widthPointer-1 downto PIXELSIZE*(i)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(0)(PIXELSIZE*(i+1)*widthPointer-1 downto PIXELSIZE*(i+1)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(1)(PIXELSIZE*(i-1)*widthPointer-1 downto PIXELSIZE*(i-1)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(1)(PIXELSIZE*(i)*widthPointer-1 downto PIXELSIZE*(i)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(1)(PIXELSIZE*(i+1)*widthPointer-1 downto PIXELSIZE*(i+1)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(2)(PIXELSIZE*(i-1)*widthPointer-1 downto PIXELSIZE*(i-1)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(2)(PIXELSIZE*(i)*widthPointer-1 downto PIXELSIZE*(i)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(2)(PIXELSIZE*(i+1)*widthPointer-1 downto PIXELSIZE*(i+1)*widthPointer-PIXELSIZE))) / divisorMiddle, PIXELSIZE));
--                                end loop;
--                            else
--                                -- Middle pixel 2x3, 3x3
--                                for i in 1 to PACKETSIZE loop
--                                    m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize((
--                                            resize(unsigned(buffered(0)(PIXELSIZE*(i-1)*widthPointer-1 downto PIXELSIZE*(i-1)*widthPointer-PIXELSIZE)), PIXELSIZE*2-1)
--                                          + unsigned(buffered(0)(PIXELSIZE*(i)*widthPointer-1 downto PIXELSIZE*(i)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(0)(PIXELSIZE*(i+1)*widthPointer-1 downto PIXELSIZE*(i+1)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(1)(PIXELSIZE*(i-1)*widthPointer-1 downto PIXELSIZE*(i-1)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(1)(PIXELSIZE*(i)*widthPointer-1 downto PIXELSIZE*(i)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(1)(PIXELSIZE*(i+1)*widthPointer-1 downto PIXELSIZE*(i+1)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(2)(PIXELSIZE*(i-1)*widthPointer-1 downto PIXELSIZE*(i-1)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(2)(PIXELSIZE*(i)*widthPointer-1 downto PIXELSIZE*(i)*widthPointer-PIXELSIZE))
--                                          + unsigned(buffered(2)(PIXELSIZE*(i+1)*widthPointer-1 downto PIXELSIZE*(i+1)*widthPointer-PIXELSIZE))) / divisorMiddle, PIXELSIZE));
--                                end loop;
--                            end if;

--                            if widthPointer = 1 then --IMAGEWIDTHRATIO then
                                -- Rightside pixel 2x2, 2x3
                                m_axi_data(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE) <= std_logic_vector(resize((
                                        resize(unsigned(buffered(0)(PIXELSIZE*(PACKETSIZE-1)*widthPointer-1 downto PIXELSIZE*(PACKETSIZE-1)*widthPointer-PIXELSIZE)), PIXELSIZE*2-1)
                                      + unsigned(buffered(0)(PIXELSIZE*PACKETSIZE*widthPointer-1 downto PIXELSIZE*PACKETSIZE*widthPointer-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(PACKETSIZE-1)*widthPointer-1 downto PIXELSIZE*(PACKETSIZE-1)*widthPointer-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*PACKETSIZE*widthPointer-1 downto PIXELSIZE*PACKETSIZE*widthPointer-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*(PACKETSIZE-1)*widthPointer-1 downto PIXELSIZE*(PACKETSIZE-1)*widthPointer-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*PACKETSIZE*widthPointer-1 downto PIXELSIZE*PACKETSIZE*widthPointer-PIXELSIZE))) / divisorSide, PIXELSIZE));
--                            end if;
                        
                            widthPointer <= widthPointer + 1;
                            m_axi_valid <= '1';

                            if widthPointer = IMAGEWIDTHRATIO then
                                s_axi_ready <= '1';
                                widthPointer <= 1;
                                heightPointer <= heightPointer + 1;
                                state <= RECEIVE;
                            end if;

                            -- Change divisors
                            if heightPointer = 0 then
                                divisorSide <= X"6";
                                divisorMiddle <= X"9";
                            elsif heightPointer = IMAGEHEIGHT-2 then
                                divisorSide <= X"4";
                                divisorMiddle <= X"6";
                            -- End of filtered image
                            elsif heightPointer = IMAGEHEIGHT-1 then
                                m_axi_last <= '1';
                                state <= DIM;
                            end if;

                    end case;

                end if;

            end if;

        end if;

    end process;

end architecture;
