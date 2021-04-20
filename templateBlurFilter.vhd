#  0  1     2  3    4  5    6  7
#  8  9     10 11   12 13   14 15

#  16 17    18 19   20 21   22 23
#  24 25    26 27   28 29   30 31

#  32 33    34 35   36 37   38 39
#  40 41    42 43   44 45   46 47

#  48 49    50 51   52 53   54 55
#  56 57    58 59   60 61   62 63


#  0  1  2  3    4  5  6  7
#  8  9  10 11   12 13 14 15
#  16 17 18 19   20 21 22 23
#  24 25 26 27   28 29 30 31

#  32 33 34 35   36 37 38 39
#  40 41 42 43   44 45 46 47
#  48 49 50 51   52 53 54 55
#  56 57 58 59   60 61 62 63

-- Explanation with 8x8 example
--  0  1     4  5    8  9    12 13      2x2 upperBlock
--  2 |3     6| 7    10 11   14 15
--  0 |1     0| 1    0  1    0  1       2x2 m_axi_data
--  2  3     2  3    2  3    2  3

--  0  1     0  1    0  1    0  1       future 2x2 m_axi_data
--  2  3     2  3    2  3    2  3

--  0  1     0  1    0  1    0  1
--  2  3     2  3    2  3    2  3


states : (TOPLEFTCORNER, TOPSIDE, TOPRIGHTCORNER,
          LEFTSIDE, MIDDLE, RIGHTSIDE,
          BOTTOMLEFTCORNER, BOTTOMSIDE, BOTTOMRIGHTCORNER)

