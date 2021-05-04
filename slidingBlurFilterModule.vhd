library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity slidingBlurFilter is
generic (PIXELSIZE, PACKETSIZE, MAXIMAGEWIDTH, MAXIMAGEHEIGHT: integer);
port (
    clk : in std_logic; -- Clock
    rst : in std_logic; -- Reset

    s_axi_pixels_data : in std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0); -- Input data
    s_axi_pixels_valid : in std_logic; -- Input valid
    s_axi_pixels_last : in std_logic; -- Input last
    s_axi_pixels_ready : out std_logic; -- Output ready

    m_axi_pixels_data : out std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0); -- Output data
    m_axi_pixels_valid : out std_logic; -- Output valid
    m_axi_pixels_last : out std_logic; -- Output last
    m_axi_pixels_ready : in std_logic; -- Input ready

    s_axi_dimensions_data : in std_logic_vector(23 downto 0); -- Input data
    s_axi_dimensions_valid : in std_logic; -- Input valid
    s_axi_dimensions_ready : out std_logic; -- Output ready
    m_axi_dimensions_ready : in std_logic); -- Input ready
end entity;


architecture rtl of slidingBlurFilter is

    type threeRows is array(0 to 2) of std_logic_vector(PIXELSIZE*PACKETSIZE*(MAXIMAGEWIDTH/PACKETSIZE)-1 downto 0); -- Buffered rows
    type typeState is (DIM, RECEIVE, FILTER); -- Finite State Machine for dimensions, pixels, and filter

    constant PACKETBITS : integer := PIXELSIZE*PACKETSIZE; -- Total number of bits in each packet
    constant ZERO : std_logic_vector(PACKETBITS-1 downto 0) := (others => '0'); -- Zero padding for the image

    signal state : typeState := DIM; -- Initial state for receiving image dimensions
    signal buffered : threeRows := (others => (others => '0'));
    signal restart : std_logic := '0'; -- Reset the signals for the next image

    signal heightPointer : integer range 0 to MAXIMAGEHEIGHT; -- Height pointer for the image
    signal widthPointer : integer range 1 to MAXIMAGEWIDTH/PACKETSIZE; -- Width pointer for the image

    signal bWidthPointer : integer range 0 to MAXIMAGEWIDTH/PACKETSIZE; -- Width pointer for the buffered packets
    signal bHeightPointer : integer range 0 to 2; -- Height pointer for the buffered rows

    signal IMAGEHEIGHT : integer range 0 to MAXIMAGEHEIGHT; -- The height of the image
    signal IMAGEWIDTHRATIO : integer range 0 to MAXIMAGEWIDTH/PACKETSIZE; -- The packet width of the image

    signal divisorSide : unsigned(3 downto 0); -- Side divisor for the filter
    signal divisorMiddle : unsigned(3 downto 0); -- Middle divisor for the filter

    procedure middle(signal packet : out std_logic_vector(PACKETBITS-1 downto 0);
                     constant p1 : in integer; constant p2 : in integer;
                     constant a1 : in integer; constant a2 : in integer;
                     constant b1 : in integer; constant b2 : in integer;
                     constant c1 : in integer; constant c2 : in integer) is
    begin
        packet(p1 downto p2) <= std_logic_vector(resize((
            resize(unsigned(buffered(0)(a1 downto a2)), PIXELSIZE*2-1)
          + unsigned(buffered(0)(b1 downto b2))
          + unsigned(buffered(0)(c1 downto c2))
          + unsigned(buffered(1)(a1 downto a2))
          + unsigned(buffered(1)(b1 downto b2))
          + unsigned(buffered(1)(c1 downto c2))
          + unsigned(buffered(2)(a1 downto a2))
          + unsigned(buffered(2)(b1 downto b2))
          + unsigned(buffered(2)(c1 downto c2))) / divisorMiddle, PIXELSIZE));
    end procedure;

