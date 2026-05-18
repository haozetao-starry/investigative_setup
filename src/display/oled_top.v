// OLED Display Top-Level — SSD1306 128x64 I2C OLED
// Encapsulates: fb_ram, i2c_master, ssd1306_cmd, font_8x16, oled_display
// Simple interface: just connect filter_type and model_valid

module oled_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  filter_type,
    input  wire        model_valid,
    output wire        oled_scl,
    inout  wire        oled_sda
);

    // ── Internal wires ─────────────────────────────────
    wire [9:0]  fb_wr_addr, fb_rd_addr;
    wire [7:0]  fb_wr_data, fb_rd_data;
    wire        fb_wren;
    wire        refresh_req, ssd1306_bsy, ssd1306_init_done;
    wire        i2c_tx_start, i2c_tx_valid, i2c_tx_last, i2c_tx_ready;
    wire [7:0]  i2c_tx_dev, i2c_tx_byte;
    wire        i2c_bsy, i2c_done;
    wire [6:0]  font_char;
    wire [3:0]  font_row;
    wire [7:0]  font_pixel;

    // ══════════════════════════════════════════════════
    fb_ram u_fb (
        .clk    (clk),
        .wr_addr(fb_wr_addr), .wr_data(fb_wr_data), .wren(fb_wren),
        .rd_addr(fb_rd_addr), .rd_data(fb_rd_data)
    );

    i2c_master u_i2c (
        .clk(clk), .rst_n(rst_n),
        .tx_start(i2c_tx_start), .tx_dev_addr(i2c_tx_dev),
        .tx_byte(i2c_tx_byte), .tx_valid(i2c_tx_valid),
        .tx_ready(i2c_tx_ready), .tx_last(i2c_tx_last),
        .busy(i2c_bsy), .done(i2c_done),
        .scl(oled_scl), .sda(oled_sda)
    );

    font_8x16 u_font (
        .char_code(font_char), .row(font_row), .pixel_data(font_pixel)
    );

    ssd1306_cmd u_ssd (
        .clk(clk), .rst_n(rst_n),
        .fb_addr(fb_rd_addr), .fb_data(fb_rd_data),
        .refresh_req(refresh_req), .busy(ssd1306_bsy),
        .init_done(ssd1306_init_done),
        .i2c_tx_start(i2c_tx_start), .i2c_tx_dev(i2c_tx_dev),
        .i2c_tx_byte(i2c_tx_byte), .i2c_tx_valid(i2c_tx_valid),
        .i2c_tx_last(i2c_tx_last), .i2c_tx_ready(i2c_tx_ready),
        .i2c_bsy(i2c_bsy), .i2c_done(i2c_done)
    );

    oled_display u_disp (
        .clk(clk), .rst_n(rst_n),
        .filter_type(filter_type), .model_valid(model_valid),
        .fb_wr_addr(fb_wr_addr), .fb_wr_data(fb_wr_data), .fb_wren(fb_wren),
        .refresh_req(refresh_req),
        .ssd1306_busy(ssd1306_bsy), .ssd1306_init_done(ssd1306_init_done),
        .font_char(font_char), .font_row(font_row), .font_pixel(font_pixel)
    );

endmodule
