library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity slidingBlurFilter is
generic (PIXELSIZE: integer := 8;
         WORDSIZE: integer := 16;
         MAXIMAGEWIDTH: integer := 16;
         MAXIMAGEHEIGHT: integer := 16);
port (
    clk : in std_logic; -- Clock
    rst : in std_logic; -- Reset

    s_axi_pixels_data : in std_logic_vector(PIXELSIZE*WORDSIZE-1 downto 0); -- Input data
    s_axi_pixels_valid : in std_logic; -- Input valid
    s_axi_pixels_last : in std_logic; -- Input last
    s_axi_pixels_ready : out std_logic; -- Output ready
    m_axi_pixels_data : out std_logic_vector(PIXELSIZE*WORDSIZE-1 downto 0); -- Output data
    m_axi_pixels_valid : out std_logic; -- Output valid
    m_axi_pixels_last : out std_logic; -- Output last
    m_axi_pixels_ready : in std_logic; -- Input ready

    s_axi_dimensions_data : in std_logic_vector(23 downto 0); -- Input data
    s_axi_dimensions_valid : in std_logic; -- Input valid
    s_axi_dimensions_ready : out std_logic; -- Output ready
    m_axi_dimensions_ready : in std_logic); -- Input ready
end entity;


architecture rtl of slidingBlurFilter is

    constant WORDBITS : integer := PIXELSIZE*WORDSIZE; -- Total number of bits in each word
    constant ZERO : std_logic_vector(WORDBITS-1 downto 0) := (others => '0'); -- Zero padding for the image

    type threeRows is array(0 to 2) of std_logic_vector(WORDBITS*(MAXIMAGEWIDTH/WORDSIZE)-1 downto 0); -- buffered rows
    type typeState is (DIM, RECEIVE, FILTER); -- Finite State Machine for dimensions, pixels, and filter

    signal state : typeState := DIM; -- Initial state for receiving image dimensions
    signal rows : threeRows := (others => (others => '0'));
    signal restart : std_logic := '0'; -- Reset the signals for the next image

    signal heightPointer, IMAGEHEIGHT : integer range 0 to MAXIMAGEHEIGHT; -- Height pointer for the image, The height of the image
    signal widthPointer : integer range 1 to MAXIMAGEWIDTH/WORDSIZE; -- Width pointer for the image,

    signal bWidthPointer, IMAGEWIDTHRATIO : integer range 0 to MAXIMAGEWIDTH/WORDSIZE; -- Width pointer for the rows words, The word width of the image
    signal bHeightPointer : integer range 0 to 2; -- Height pointer for the buffered rows

    signal divisorSide : unsigned(3 downto 0); -- Side divisor for the filter
    signal divisorMiddle : unsigned(3 downto 0); -- Middle divisor for the filter

    procedure middle(signal word : out std_logic_vector(WORDBITS-1 downto 0);
                     constant startPos, endPos, startA, endA, startB, endB, startC, endC : in integer) is
    begin
        word(startPos downto endPos) <= std_logic_vector(resize((
            resize(unsigned(rows(0)(startA downto endA)), PIXELSIZE*2-1) + unsigned(rows(0)(startB downto endB)) + unsigned(rows(0)(startC downto endC))
            + unsigned(rows(1)(startA downto endA)) + unsigned(rows(1)(startB downto endB)) + unsigned(rows(1)(startC downto endC))
            + unsigned(rows(2)(startA downto endA)) + unsigned(rows(2)(startB downto endB)) + unsigned(rows(2)(startC downto endC))
            ) / divisorMiddle, PIXELSIZE));
    end procedure;

    procedure side(signal word : out std_logic_vector(WORDBITS-1 downto 0);
                   constant startPos, endPos, startA, endA,  startB, endB : in integer) is
    begin
        word(startPos downto endPos) <= std_logic_vector(resize((
            resize(unsigned(rows(0)(startA downto endA)), PIXELSIZE*2-1) + unsigned(rows(0)(startB downto endB))
            + unsigned(rows(1)(startA downto endA)) + unsigned(rows(1)(startB downto endB))
            + unsigned(rows(2)(startA downto endA)) + unsigned(rows(2)(startB downto endB))
            ) / divisorSide, PIXELSIZE));
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
                rows <= (others => (others => '0'));
                restart <= '0';
                bHeightPointer <= 0;
                heightPointer <= 0;
                IMAGEHEIGHT <= 0;
                IMAGEWIDTHRATIO <= 0;
                divisorSide <= X"4";
                divisorMiddle <= X"6";

            else
                if (m_axi_pixels_ready = '1' and state /= DIM) or (m_axi_dimensions_ready = '1' and s_axi_dimensions_valid = '1') then
                    m_axi_pixels_last <= '0';
                    m_axi_pixels_valid <= '0';
                    s_axi_dimensions_ready <= '0';

                    case state is
                        when DIM => -- Receive image dimensions
                            IMAGEHEIGHT <= to_integer(unsigned(s_axi_dimensions_data(11 downto 0)));
                            IMAGEWIDTHRATIO <= to_integer(unsigned(s_axi_dimensions_data(23 downto 12)))/WORDSIZE;
                            bWidthPointer <= to_integer(unsigned(s_axi_dimensions_data(23 downto 12)))/WORDSIZE;
                            widthPointer <= to_integer(unsigned(s_axi_dimensions_data(23 downto 12)))/WORDSIZE;
                            s_axi_pixels_ready <= '1';
                            state <= RECEIVE;

                        when RECEIVE => -- Receive pixel words
                            if s_axi_pixels_valid = '1' or heightPointer > IMAGEHEIGHT-2 then
                                if s_axi_pixels_valid = '1' then
                                    rows(bHeightPointer)(WORDBITS*bWidthPointer-1 downto WORDBITS*(bWidthPointer-1)) <= s_axi_pixels_data;
                                else
                                    rows(bHeightPointer)(WORDBITS*bWidthPointer-1 downto WORDBITS*(bWidthPointer-1)) <= ZERO;
                                end if;

                                if bWidthPointer = 1 then
                                    bHeightPointer <= bHeightPointer + 1; -- Increment bHeightPointer
                                    if bHeightPointer = 2 then
                                        bHeightPointer <= 0; -- Reset bHeightPointer
                                    end if;
                                    if (heightPointer = 0 and bHeightPointer = 1) or (heightPointer > 0) then
                                        state <= FILTER; -- Switch state
                                        s_axi_pixels_ready <= '0'; -- Not ready
                                    end if;
                                    bWidthPointer <= IMAGEWIDTHRATIO; -- Reset bWidthPointer
                                elsif bWidthPointer > 1 then
                                    bWidthPointer <= bWidthPointer - 1; -- Decrement bWidthPointer
                                end if;
                            end if;

                        when FILTER => -- Filter pixel words
                            m_axi_pixels_valid <= '1'; -- Valid output
                            widthPointer <= widthPointer - 1; -- Decrement widthPointer

                            for i in 1 to WORDSIZE-2 loop -- First/Intermediate/Last word(s) in the row
                                middle(m_axi_pixels_data, PIXELSIZE*(WORDSIZE-i)-1, PIXELSIZE*(WORDSIZE-i)-PIXELSIZE,
                                       WORDBITS*widthPointer-PIXELSIZE*(i-1)-1, WORDBITS*widthPointer-PIXELSIZE*(i-1)-PIXELSIZE,
                                       WORDBITS*widthPointer-PIXELSIZE*(i)-1, WORDBITS*widthPointer-PIXELSIZE*(i)-PIXELSIZE,
                                       WORDBITS*widthPointer-PIXELSIZE*(i+1)-1, WORDBITS*widthPointer-PIXELSIZE*(i+1)-PIXELSIZE);
                            end loop;

                            if widthPointer = IMAGEWIDTHRATIO then -- First pixel in the row
                                side(m_axi_pixels_data, WORDBITS-1, WORDBITS-PIXELSIZE,
                                     WORDBITS*widthPointer-1, WORDBITS*widthPointer-PIXELSIZE,
                                     WORDBITS*widthPointer-PIXELSIZE-1, WORDBITS*widthPointer-PIXELSIZE*2);
                            else
                                middle(m_axi_pixels_data, PIXELSIZE*(WORDSIZE-0)-1, PIXELSIZE*(WORDSIZE-0)-PIXELSIZE,
                                       WORDBITS*widthPointer-PIXELSIZE*(0-1)-1, WORDBITS*widthPointer-PIXELSIZE*(0-1)-PIXELSIZE,
                                       WORDBITS*widthPointer-PIXELSIZE*(0)-1, WORDBITS*widthPointer-PIXELSIZE*(0)-PIXELSIZE,
                                       WORDBITS*widthPointer-PIXELSIZE*(0+1)-1, WORDBITS*widthPointer-PIXELSIZE*(0+1)-PIXELSIZE);
                            end if;

                            if widthPointer = 1 then -- Last pixel in the row
                                side(m_axi_pixels_data, PIXELSIZE-1, 0,
                                     PIXELSIZE-1, 0,
                                     PIXELSIZE*2-1, PIXELSIZE);

                                -- Prepare for next row
                                s_axi_pixels_ready <= '1';
                                widthPointer <= IMAGEWIDTHRATIO;
                                heightPointer <= heightPointer + 1;
                                state <= RECEIVE;
                                divisorSide <= X"6";
                                divisorMiddle <= X"9";

                                if heightPointer = IMAGEHEIGHT-2  then -- Change divisors
                                    divisorSide <= X"4";
                                    divisorMiddle <= X"6";
                                elsif heightPointer = IMAGEHEIGHT-1 then -- End of filtered image
                                    m_axi_pixels_last <= '1';
                                    restart <= '1';
                                end if;
                            else -- Crossover intermediate pixel
                                middle(m_axi_pixels_data, PIXELSIZE*(WORDSIZE-(WORDSIZE-1))-1, PIXELSIZE*(WORDSIZE-(WORDSIZE-1))-PIXELSIZE,
                                       WORDBITS*widthPointer-PIXELSIZE*(WORDSIZE-2)-1, WORDBITS*widthPointer-PIXELSIZE*(WORDSIZE-2)-PIXELSIZE,
                                       WORDBITS*widthPointer-PIXELSIZE*(WORDSIZE-1)-1, WORDBITS*widthPointer-PIXELSIZE*(WORDSIZE-1)-PIXELSIZE,
                                       WORDBITS*widthPointer-PIXELSIZE*(WORDSIZE)-1, WORDBITS*widthPointer-PIXELSIZE*(WORDSIZE)-PIXELSIZE);
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;
end architecture;