begin

    process (clk) begin

        if rising_edge(clk) then

            if rst = '1' or (restart = '1' and m_axi_pixels_ready = '1') then
                s_axi_pixels_ready <= '0';
                s_axi_dimensions_ready <= '1';

                m_axi_pixels_data <= (others => '0');
                m_axi_pixels_valid <= '0';
                m_axi_pixels_last <= '0';

                state <= DIM;
                buffered <= (others => (others => '0'));
                restart <= '0';

                bHeightPointer <= 0;
                heightPointer <= 0;

                IMAGEHEIGHT <= 0;
                IMAGEWIDTHRATIO <= 0;

                divisorSide <= X"4";
                divisorMiddle <= X"6";

            else
                if m_axi_pixels_ready = '1' then
                    m_axi_pixels_last <= '0';
                    m_axi_pixels_valid <= '0';

                    case state is
                        when DIM => -- Receive image dimensions
                            if m_axi_dimensions_ready = '1' and s_axi_dimensions_valid = '1' then
                                IMAGEHEIGHT <= to_integer(unsigned(s_axi_dimensions_data(23 downto 12)));
                                IMAGEWIDTHRATIO <= to_integer(unsigned(s_axi_dimensions_data(11 downto 0)))/PACKETSIZE;
                                bWidthPointer <= to_integer(unsigned(s_axi_dimensions_data(11 downto 0)))/PACKETSIZE;
                                widthPointer <= to_integer(unsigned(s_axi_dimensions_data(11 downto 0)))/PACKETSIZE;
                                s_axi_dimensions_ready <= '0';
                                s_axi_pixels_ready <= '1';
                                state <= RECEIVE;
                            end if;

                        when RECEIVE => -- Receive pixel packets
                            if s_axi_pixels_valid = '1' or heightPointer > IMAGEHEIGHT-2 then
                                if s_axi_pixels_valid = '1' then
                                    buffered(bHeightPointer)(PACKETBITS*bWidthPointer-1 downto PACKETBITS*(bWidthPointer-1)) <= s_axi_pixels_data;
                                    bWidthPointer <= bWidthPointer - 1;
                                elsif heightPointer > IMAGEHEIGHT-2 then
                                    buffered(bHeightPointer)(PACKETBITS*bWidthPointer-1 downto PACKETBITS*(bWidthPointer-1)) <= ZERO;
                                    bWidthPointer <= bWidthPointer - 1;
                                end if;

                                if bHeightPointer = 2 and bWidthPointer = 1 and heightPointer > 0 then
                                    bHeightPointer <= 0;
                                    bWidthPointer <= IMAGEWIDTHRATIO;
                                elsif bWidthPointer = 1 then -- next row
                                    bHeightPointer <= bHeightPointer + 1;
                                    bWidthPointer <= IMAGEWIDTHRATIO;
                                end if;

                                if (heightPointer = 0 and bHeightPointer = 1 and bWidthPointer = 1) or (heightPointer > 0 and bWidthPointer = 1) then
                                    state <= FILTER;
                                    s_axi_pixels_ready <= '0';
                                end if;
                            end if;

                        when FILTER => -- Filter pixel packets
                            m_axi_pixels_data <= (others => '0');
                            if widthPointer = IMAGEWIDTHRATIO then
                                m_axi_pixels_data(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(0)(PACKETBITS*widthPointer-1 downto PACKETBITS*widthPointer-PIXELSIZE)), PIXELSIZE*2-1)
                                  + unsigned(buffered(0)(PACKETBITS*widthPointer-PIXELSIZE-1 downto PACKETBITS*widthPointer-PIXELSIZE*2))
                                  + unsigned(buffered(1)(PACKETBITS*widthPointer-1 downto PACKETBITS*widthPointer-PIXELSIZE))
                                  + unsigned(buffered(1)(PACKETBITS*widthPointer-PIXELSIZE-1 downto PACKETBITS*widthPointer-PIXELSIZE*2))
                                  + unsigned(buffered(2)(PACKETBITS*widthPointer-1 downto PACKETBITS*widthPointer-PIXELSIZE))
                                  + unsigned(buffered(2)(PACKETBITS*widthPointer-PIXELSIZE-1 downto PACKETBITS*widthPointer-PIXELSIZE*2))) / divisorSide, PIXELSIZE));
                            end if;

                            if IMAGEWIDTHRATIO > 1 then -- Image width greater than the packetsize
                                if widthPointer = IMAGEWIDTHRATIO then -- First packet in the row
                                    for i in 1 to PACKETSIZE-1 loop
                                        middle(m_axi_pixels_data, PIXELSIZE*(PACKETSIZE-i)-1, PIXELSIZE*(PACKETSIZE-i)-PIXELSIZE,
                                               PACKETBITS*widthPointer-PIXELSIZE*(i-1)-1, PACKETBITS*widthPointer-PIXELSIZE*(i-1)-PIXELSIZE,
                                               PACKETBITS*widthPointer-PIXELSIZE*(i)-1, PACKETBITS*widthPointer-PIXELSIZE*(i)-PIXELSIZE,
                                               PACKETBITS*widthPointer-PIXELSIZE*(i+1)-1, PACKETBITS*widthPointer-PIXELSIZE*(i+1)-PIXELSIZE);
                                    end loop;
                                elsif widthPointer = 1 then -- Last packet in the row
                                    for i in 2 to PACKETSIZE loop
                                        middle(m_axi_pixels_data, PIXELSIZE*i-1, PIXELSIZE*i-PIXELSIZE,
                                               PIXELSIZE*(i-1)-1, PIXELSIZE*(i-1)-PIXELSIZE,
                                               PIXELSIZE*(i)-1, PIXELSIZE*(i)-PIXELSIZE,
                                               PIXELSIZE*(i+1)-1, PIXELSIZE*(i+1)-PIXELSIZE);
                                    end loop;
                                else -- Intermediate packet(s) in the row
                                    for i in 0 to PACKETSIZE-1 loop
                                        middle(m_axi_pixels_data, PIXELSIZE*(PACKETSIZE-i)-1, PIXELSIZE*(PACKETSIZE-i)-PIXELSIZE,
                                               PACKETBITS*widthPointer-PIXELSIZE*(i-1)-1, PACKETBITS*widthPointer-PIXELSIZE*(i-1)-PIXELSIZE,
                                               PACKETBITS*widthPointer-PIXELSIZE*(i)-1, PACKETBITS*widthPointer-PIXELSIZE*(i)-PIXELSIZE,
                                               PACKETBITS*widthPointer-PIXELSIZE*(i+1)-1, PACKETBITS*widthPointer-PIXELSIZE*(i+1)-PIXELSIZE);
                                    end loop;
                                end if;
                            elsif IMAGEWIDTHRATIO = 1 then -- Image width equals the packetsize
                                for i in 2 to PACKETSIZE-1 loop
                                    middle(m_axi_pixels_data, PIXELSIZE*i-1, PIXELSIZE*i-PIXELSIZE,
                                           PIXELSIZE*(i-1)-1, PIXELSIZE*(i-1)-PIXELSIZE,
                                           PIXELSIZE*(i)-1, PIXELSIZE*(i)-PIXELSIZE,
                                           PIXELSIZE*(i+1)-1, PIXELSIZE*(i+1)-PIXELSIZE);
                                end loop;
                            end if;

                            m_axi_pixels_valid <= '1';
                            widthPointer <= widthPointer - 1;
                            if widthPointer = 1 then
                                -- Last pixel in the row
                                m_axi_pixels_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize((
                                    resize(unsigned(buffered(0)(PIXELSIZE-1 downto 0)), PIXELSIZE*2-1)
                                  + unsigned(buffered(0)(PIXELSIZE*2-1 downto PIXELSIZE))
                                  + unsigned(buffered(1)(PIXELSIZE-1 downto 0))
                                  + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                  + unsigned(buffered(2)(PIXELSIZE-1 downto 0))
                                  + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE))) / divisorSide, PIXELSIZE));
                                -- Prepare for next row
                                s_axi_pixels_ready <= '1';
                                widthPointer <= IMAGEWIDTHRATIO;
                                heightPointer <= heightPointer + 1;
                                state <= RECEIVE;
                                -- Change divisors
                                if heightPointer = 0 then
                                    divisorSide <= X"6";
                                    divisorMiddle <= X"9";
                                elsif heightPointer = IMAGEHEIGHT-2  then
                                    divisorSide <= X"4";
                                    divisorMiddle <= X"6";
                                -- End of filtered image
                                elsif heightPointer = IMAGEHEIGHT-1 then
                                    m_axi_pixels_last <= '1';
                                    restart <= '1';
                                    state <= DIM;
                                end if;
                            end if;

                    end case;

                end if;

            end if;

        end if;

    end process;

end architecture;
