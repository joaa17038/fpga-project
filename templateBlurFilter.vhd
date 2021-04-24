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
    s_axi_data : in std_logic_vector(IMAGEWIDTH*PIXELSIZE-1 downto 0);
    s_axi_last : in std_logic;

    m_axi_valid : out std_logic := '0';
    m_axi_ready : in std_logic;
    m_axi_last : out std_logic := '0';
    m_axi_data : out std_logic_vector(IMAGEWIDTH*PIXELSIZE-1 downto 0) := (others => '0'));
end entity;


architecture rtl of slidingBlurFilterV1 is

    type typeState is (RECEIVE, SIDE, MIDDLE);
    type threeRows is array(0 to 2) of std_logic_vector(IMAGEWIDTH*PIXELSIZE-1 downto 0);
    
    signal state : typeState := RECEIVE;
    signal buffered : threeRows := (others => (others => '0'));
    signal heightPointer : integer range 0 to IMAGEHEIGHT-1 := 0;

begin

    process (clk) 
    
        variable temp : unsigned(PIXELSIZE*2-1 downto 0) := (others => '0');
        
    begin

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
                            buffered <= buffered(1 to 2) & s_axi_data;
                        end if;
                        
                        heightPointer <= heightPointer + 1;
                        state <= RECEIVE;
                        if heightPointer = 2 then
                            state <= SIDE;
                            heightPointer <= 0;
                        end if;

                    when SIDE =>
                        -- Leftside corner pixel 2x2
                        temp := temp + unsigned(buffered(1)(PIXELSIZE-1 downto 0));
                        temp := temp + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE));
                        temp := temp + unsigned(buffered(2)(PIXELSIZE-1 downto 0));
                        temp := temp + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE));
                        temp := temp / 4;
                        m_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize(temp, PIXELSIZE));
                        temp := (others => '0');

                        -- Side pixel 2x3
                        for i in 2 to IMAGEWIDTH-1 loop
                            temp := temp + unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE));
                            temp := temp + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE));
                            temp := temp + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE));
                            temp := temp + unsigned(buffered(2)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE));
                            temp := temp + unsigned(buffered(2)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE));
                            temp := temp + unsigned(buffered(2)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE));
                            temp := temp / 6;
                            m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize(temp, PIXELSIZE));
                            temp := (others => '0');
                        end loop;

                        -- Rightside corner pixel 2x2
                        temp := temp + unsigned(buffered(1)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE));
                        temp := temp + unsigned(buffered(1)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE));
                        temp := temp + unsigned(buffered(2)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE));
                        temp := temp + unsigned(buffered(2)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE));
                        temp := temp / 4;
                        m_axi_data(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE) <= std_logic_vector(resize(temp, PIXELSIZE));
                        temp := (others => '0');

                        if s_axi_valid = '1' then
                            buffered <= buffered(1 to 2) & s_axi_data;
                        end if;
                        heightPointer <= heightPointer + 1;
                        m_axi_valid <= '1'; -- Starts stream

                        if heightPointer = IMAGEHEIGHT-1 then
                            m_axi_last <= '1';
                        elsif heightPointer = IMAGEHEIGHT then
                            m_axi_last <= '0';
                            s_axi_ready <= '0';
                            heightPointer <= heightPointer;
                            m_axi_valid <= '0';
                            m_axi_data <= (others => '0');
                        else
                            state <= MIDDLE;
                        end if;

                    when MIDDLE =>
                        -- Leftside pixel 3x2
                        temp := temp + unsigned(buffered(0)(PIXELSIZE-1 downto 0));
                        temp := temp + unsigned(buffered(0)(PIXELSIZE*2-1 downto PIXELSIZE));
                        temp := temp + unsigned(buffered(1)(PIXELSIZE-1 downto 0));
                        temp := temp + unsigned(buffered(1)(PIXELSIZE*2-1 downto PIXELSIZE));
                        temp := temp + unsigned(buffered(2)(PIXELSIZE-1 downto 0));
                        temp := temp + unsigned(buffered(2)(PIXELSIZE*2-1 downto PIXELSIZE));
                        temp := temp / 6;
                        m_axi_data(PIXELSIZE-1 downto 0) <= std_logic_vector(resize(temp, PIXELSIZE));
                        temp := (others => '0');

                        -- Middle pixel 3x3
                        for i in 2 to IMAGEWIDTH-1 loop
                            temp := temp + unsigned(buffered(0)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE));
                            temp := temp + unsigned(buffered(0)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE));
                            temp := temp + unsigned(buffered(0)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE));
                            temp := temp + unsigned(buffered(1)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE));
                            temp := temp + unsigned(buffered(1)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE));
                            temp := temp + unsigned(buffered(1)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE));
                            temp := temp + unsigned(buffered(2)(PIXELSIZE*(i-1)-1 downto PIXELSIZE*(i-1)-PIXELSIZE));
                            temp := temp + unsigned(buffered(2)(PIXELSIZE*(i)-1 downto PIXELSIZE*(i)-PIXELSIZE));
                            temp := temp + unsigned(buffered(2)(PIXELSIZE*(i+1)-1 downto PIXELSIZE*(i+1)-PIXELSIZE));
                            temp := temp / 9;
                            m_axi_data(PIXELSIZE*i-1 downto PIXELSIZE*i-PIXELSIZE) <= std_logic_vector(resize(temp, PIXELSIZE));
                            temp := (others => '0');
                        end loop;

                        -- Rightside pixel 3x2
                        temp := temp + unsigned(buffered(0)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE));
                        temp := temp + unsigned(buffered(0)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE));
                        temp := temp + unsigned(buffered(1)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE));
                        temp := temp + unsigned(buffered(1)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE));
                        temp := temp + unsigned(buffered(2)(PIXELSIZE*(IMAGEWIDTH-1)-1 downto PIXELSIZE*(IMAGEWIDTH-1)-PIXELSIZE));
                        temp := temp + unsigned(buffered(2)(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE));
                        temp := temp / 6;
                        m_axi_data(PIXELSIZE*IMAGEWIDTH-1 downto PIXELSIZE*IMAGEWIDTH-PIXELSIZE) <= std_logic_vector(resize(temp, PIXELSIZE));
                        temp := (others => '0');

                        if s_axi_valid = '1' then
                            buffered <= buffered(1 to 2) & s_axi_data;
                        end if;
                        
                        heightPointer <= heightPointer + 1;
                        m_axi_valid <= '1';

                        if heightPointer = IMAGEHEIGHT-3 then
                            s_axi_ready <= '0';
                        elsif heightPointer = IMAGEHEIGHT-2 then
                            state <= SIDE;
                        else
                            state <= MIDDLE;
                        end if;

                end case;

            end if;

        end if;

    end process;

end architecture;
