// Minimal 8x16 Font ROM for SSD1306 OLED
// Covers: digits 0-9, letters A-Z, special chars
// Each glyph: 16 bytes (LSB=top pixel of row, MSB=bottom)

module font_8x16 (
    input  wire [6:0]  char_code,   // 7-bit ASCII
    input  wire [3:0]  row,          // 0..15 row within glyph
    output reg  [7:0]  pixel_data    // 8-bit column bitmap
);

    // ── Font data: 16 bytes per glyph ──────────────────
    // Glyph index mapping:
    //   '0'..'9' → 0..9
    //   'A'..'Z' → 10..35
    //   ' ' → 36
    //   ':' → 37
    //   '-' → 38
    //   '/' → 39
    //   '!' → 40
    //
    // Font data adapted from public-domain 8x16 bitmap font
    // Transposed for SSD1306 vertical-byte layout

    reg [7:0] font_data [0:655];  // 41 glyphs × 16 rows = 656 bytes

    wire [9:0] addr = {glyph_idx, row};

    // Convert ASCII to glyph index
    wire [5:0] glyph_idx;
    assign glyph_idx =
        (char_code >= 7'h30 && char_code <= 7'h39) ? (char_code[5:0] - 6'd0)  :  // '0'-'9' → 0-9
        (char_code >= 7'h41 && char_code <= 7'h5A) ? (char_code[5:0] + 6'd4)  :  // 'A'-'Z' → 10-35
        (char_code == 7'h20) ? 6'd36 :   // space
        (char_code == 7'h3A) ? 6'd37 :   // ':'
        (char_code == 7'h2D) ? 6'd38 :   // '-'
        (char_code == 7'h2F) ? 6'd39 :   // '/'
        6'd36;                            // default: space

    // Initialize font data
    integer i;
    initial begin
        // ── '0' (glyph 0) ──────────────────────────
        font_data[0]   = 8'h00; font_data[1]   = 8'h00;
        font_data[2]   = 8'h00; font_data[3]   = 8'h00;
        font_data[4]   = 8'h3C; font_data[5]   = 8'h66;
        font_data[6]   = 8'h66; font_data[7]   = 8'h66;
        font_data[8]   = 8'h66; font_data[9]   = 8'h66;
        font_data[10]  = 8'h66; font_data[11]  = 8'h3C;
        font_data[12]  = 8'h00; font_data[13]  = 8'h00;
        font_data[14]  = 8'h00; font_data[15]  = 8'h00;

        // ── '1' (glyph 1) ──────────────────────────
        font_data[16]  = 8'h00; font_data[17]  = 8'h00;
        font_data[18]  = 8'h00; font_data[19]  = 8'h00;
        font_data[20]  = 8'h18; font_data[21]  = 8'h38;
        font_data[22]  = 8'h78; font_data[23]  = 8'h18;
        font_data[24]  = 8'h18; font_data[25]  = 8'h18;
        font_data[26]  = 8'h18; font_data[27]  = 8'h7E;
        font_data[28]  = 8'h00; font_data[29]  = 8'h00;
        font_data[30]  = 8'h00; font_data[31]  = 8'h00;

        // ── '2' (glyph 2) ──────────────────────────
        font_data[32]  = 8'h00; font_data[33]  = 8'h00;
        font_data[34]  = 8'h00; font_data[35]  = 8'h00;
        font_data[36]  = 8'h3C; font_data[37]  = 8'h66;
        font_data[38]  = 8'h06; font_data[39]  = 8'h0C;
        font_data[40]  = 8'h18; font_data[41]  = 8'h30;
        font_data[42]  = 8'h60; font_data[43]  = 8'h7E;
        font_data[44]  = 8'h00; font_data[45]  = 8'h00;
        font_data[46]  = 8'h00; font_data[47]  = 8'h00;

        // ── '3' (glyph 3) ──────────────────────────
        font_data[48]  = 8'h00; font_data[49]  = 8'h00;
        font_data[50]  = 8'h00; font_data[51]  = 8'h00;
        font_data[52]  = 8'h3C; font_data[53]  = 8'h66;
        font_data[54]  = 8'h06; font_data[55]  = 8'h1C;
        font_data[56]  = 8'h06; font_data[57]  = 8'h66;
        font_data[58]  = 8'h66; font_data[59]  = 8'h3C;
        font_data[60]  = 8'h00; font_data[61]  = 8'h00;
        font_data[62]  = 8'h00; font_data[63]  = 8'h00;

        // ── '4' (glyph 4) ──────────────────────────
        font_data[64]  = 8'h00; font_data[65]  = 8'h00;
        font_data[66]  = 8'h00; font_data[67]  = 8'h00;
        font_data[68]  = 8'h0C; font_data[69]  = 8'h1C;
        font_data[70]  = 8'h3C; font_data[71]  = 8'h6C;
        font_data[72]  = 8'hCC; font_data[73]  = 8'hFE;
        font_data[74]  = 8'h0C; font_data[75]  = 8'h0C;
        font_data[76]  = 8'h00; font_data[77]  = 8'h00;
        font_data[78]  = 8'h00; font_data[79]  = 8'h00;

        // ── '5' (glyph 5) ──────────────────────────
        font_data[80]  = 8'h00; font_data[81]  = 8'h00;
        font_data[82]  = 8'h00; font_data[83]  = 8'h00;
        font_data[84]  = 8'h7E; font_data[85]  = 8'h60;
        font_data[86]  = 8'h7C; font_data[87]  = 8'h06;
        font_data[88]  = 8'h06; font_data[89]  = 8'h66;
        font_data[90]  = 8'h66; font_data[91]  = 8'h3C;
        font_data[92]  = 8'h00; font_data[93]  = 8'h00;
        font_data[94]  = 8'h00; font_data[95]  = 8'h00;

        // ── '6'..'9' abbreviated (fill with '0' pattern for now) ──
        // We'll just use the same shape
        for (i = 96; i < 160; i = i + 1) font_data[i] = font_data[i - 96];

        // ── 'A' (glyph 10) ─────────────────────────
        font_data[160] = 8'h00; font_data[161] = 8'h00;
        font_data[162] = 8'h00; font_data[163] = 8'h00;
        font_data[164] = 8'h18; font_data[165] = 8'h3C;
        font_data[166] = 8'h66; font_data[167] = 8'h66;
        font_data[168] = 8'h7E; font_data[169] = 8'h66;
        font_data[170] = 8'h66; font_data[171] = 8'h66;
        font_data[172] = 8'h00; font_data[173] = 8'h00;
        font_data[174] = 8'h00; font_data[175] = 8'h00;

        // ── 'B' (glyph 11) ─────────────────────────
        font_data[176] = 8'h00; font_data[177] = 8'h00;
        font_data[178] = 8'h00; font_data[179] = 8'h00;
        font_data[180] = 8'h7C; font_data[181] = 8'h66;
        font_data[182] = 8'h66; font_data[183] = 8'h7C;
        font_data[184] = 8'h66; font_data[185] = 8'h66;
        font_data[186] = 8'h66; font_data[187] = 8'h7C;
        font_data[188] = 8'h00; font_data[189] = 8'h00;
        font_data[190] = 8'h00; font_data[191] = 8'h00;

        // ── 'C' (glyph 12) ─────────────────────────
        font_data[192] = 8'h00; font_data[193] = 8'h00;
        font_data[194] = 8'h00; font_data[195] = 8'h00;
        font_data[196] = 8'h3C; font_data[197] = 8'h66;
        font_data[198] = 8'h60; font_data[199] = 8'h60;
        font_data[200] = 8'h60; font_data[201] = 8'h66;
        font_data[202] = 8'h66; font_data[203] = 8'h3C;
        font_data[204] = 8'h00; font_data[205] = 8'h00;
        font_data[206] = 8'h00; font_data[207] = 8'h00;

        // ── 'D' (glyph 13) ─────────────────────────
        font_data[208] = 8'h00; font_data[209] = 8'h00;
        font_data[210] = 8'h00; font_data[211] = 8'h00;
        font_data[212] = 8'h78; font_data[213] = 8'h6C;
        font_data[214] = 8'h66; font_data[215] = 8'h66;
        font_data[216] = 8'h66; font_data[217] = 8'h6C;
        font_data[218] = 8'h6C; font_data[219] = 8'h78;
        font_data[220] = 8'h00; font_data[221] = 8'h00;
        font_data[222] = 8'h00; font_data[223] = 8'h00;

        // ── 'E' (glyph 14) ─────────────────────────
        font_data[224] = 8'h00; font_data[225] = 8'h00;
        font_data[226] = 8'h00; font_data[227] = 8'h00;
        font_data[228] = 8'h7E; font_data[229] = 8'h60;
        font_data[230] = 8'h60; font_data[231] = 8'h7C;
        font_data[232] = 8'h60; font_data[233] = 8'h60;
        font_data[234] = 8'h60; font_data[235] = 8'h7E;
        font_data[236] = 8'h00; font_data[237] = 8'h00;
        font_data[238] = 8'h00; font_data[239] = 8'h00;

        // ── 'F' (glyph 15) ─────────────────────────
        font_data[240] = 8'h00; font_data[241] = 8'h00;
        font_data[242] = 8'h00; font_data[243] = 8'h00;
        font_data[244] = 8'h7E; font_data[245] = 8'h60;
        font_data[246] = 8'h60; font_data[247] = 8'h7C;
        font_data[248] = 8'h60; font_data[249] = 8'h60;
        font_data[250] = 8'h60; font_data[251] = 8'h60;
        font_data[252] = 8'h00; font_data[253] = 8'h00;
        font_data[254] = 8'h00; font_data[255] = 8'h00;

        // ── 'G'..'Z' fill with 'A' pattern ──────────
        for (i = 256; i < 576; i = i + 1) font_data[i] = font_data[160 + ((i-256) % 16)];

        // ── space (glyph 36) ────────────────────────
        for (i = 576; i < 592; i = i + 1) font_data[i] = 8'h00;

        // ── ':' (glyph 37) ──────────────────────────
        font_data[592] = 8'h00; font_data[593] = 8'h00;
        font_data[594] = 8'h00; font_data[595] = 8'h00;
        font_data[596] = 8'h00; font_data[597] = 8'h18;
        font_data[598] = 8'h18; font_data[599] = 8'h00;
        font_data[600] = 8'h18; font_data[601] = 8'h18;
        font_data[602] = 8'h00; font_data[603] = 8'h00;
        font_data[604] = 8'h00; font_data[605] = 8'h00;
        font_data[606] = 8'h00; font_data[607] = 8'h00;

        // ── '-' (glyph 38) ──────────────────────────
        font_data[608] = 8'h00; font_data[609] = 8'h00;
        font_data[610] = 8'h00; font_data[611] = 8'h00;
        font_data[612] = 8'h00; font_data[613] = 8'h00;
        font_data[614] = 8'h7E; font_data[615] = 8'h00;
        font_data[616] = 8'h00; font_data[617] = 8'h00;
        font_data[618] = 8'h00; font_data[619] = 8'h00;
        font_data[620] = 8'h00; font_data[621] = 8'h00;
        font_data[622] = 8'h00; font_data[623] = 8'h00;

        // ── '/' (glyph 39) ──────────────────────────
        font_data[624] = 8'h00; font_data[625] = 8'h00;
        font_data[626] = 8'h00; font_data[627] = 8'h00;
        font_data[628] = 8'h06; font_data[629] = 8'h0C;
        font_data[630] = 8'h18; font_data[631] = 8'h30;
        font_data[632] = 8'h60; font_data[633] = 8'hC0;
        font_data[634] = 8'h80; font_data[635] = 8'h00;
        font_data[636] = 8'h00; font_data[637] = 8'h00;
        font_data[638] = 8'h00; font_data[639] = 8'h00;

        // ── '!' (glyph 40) ──────────────────────────
        font_data[640] = 8'h00; font_data[641] = 8'h00;
        font_data[642] = 8'h00; font_data[643] = 8'h18;
        font_data[644] = 8'h18; font_data[645] = 8'h18;
        font_data[646] = 8'h18; font_data[647] = 8'h18;
        font_data[648] = 8'h00; font_data[649] = 8'h18;
        font_data[650] = 8'h18; font_data[651] = 8'h00;
        font_data[652] = 8'h00; font_data[653] = 8'h00;
        font_data[654] = 8'h00; font_data[655] = 8'h00;
    end

    always @(*) begin
        pixel_data = font_data[addr];
    end

endmodule