case state is
    when TOPLEFTCORNER =>
        output1 <= (m_axi_data(0) + m_axi_data(1) + m_axi_data(2) + m_axi_data(3)) // 4;

        previousBlock <= m_axi_data;
        widthTracker <= widthTracker + 1;
        state <= SIDE;

    when TOPSIDE =>
        output1 <= (m_axi_data(0) + m_axi_data(2) + previousBlock(0)
                 + previousBlock(1) + previousBlock(2) + previousBlock(3)) // 6;
        output2 <= (m_axi_data(0) + m_axi_data(1) + m_axi_data(2)
                 + m_axi_data(3) + previousBlock(1) + previousBlock(3)) // 6;

        previousBlock <= m_axi_data;
        widthTracker <= widthTracker + 2;
        if widthTracker = WIDTH-3 then
            state <= RIGHTCORNER;
        end if;

    when TOPRIGHTCORNER =>
        output1 <= (m_axi_data(0) + m_axi_data(2) + previousBlock(0)
                 + previousBlock(1) + previousBlock(2) + previousBlock(3)) // 6;
        output2 <= (m_axi_data(0) + m_axi_data(1) + m_axi_data(2)
                 + m_axi_data(3) + previousBlock(1) + previousBlock(3)) // 6;
        output3 <= (m_axi_data(0) + m_axi_data(1) + m_axi_data(2) + m_axi_data(3)) // 4;

        previousBlock <= (others => (others => '0'));
        widthTracker <= (others => '0');
        heightTracker <= heightTracker + 1;
        if heightTracker = HEIGHT-3 then
            state <= BOTTOMLEFTCORNER;
        else
            state <= LEFTSIDE;
        end if;

    when LEFTSIDE =>
        output1 <= (upperBlock(0) + upperBlock(1) + upperBlock(2)
                 + upperBlock(3) + m_axi_data(0) + m_axi_data(1)) // 6;
        output2 <= (upperBlock(2) + upperBlock(3) + m_axi_data(0)
                 + m_axi_data(1) + m_axi_data(2) + m_axi_data(3)) // 6;

        previousBlock <= m_axi_data;
        widthTracker <= widthTracker + 2;
        state <= MIDDLE;

    when MIDDLE =>
        output1 <= (upperBlock(0+blockTracker) + upperBlock(1+blockTracker) + upperBlock(4+blockTracker)
                 + upperBlock(2+blockTracker) + upperblock(3+blockTracker) + upperBlock(6+blockTracker)
                 + previousBlock(0) + previousBlock(1) + m_axi_data(0)) // 9;
        output2 <= (upperBlock(1+blockTracker) + upperBlock(4+blockTracker) + upperBlock(5+blockTracker)
                 + upperBlock(3+blockTracker) + upperBlock(6+blockTracker) + upperBlock(7+blockTracker)
                 + previousBlock(1) + m_axi_data(0) + m_axi_data(1)) // 9;
        output3 <= (upperBlock(2+blockTracker) + upperBlock(3+blockTracker) + upperBlock(6+blockTracker)
                 + previousBlock(0) + previousBlock(1) + m_axi_data(0)
                 + previousBlock(2) + previousBlock(3) + m_axi_data(2)) // 9;
        output4 <= (upperBlock(3+blockTracker) + upperBlock(6+blockTracker) + upperBlock(7+blockTracker)
                 + previousBlock(1+blockTracker) + m_axi_data(0) + m_axi_data(1)
                 + previousBlock(3) + m_axi_data(2) + m_axi_data(3)) // 9;

        previousBlock <= m_axi_data;
        blockTracker <= blockTracker + 4;
        widthTracker <= widthTracker + 2;
        if widthTracker = WIDTH-4 then
            state <= RIGHTSIDE;
        end if;

    when RIGHTSIDE =>
        output1 <= (upperBlock(0+blockTracker) + upperBlock(1) + upperBlock(2)
                 + upperBlock(3+blockTracker) + upperBlock(4+blockTracker) + upperBlock(6+blockTracker)
                 + previousBlock(0) + previousBlock(1) + m_axi_data(0)) // 9;
        output2 <= (upperBlock(1+blockTracker) + upperBlock(4+blockTracker) + upperBlock(5+blockTracker)
                 + upperBlock(3+blockTracker) + upperBlock(6+blockTracker) + upperBlock(7+blockTracker)
                 + previousBlock(1) + m_axi_data(0) + m_axi_data(1)) // 9;
        output3 <= (upperBlock(4+blockTracker) + upperBlock(5+blockTracker) + upperBlock(6+blockTracker)
                 + upperBlock(7+blockTracker) + m_axi_data(0) + m_axi_data(1)) // 6;
        output4 <= (upperBlock(2+blockTracker) + upperBlock(3+blockTracker) + upperBlock(6+blockTracker),
                 + previousBlock(0) + previousBlock(1) + m_axi_data(0)
                 + previousBlock(2) + previousBlock(3) + m_axi_data(2)) // 9;
        output5 <= (upperBlock(3+blockTracker) + upperBlock(6+blockTracker) + upperBlock(7+blockTracker),
                 + previousBlock(1) + m_axi_data(0) + m_axi_data(1)
                 + previousBlock(3) + m_axi_data(2) + m_axi_data(3)) // 9;
        output6 <= (upperBlock(6+blockTracker) + upperBlock(7+blockTracker) + m_axi_data(0)
                 + m_axi_data(1) + m_axi_data(2) + m_axi_data(3)) // 6;

        previousBlock <= (others => (others => '0'));
        widthTracker <= (others => '0');
        heightTracker <= heightTracker + 2;
        if heightTracker = HEIGHT-3 then
            state <= BOTTOMLEFTCORNER;
        else
            state <= LEFTSIDE;
        end if;

    when BOTTOMLEFTCORNER =>

    when BOTTOMSIDE =>

    WHEN BOTTOMRIGHTCORNER =>

end case;

#  0  1     4  5    8  9    12 13
#  2 (3     6) 7    10 11   14 15
#  0 (1     0) 1    0  1    0  1
#  2  3     2  3    2  3    2  3

#  0  1     0  1    0  1    0  1
#  2  3     2  3    2  3    2  3

#  0  1     0  1    0  1    0  1
#  2  3     2  3    2  3    2  3
