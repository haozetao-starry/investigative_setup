// OLED Display Controller — renders filter type text to framebuffer

module oled_display (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  filter_type,
    input  wire        model_valid,
    output reg  [9:0]  fb_wr_addr,
    output reg  [7:0]  fb_wr_data,
    output reg         fb_wren,
    output reg         refresh_req,
    input  wire        ssd1306_busy,
    input  wire        ssd1306_init_done,
    output reg  [6:0]  font_char,
    output reg  [3:0]  font_row,
    input  wire [7:0]  font_pixel
);

    localparam [2:0] S_IDLE      = 3'd0;
    localparam [2:0] S_CLEAR     = 3'd1;
    localparam [2:0] S_READ_FONT = 3'd2;
    localparam [2:0] S_WRITE_COL = 3'd3;
    localparam [2:0] S_REFRESH   = 3'd4;

    reg [2:0] state;
    reg       model_valid_d1;
    wire      trigger = model_valid && !model_valid_d1;

    // Display layout: pages 3-4 (rows 24-39), centered
    localparam [2:0] PAGE_BASE = 3'd3;
    localparam [6:0] COL_BASE  = 7'd32;   // (128-64)/2 for 8 chars

    reg [9:0]  clear_cnt;
    reg [2:0]  char_idx;
    reg [3:0]  font_row_cnt;
    reg [3:0]  col_cnt;
    reg [7:0]  font_buf [0:15];
    reg [6:0]  disp_str [0:7];
    reg [3:0]  num_chars;      // FIXED: 4-bit to hold 0..8

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            model_valid_d1 <= 1'b0;
            clear_cnt   <= 10'd0;
            char_idx    <= 3'd0;
            font_row_cnt<= 4'd0;
            col_cnt     <= 4'd0;
            fb_wren     <= 1'b0;
            refresh_req <= 1'b0;
            num_chars   <= 4'd0;
            for (i = 0; i < 16; i = i + 1) font_buf[i] <= 8'd0;
        end else begin
            model_valid_d1 <= model_valid;
            fb_wren   <= 1'b0;
            refresh_req <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (trigger && ssd1306_init_done) begin
                        case (filter_type)
                            3'd0: begin disp_str[0]="U";disp_str[1]="N";disp_str[2]="K";disp_str[3]="N";disp_str[4]="O";disp_str[5]="W";disp_str[6]="N";disp_str[7]=" "; num_chars=4'd8; end
                            3'd1: begin disp_str[0]="L";disp_str[1]="O";disp_str[2]="W";disp_str[3]="P";disp_str[4]="A";disp_str[5]="S";disp_str[6]="S";disp_str[7]=" "; num_chars=4'd8; end
                            3'd2: begin disp_str[0]="H";disp_str[1]="I";disp_str[2]="G";disp_str[3]="H";disp_str[4]="P";disp_str[5]="A";disp_str[6]="S";disp_str[7]="S"; num_chars=4'd8; end
                            3'd3: begin disp_str[0]="B";disp_str[1]="A";disp_str[2]="N";disp_str[3]="D";disp_str[4]="P";disp_str[5]="A";disp_str[6]="S";disp_str[7]="S"; num_chars=4'd8; end
                            3'd4: begin disp_str[0]="N";disp_str[1]="O";disp_str[2]="T";disp_str[3]="C";disp_str[4]="H";disp_str[5]=" ";disp_str[6]=" ";disp_str[7]=" "; num_chars=4'd5; end
                            3'd5: begin disp_str[0]="A";disp_str[1]="L";disp_str[2]="L";disp_str[3]="P";disp_str[4]="A";disp_str[5]="S";disp_str[6]="S";disp_str[7]=" "; num_chars=4'd8; end
                            default: begin disp_str[0]="?";disp_str[1]="?";disp_str[2]="?";disp_str[3]=" ";disp_str[4]=" ";disp_str[5]=" ";disp_str[6]=" ";disp_str[7]=" "; num_chars=4'd3; end
                        endcase
                        clear_cnt <= 10'd0; char_idx <= 3'd0; state <= S_CLEAR;
                    end
                end

                S_CLEAR: begin
                    fb_wr_addr <= clear_cnt; fb_wr_data <= 8'h00; fb_wren <= 1'b1;
                    if (clear_cnt == 10'd1023) begin
                        font_row_cnt <= 4'd0; char_idx <= 3'd0; state <= S_READ_FONT;
                    end else clear_cnt <= clear_cnt + 10'd1;
                end

                S_READ_FONT: begin
                    font_char <= disp_str[char_idx];
                    font_row  <= font_row_cnt;
                    font_buf[font_row_cnt] <= font_pixel;
                    if (font_row_cnt == 4'd15) begin col_cnt <= 4'd0; state <= S_WRITE_COL; end
                    else font_row_cnt <= font_row_cnt + 4'd1;
                end

                S_WRITE_COL: begin
                    fb_wren <= 1'b1;
                    // col_cnt 0..7: page_base, col_cnt 8..15: page_base+1
                    if (col_cnt < 4'd8) begin
                        fb_wr_addr <= (PAGE_BASE * 128) + COL_BASE + (char_idx * 8) + (7 - col_cnt[2:0]);
                        fb_wr_data <= {font_buf[7][7-col_cnt[2:0]], font_buf[6][7-col_cnt[2:0]],
                                       font_buf[5][7-col_cnt[2:0]], font_buf[4][7-col_cnt[2:0]],
                                       font_buf[3][7-col_cnt[2:0]], font_buf[2][7-col_cnt[2:0]],
                                       font_buf[1][7-col_cnt[2:0]], font_buf[0][7-col_cnt[2:0]]};
                    end else begin
                        fb_wr_addr <= ((PAGE_BASE + 1) * 128) + COL_BASE + (char_idx * 8) + (7 - (col_cnt[2:0] - 3'd4));  // FIXED: col_cnt-8 remapped
                        fb_wr_data <= {font_buf[15][7-(col_cnt[2:0]-3'd4)], font_buf[14][7-(col_cnt[2:0]-3'd4)],
                                       font_buf[13][7-(col_cnt[2:0]-3'd4)], font_buf[12][7-(col_cnt[2:0]-3'd4)],
                                       font_buf[11][7-(col_cnt[2:0]-3'd4)], font_buf[10][7-(col_cnt[2:0]-3'd4)],
                                       font_buf[9][7-(col_cnt[2:0]-3'd4)],  font_buf[8][7-(col_cnt[2:0]-3'd4)]};
                    end

                    if (col_cnt == 4'd15) begin
                        if (char_idx == (num_chars - 1)) state <= S_REFRESH;
                        else begin char_idx <= char_idx + 3'd1; font_row_cnt <= 4'd0; state <= S_READ_FONT; end
                    end else col_cnt <= col_cnt + 4'd1;
                end

                S_REFRESH: begin
                    if (!ssd1306_busy) begin refresh_req <= 1'b1; state <= S_IDLE; end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
