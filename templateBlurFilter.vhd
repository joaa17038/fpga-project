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
        if heightTracker = HEIGHT-4 then
            state <= BOTTOMLEFTCORNER;
        else
            state <= LEFTSIDE;
        end if;

    when LEFTSIDE =>
        output1 <= (upperRow(0) + upperRow(1)
                 + lowerRow(0) + lowerRow(1)
                 + m_axi_data(0) + m_axi_data(1)) // 6;
        output2 <= (lowerRow(0) + lowerRow(1)
                 + m_axi_data(0) + m_axi_data(1)
                 + m_axi_data(2) + m_axi_data(3)) // 6;

        previousBlock <= m_axi_data;
        blockTracker <= blockTracker + 4;
        widthTracker <= widthTracker + 2;
        state <= MIDDLE;

    when MIDDLE =>
        output1 <= (upperRow(0+blockTracker) + upperRow(1+blockTracker) + upperRow(2+blockTracker)
                 + lowerRow(0+blockTracker) + lowerRow(1+blockTracker) + lowerRow(2+blockTracker)
                 + previousBlock(0) + previousBlock(1) + m_axi_data(0)) // 9;
        output2 <= (upperRow(1+blockTracker) + upperRow(2+blockTracker) + upperRow(3+blockTracker)
                 + lowerRow(1+blockTracker) + lowerRow(2+blockTracker) + lowerRow(3+blockTracker)
                 + previousBlock(1) + m_axi_data(0) + m_axi_data(1)) // 9;
        output3 <= (lowerRow(0+blockTracker) + lowerRow(1+blockTracker) + lowerRow(2+blockTracker)
                 + previousBlock(0) + previousBlock(1) + m_axi_data(0)
                 + previousBlock(2) + previousBlock(3) + m_axi_data(2)) // 9;
        output4 <= (lowerRow(1+blockTracker) + lowerRow(2+blockTracker) + lowerRow(3+blockTracker)
                 + previousBlock(1+blockTracker) + m_axi_data(0) + m_axi_data(1)
                 + previousBlock(3) + m_axi_data(2) + m_axi_data(3)) // 9;

        previousBlock <= m_axi_data;
        blockTracker <= blockTracker + 4;
        widthTracker <= widthTracker + 2;
        if widthTracker = WIDTH-3 then
            state <= RIGHTSIDE;
        end if;

    when RIGHTSIDE =>
        output1 <= (upperRow(0+blockTracker) + upperRow(1+blockTracker) + upperRow(2+blockTracker)
                 + lowerRow(0+blockTracker) + lowerRow(1+blockTracker)  + lowerRow(2+blockTracker)
                 + previousBlock(0) + previousBlock(1) + m_axi_data(0)) // 9;

        output2 <= (upperRow(1+blockTracker) + upperRow(2+blockTracker) + upperRow(3+blockTracker)
                 + lowerRow(1+blockTracker) + lowerRow(2+blockTracker) + lowerRow(3+blockTracker)
                 + previousBlock(1) + m_axi_data(0) + m_axi_data(1)) // 9;

        output3 <= (upperRow(2+blockTracker) + upperRow(3+blockTracker)
                 + lowerRow(2+blockTracker) + lowerRow(3+blockTracker)
                 + m_axi_data(0) + m_axi_data(1)) // 6;

        output4 <= (lowerRow(0+blockTracker) + lowerRow(1+blockTracker) + lowerRow(2+blockTracker),
                 + previousBlock(0) + previousBlock(1) + m_axi_data(0)
                 + previousBlock(2) + previousBlock(3) + m_axi_data(2)) // 9;

        output5 <= (lowerRow(1+blockTracker) + lowerRow(2+blockTracker) + lowerRow(3+blockTracker),
                 + previousBlock(1) + m_axi_data(0) + m_axi_data(1)
                 + previousBlock(3) + m_axi_data(2) + m_axi_data(3)) // 9;

        output6 <= (lowerRow(2+blockTracker) + lowerRow(3+blockTracker)
                 + m_axi_data(0) + m_axi_data(1)
                 + m_axi_data(2) + m_axi_data(3)) // 6;

        previousBlock <= (others => (others => '0'));
        widthTracker <= (others => '0');
        blockTracker <= (others => '0');
        heightTracker <= heightTracker + 2;
        if heightTracker = HEIGHT-4 then
            state <= BOTTOMLEFTCORNER;
        else
            state <= LEFTSIDE;
        end if;

    when BOTTOMLEFTCORNER =>
        output1 <= (upperRow(0) + upperRow(1)
                 + lowerRow(0) + lowerRow(1)
                 + m_axi_data(0) + m_axi_data(1)) // 6;
        output2 <= (lowerRow(0) + lowerRow(1)
                 + m_axi_data(0) + m_axi_data(1)
                 + m_axi_data(2) + m_axi_data(3)) // 6;
        output3 <= (m_axi_data(0) + m_axi_data(1)
                 + m_axi_data(2) + m_axi_data(3)) // 4;

        previousBlock <= m_axi_data;
        widthTracker <= widthTracker + 1;
        state <= BOTTOMSIDE;

        #  0  1     4  5    8  9    12 13
        #  2 (3     6) 7    10 11   14 15

    when BOTTOMSIDE =>
        output1 <= (upperRow(1+blockTracker) + upperRow(2+blockTracker) + upperRow(3+blockTracker)
                 + lowerRow(1+blockTracker) + lowerRow(2+blockTracker) + lowerRow(3+blockTracker)
                 + previousBlock(1) + );
        output2 <= ();
        output3 <= ();
        output4 <= ();
        output5 <= ();
        output6 <= ();

        previousBlock <= m_axi_data;
        blockTracker <= blockTracker + 4;
        widthTracker <= widthTracker + 2;
        if widthTracker = WIDTH-3 then
            state <= BOTTOMRIGHTCORNER
        end if;

    WHEN BOTTOMRIGHTCORNER =>
        output1 <= ();
        output2 <= ();
        output3 <= ();
        output4 <= ();
        output5 <= ();
        output6 <= ();

        s_axi_valid <= '0';

end case;
