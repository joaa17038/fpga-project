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
    s_axi_ready : out std_logic;
    s_axi_data : in std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0);
    s_axi_dim : in std_logic_vector(23 downto 0);
    s_axi_last : in std_logic;

    m_axi_valid : out std_logic;
    m_axi_ready : in std_logic;
    m_axi_last : out std_logic;
    m_axi_data : out std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0));
end entity;


architecture rtl of slidingBlurFilterV1 is

    type typeState is (RECEIVE, FILTER);
    type threeRows is array(0 to 2) of std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0);

    constant ZERO : std_logic_vector(PIXELSIZE*PACKETSIZE-1 downto 0) := (others => '0');

    signal state : typeState := RECEIVE;
    signal buffered : threeRows := (others => (others => '0'));

    signal heightPointer : unsigned(11 downto 0) := (others => '0');
    signal widthPointer : unsigned(11 downto 0) := (others => '0');
    signal IMAGEHEIGHT : unsigned(11 downto 0) := (others => '0');
    signal IMAGEWIDTH : unsigned(11 downto 0) := (others => '0');
    signal divisorSide : unsigned(3 downto 0) := (others => '0');
    signal divisorMiddle : unsigned(3 downto 0) := (others => '0');

begin

    process (clk) begin

        if rising_edge(clk) then

            if rst = '1' then
                s_axi_ready <= '1';
                m_axi_last <= '0';
                m_axi_valid <= '0';
                m_axi_data <= (others => '0');

                state <= RECEIVE;
                buffered <= (others => (others =>'0'));
                heightPointer <= (others => '0');
                widthPointer <= (others => '0');
                IMAGEHEIGHT <= (others => '0');
                IMAGEWIDTH <= (others => '0');
                divisorSide <= X"4";
                divisorMiddle <= X"6";

            else
                if m_axi_ready = '1' then
                    m_axi_last <= '0';
                    m_axi_valid <= '0';

                    case state is
                        when RECEIVE =>
                            -- Buffer first two rows
                            if s_axi_valid = '1' then
                                buffered <= buffered(1 to 2) & s_axi_data;
                                IMAGEHEIGHT <= unsigned(s_axi_dim(23 downto 12));
                                IMAGEWIDTH <= unsigned(s_axi_dim(11 downto 0));
                                heightPointer <= heightPointer + 1;
                                if heightPointer = 1 then
                                    heightPointer <= (others => '0');
                                    state <= FILTER;
                                end if;
                            -- Prepare for next image
                            elsif heightPointer = IMAGEHEIGHT then
                                s_axi_ready <= '1';
                                m_axi_data <= (others => '0');
                                buffered <= (others => (others =>'0'));
                                heightPointer <= (others => '0');
                                widthPointer <= (others => '0');
                                IMAGEHEIGHT <= (others => '0');
                                IMAGEWIDTH <= (others => '0');
                                divisorSide <= X"4";
                                divisorMiddle <= X"6";
                            end if;

                        when FILTER =>
                            if s_axi_valid = '1' or heightPointer = IMAGEHEIGHT-1 or heightPointer = IMAGEHEIGHT-2 then
                                -- Leftside pixel 2x2, 2x3
                                m_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize((
                                        resize(unsigned(buffered(0)(PIXELSIZE-1 downto 0)), PIXELSIZE*2-1)
                                      + unsigned(buffered(0)(PIXELSIZE*2-1 downto PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE-1 downto 0))
                                      + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE-1 downto 0))
                                      + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE))) / divisorSide, PIXELSIZE));

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

                                -- Rightside pixel 2x2, 2x3
                                m_axi_data(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE) <= std_logic_vector(resize((
                                        resize(unsigned(buffered(0)(PIXELSIZE*(PACKETSIZE-1)-1 downto PIXELSIZE*(PACKETSIZE-1)-PIXELSIZE)), PIXELSIZE*2-1)
                                      + unsigned(buffered(0)(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*(PACKETSIZE-1)-1 downto PIXELSIZE*(PACKETSIZE-1)-PIXELSIZE))
                                      + unsigned(buffered(1)(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*(PACKETSIZE-1)-1 downto PIXELSIZE*(PACKETSIZE-1)-PIXELSIZE))
                                      + unsigned(buffered(2)(PIXELSIZE*PACKETSIZE-1 downto PIXELSIZE*PACKETSIZE-PIXELSIZE))) / divisorSide, PIXELSIZE));

                                if s_axi_valid = '1' then
                                    buffered <= buffered(1 to 2) & s_axi_data;
                                else
                                    buffered <= buffered(1 to 2) & ZERO;
                                end if;

                                heightPointer <= heightPointer + 1;
                                m_axi_valid <= '1';
                            end if;

                            -- Not ready for more input
                            if s_axi_last = '1' then
                                s_axi_ready <= '0';
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
                                state <= RECEIVE;
                            end if;

                    end case;

                end if;

            end if;

        end if;

    end process;

end architecture;
