// 8x16 Font ROM for SSD1306 OLED
// 19 glyphs: A,B,C,D,G,H,I,K,L,N,O,P,S,T,U,W,?,space
// Each glyph: 16 bytes, LSB = pixel row low, MSB = pixel row high
// Horizontal: bit7=left, bit0=right

module font_8x16 (
    input  wire [6:0]  char_code,
    input  wire [3:0]  row,
    output reg  [7:0]  pixel_data
);

    // Map ASCII to glyph index 0..18
    wire [4:0] gidx =
        (char_code == 7'h41) ? 5'd0  :  // A
        (char_code == 7'h42) ? 5'd1  :  // B
        (char_code == 7'h43) ? 5'd2  :  // C
        (char_code == 7'h44) ? 5'd3  :  // D
        (char_code == 7'h47) ? 5'd4  :  // G
        (char_code == 7'h48) ? 5'd5  :  // H
        (char_code == 7'h49) ? 5'd6  :  // I
        (char_code == 7'h4B) ? 5'd7  :  // K
        (char_code == 7'h4C) ? 5'd8  :  // L
        (char_code == 7'h4E) ? 5'd9  :  // N
        (char_code == 7'h4F) ? 5'd10 :  // O
        (char_code == 7'h50) ? 5'd11 :  // P
        (char_code == 7'h53) ? 5'd12 :  // S
        (char_code == 7'h54) ? 5'd13 :  // T
        (char_code == 7'h55) ? 5'd14 :  // U
        (char_code == 7'h57) ? 5'd15 :  // W
        (char_code == 7'h3F) ? 5'd16 :  // ?
        (char_code == 7'h20) ? 5'd17 :  // space
        5'd17;  // default: space

    wire [8:0] addr = {gidx, row};  // 5+4 = 9 bits, 0..303

    always @(*) begin
        case (addr)
            // ── 'A' (glyph 0) ──────────────────────────
            9'h000: pixel_data = 8'h00; 9'h001: pixel_data = 8'h00;
            9'h002: pixel_data = 8'h00; 9'h003: pixel_data = 8'h00;
            9'h004: pixel_data = 8'h18; 9'h005: pixel_data = 8'h3C;
            9'h006: pixel_data = 8'h66; 9'h007: pixel_data = 8'h66;
            9'h008: pixel_data = 8'h7E; 9'h009: pixel_data = 8'h66;
            9'h00A: pixel_data = 8'h66; 9'h00B: pixel_data = 8'h66;
            9'h00C: pixel_data = 8'h00; 9'h00D: pixel_data = 8'h00;
            9'h00E: pixel_data = 8'h00; 9'h00F: pixel_data = 8'h00;
            // ── 'B' ────────────────────────────────────
            9'h010: pixel_data = 8'h00; 9'h011: pixel_data = 8'h00;
            9'h012: pixel_data = 8'h00; 9'h013: pixel_data = 8'h00;
            9'h014: pixel_data = 8'h7C; 9'h015: pixel_data = 8'h66;
            9'h016: pixel_data = 8'h66; 9'h017: pixel_data = 8'h7C;
            9'h018: pixel_data = 8'h66; 9'h019: pixel_data = 8'h66;
            9'h01A: pixel_data = 8'h66; 9'h01B: pixel_data = 8'h7C;
            9'h01C: pixel_data = 8'h00; 9'h01D: pixel_data = 8'h00;
            9'h01E: pixel_data = 8'h00; 9'h01F: pixel_data = 8'h00;
            // ── 'C' ────────────────────────────────────
            9'h020: pixel_data = 8'h00; 9'h021: pixel_data = 8'h00;
            9'h022: pixel_data = 8'h00; 9'h023: pixel_data = 8'h00;
            9'h024: pixel_data = 8'h3C; 9'h025: pixel_data = 8'h66;
            9'h026: pixel_data = 8'h60; 9'h027: pixel_data = 8'h60;
            9'h028: pixel_data = 8'h60; 9'h029: pixel_data = 8'h66;
            9'h02A: pixel_data = 8'h66; 9'h02B: pixel_data = 8'h3C;
            9'h02C: pixel_data = 8'h00; 9'h02D: pixel_data = 8'h00;
            9'h02E: pixel_data = 8'h00; 9'h02F: pixel_data = 8'h00;
            // ── 'D' ────────────────────────────────────
            9'h030: pixel_data = 8'h00; 9'h031: pixel_data = 8'h00;
            9'h032: pixel_data = 8'h00; 9'h033: pixel_data = 8'h00;
            9'h034: pixel_data = 8'h78; 9'h035: pixel_data = 8'h6C;
            9'h036: pixel_data = 8'h66; 9'h037: pixel_data = 8'h66;
            9'h038: pixel_data = 8'h66; 9'h039: pixel_data = 8'h6C;
            9'h03A: pixel_data = 8'h6C; 9'h03B: pixel_data = 8'h78;
            9'h03C: pixel_data = 8'h00; 9'h03D: pixel_data = 8'h00;
            9'h03E: pixel_data = 8'h00; 9'h03F: pixel_data = 8'h00;
            // ── 'G' ────────────────────────────────────
            9'h040: pixel_data = 8'h00; 9'h041: pixel_data = 8'h00;
            9'h042: pixel_data = 8'h00; 9'h043: pixel_data = 8'h00;
            9'h044: pixel_data = 8'h3C; 9'h045: pixel_data = 8'h66;
            9'h046: pixel_data = 8'h60; 9'h047: pixel_data = 8'h6E;
            9'h048: pixel_data = 8'h66; 9'h049: pixel_data = 8'h66;
            9'h04A: pixel_data = 8'h66; 9'h04B: pixel_data = 8'h3C;
            9'h04C: pixel_data = 8'h00; 9'h04D: pixel_data = 8'h00;
            9'h04E: pixel_data = 8'h00; 9'h04F: pixel_data = 8'h00;
            // ── 'H' ────────────────────────────────────
            9'h050: pixel_data = 8'h00; 9'h051: pixel_data = 8'h00;
            9'h052: pixel_data = 8'h00; 9'h053: pixel_data = 8'h00;
            9'h054: pixel_data = 8'h66; 9'h055: pixel_data = 8'h66;
            9'h056: pixel_data = 8'h66; 9'h057: pixel_data = 8'h7E;
            9'h058: pixel_data = 8'h66; 9'h059: pixel_data = 8'h66;
            9'h05A: pixel_data = 8'h66; 9'h05B: pixel_data = 8'h66;
            9'h05C: pixel_data = 8'h00; 9'h05D: pixel_data = 8'h00;
            9'h05E: pixel_data = 8'h00; 9'h05F: pixel_data = 8'h00;
            // ── 'I' ────────────────────────────────────
            9'h060: pixel_data = 8'h00; 9'h061: pixel_data = 8'h00;
            9'h062: pixel_data = 8'h00; 9'h063: pixel_data = 8'h00;
            9'h064: pixel_data = 8'h3C; 9'h065: pixel_data = 8'h18;
            9'h066: pixel_data = 8'h18; 9'h067: pixel_data = 8'h18;
            9'h068: pixel_data = 8'h18; 9'h069: pixel_data = 8'h18;
            9'h06A: pixel_data = 8'h18; 9'h06B: pixel_data = 8'h3C;
            9'h06C: pixel_data = 8'h00; 9'h06D: pixel_data = 8'h00;
            9'h06E: pixel_data = 8'h00; 9'h06F: pixel_data = 8'h00;
            // ── 'K' ────────────────────────────────────
            9'h070: pixel_data = 8'h00; 9'h071: pixel_data = 8'h00;
            9'h072: pixel_data = 8'h00; 9'h073: pixel_data = 8'h00;
            9'h074: pixel_data = 8'h66; 9'h075: pixel_data = 8'h6C;
            9'h076: pixel_data = 8'h78; 9'h077: pixel_data = 8'h70;
            9'h078: pixel_data = 8'h78; 9'h079: pixel_data = 8'h6C;
            9'h07A: pixel_data = 8'h66; 9'h07B: pixel_data = 8'h66;
            9'h07C: pixel_data = 8'h00; 9'h07D: pixel_data = 8'h00;
            9'h07E: pixel_data = 8'h00; 9'h07F: pixel_data = 8'h00;
            // ── 'L' ────────────────────────────────────
            9'h080: pixel_data = 8'h00; 9'h081: pixel_data = 8'h00;
            9'h082: pixel_data = 8'h00; 9'h083: pixel_data = 8'h00;
            9'h084: pixel_data = 8'h60; 9'h085: pixel_data = 8'h60;
            9'h086: pixel_data = 8'h60; 9'h087: pixel_data = 8'h60;
            9'h088: pixel_data = 8'h60; 9'h089: pixel_data = 8'h60;
            9'h08A: pixel_data = 8'h60; 9'h08B: pixel_data = 8'h7E;
            9'h08C: pixel_data = 8'h00; 9'h08D: pixel_data = 8'h00;
            9'h08E: pixel_data = 8'h00; 9'h08F: pixel_data = 8'h00;
            // ── 'N' ────────────────────────────────────
            9'h090: pixel_data = 8'h00; 9'h091: pixel_data = 8'h00;
            9'h092: pixel_data = 8'h00; 9'h093: pixel_data = 8'h00;
            9'h094: pixel_data = 8'h66; 9'h095: pixel_data = 8'h76;
            9'h096: pixel_data = 8'h7E; 9'h097: pixel_data = 8'h6E;
            9'h098: pixel_data = 8'h66; 9'h099: pixel_data = 8'h66;
            9'h09A: pixel_data = 8'h66; 9'h09B: pixel_data = 8'h66;
            9'h09C: pixel_data = 8'h00; 9'h09D: pixel_data = 8'h00;
            9'h09E: pixel_data = 8'h00; 9'h09F: pixel_data = 8'h00;
            // ── 'O' ────────────────────────────────────
            9'h0A0: pixel_data = 8'h00; 9'h0A1: pixel_data = 8'h00;
            9'h0A2: pixel_data = 8'h00; 9'h0A3: pixel_data = 8'h00;
            9'h0A4: pixel_data = 8'h3C; 9'h0A5: pixel_data = 8'h66;
            9'h0A6: pixel_data = 8'h66; 9'h0A7: pixel_data = 8'h66;
            9'h0A8: pixel_data = 8'h66; 9'h0A9: pixel_data = 8'h66;
            9'h0AA: pixel_data = 8'h66; 9'h0AB: pixel_data = 8'h3C;
            9'h0AC: pixel_data = 8'h00; 9'h0AD: pixel_data = 8'h00;
            9'h0AE: pixel_data = 8'h00; 9'h0AF: pixel_data = 8'h00;
            // ── 'P' ────────────────────────────────────
            9'h0B0: pixel_data = 8'h00; 9'h0B1: pixel_data = 8'h00;
            9'h0B2: pixel_data = 8'h00; 9'h0B3: pixel_data = 8'h00;
            9'h0B4: pixel_data = 8'h7C; 9'h0B5: pixel_data = 8'h66;
            9'h0B6: pixel_data = 8'h66; 9'h0B7: pixel_data = 8'h7C;
            9'h0B8: pixel_data = 8'h60; 9'h0B9: pixel_data = 8'h60;
            9'h0BA: pixel_data = 8'h60; 9'h0BB: pixel_data = 8'h60;
            9'h0BC: pixel_data = 8'h00; 9'h0BD: pixel_data = 8'h00;
            9'h0BE: pixel_data = 8'h00; 9'h0BF: pixel_data = 8'h00;
            // ── 'S' ────────────────────────────────────
            9'h0C0: pixel_data = 8'h00; 9'h0C1: pixel_data = 8'h00;
            9'h0C2: pixel_data = 8'h00; 9'h0C3: pixel_data = 8'h00;
            9'h0C4: pixel_data = 8'h3C; 9'h0C5: pixel_data = 8'h66;
            9'h0C6: pixel_data = 8'h60; 9'h0C7: pixel_data = 8'h3C;
            9'h0C8: pixel_data = 8'h06; 9'h0C9: pixel_data = 8'h66;
            9'h0CA: pixel_data = 8'h66; 9'h0CB: pixel_data = 8'h3C;
            9'h0CC: pixel_data = 8'h00; 9'h0CD: pixel_data = 8'h00;
            9'h0CE: pixel_data = 8'h00; 9'h0CF: pixel_data = 8'h00;
            // ── 'T' ────────────────────────────────────
            9'h0D0: pixel_data = 8'h00; 9'h0D1: pixel_data = 8'h00;
            9'h0D2: pixel_data = 8'h00; 9'h0D3: pixel_data = 8'h00;
            9'h0D4: pixel_data = 8'h7E; 9'h0D5: pixel_data = 8'h18;
            9'h0D6: pixel_data = 8'h18; 9'h0D7: pixel_data = 8'h18;
            9'h0D8: pixel_data = 8'h18; 9'h0D9: pixel_data = 8'h18;
            9'h0DA: pixel_data = 8'h18; 9'h0DB: pixel_data = 8'h18;
            9'h0DC: pixel_data = 8'h00; 9'h0DD: pixel_data = 8'h00;
            9'h0DE: pixel_data = 8'h00; 9'h0DF: pixel_data = 8'h00;
            // ── 'U' ────────────────────────────────────
            9'h0E0: pixel_data = 8'h00; 9'h0E1: pixel_data = 8'h00;
            9'h0E2: pixel_data = 8'h00; 9'h0E3: pixel_data = 8'h00;
            9'h0E4: pixel_data = 8'h66; 9'h0E5: pixel_data = 8'h66;
            9'h0E6: pixel_data = 8'h66; 9'h0E7: pixel_data = 8'h66;
            9'h0E8: pixel_data = 8'h66; 9'h0E9: pixel_data = 8'h66;
            9'h0EA: pixel_data = 8'h66; 9'h0EB: pixel_data = 8'h3C;
            9'h0EC: pixel_data = 8'h00; 9'h0ED: pixel_data = 8'h00;
            9'h0EE: pixel_data = 8'h00; 9'h0EF: pixel_data = 8'h00;
            // ── 'W' ────────────────────────────────────
            9'h0F0: pixel_data = 8'h00; 9'h0F1: pixel_data = 8'h00;
            9'h0F2: pixel_data = 8'h00; 9'h0F3: pixel_data = 8'h00;
            9'h0F4: pixel_data = 8'h66; 9'h0F5: pixel_data = 8'h66;
            9'h0F6: pixel_data = 8'h66; 9'h0F7: pixel_data = 8'h66;
            9'h0F8: pixel_data = 8'h7E; 9'h0F9: pixel_data = 8'h7E;
            9'h0FA: pixel_data = 8'h66; 9'h0FB: pixel_data = 8'h66;
            9'h0FC: pixel_data = 8'h00; 9'h0FD: pixel_data = 8'h00;
            9'h0FE: pixel_data = 8'h00; 9'h0FF: pixel_data = 8'h00;
            // ── '?' ────────────────────────────────────
            9'h100: pixel_data = 8'h00; 9'h101: pixel_data = 8'h00;
            9'h102: pixel_data = 8'h00; 9'h103: pixel_data = 8'h00;
            9'h104: pixel_data = 8'h3C; 9'h105: pixel_data = 8'h66;
            9'h106: pixel_data = 8'h06; 9'h107: pixel_data = 8'h0C;
            9'h108: pixel_data = 8'h18; 9'h109: pixel_data = 8'h18;
            9'h10A: pixel_data = 8'h00; 9'h10B: pixel_data = 8'h18;
            9'h10C: pixel_data = 8'h00; 9'h10D: pixel_data = 8'h00;
            9'h10E: pixel_data = 8'h00; 9'h10F: pixel_data = 8'h00;
            // ── space ──────────────────────────────────
            9'h110: pixel_data = 8'h00; 9'h111: pixel_data = 8'h00;
            9'h112: pixel_data = 8'h00; 9'h113: pixel_data = 8'h00;
            9'h114: pixel_data = 8'h00; 9'h115: pixel_data = 8'h00;
            9'h116: pixel_data = 8'h00; 9'h117: pixel_data = 8'h00;
            9'h118: pixel_data = 8'h00; 9'h119: pixel_data = 8'h00;
            9'h11A: pixel_data = 8'h00; 9'h11B: pixel_data = 8'h00;
            9'h11C: pixel_data = 8'h00; 9'h11D: pixel_data = 8'h00;
            9'h11E: pixel_data = 8'h00; 9'h11F: pixel_data = 8'h00;
            // ── default: space ──────────────────────────
            default: pixel_data = 8'h00;
        endcase
    end

endmodule
