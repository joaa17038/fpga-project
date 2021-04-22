constant PIXELWIDTH : integer := 16;
constant IMAGEWIDTH : integer := 1920;
constant IMAGEHEIGHT : integer := 1080;

type typeState is (SIDE, MIDDLE); -- Filter FSM States
type row is array(0 to IMAGEWIDTH-1) of std_logic_vector(PIXELWIDTH-1 downto 0); -- Maybe unsigned
type rectangle is array(0 to 2) of row;

signal state : typeState := SIDE;
signal buffered : rectangle := (others => (others => '0'));


-- Filter FSM
case state is
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

        if heightPointer = HEIGHT-2 then -- 2xM image probably won't happen, maybe remove
            state <= SIDE;
        elsif heightPointer = HEIGHT-1 then
            s_axi_valid <= '0'; -- Ends stream
        else
            state <= MIDDLE;
        end if;

    when MIDDLE =>
        -- Leftside pixel 3x2
        s_axi_data(i) <= (buffered(0)(0) + buffered(0)(1)
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

        if heightPointer = HEIGHT-2 then
            state <= SIDE;
        else
            state <= MIDDLE;
        end if;

end case;
