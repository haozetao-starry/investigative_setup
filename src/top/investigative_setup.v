module investigative_setup(
    input                 sys_clk,
    input                 sys_rst_n,
    output                da_clk,
    output      [7:0]     da_data,
    input       [7:0]     ad_data,
    input                 ad_otr,
    output                ad_clk,
    // ── OLED I2C ─────────────────────────────────
    output                oled_scl,
    inout                 oled_sda
);

    // ── STOP_WORD 统一定义 ──────────────────────────────
    localparam [31:0] STOP_WORD = 32'd1717987;  // ≈20kHz @ 50MHz

    wire [31:0] f_word;
    wire [8:0]  a_word = 9'd256;
    wire [7:0]  dds_wave;
    wire        sweep_phase_clr;
    wire        sweep_step_sync;
    wire        sweep_busy;
    wire        sweep_done;

    wire        ad_buf_full;
    wire        ad_otr_flag;
    wire        ad_acq_start;
    wire [15:0] ad_smp_div;
    wire        fft_start_en;
    wire        rls_start_en;
    wire        store_result_en;
    wire        classify_start;
    wire        store_clear;
    wire        sweep_restart;
    wire        fft_busy;
    wire        fft_done;
    wire [9:0]  fft_peak_freq_idx;
    wire [31:0] h_mag_q16;
    wire signed [15:0] h_phase_deg_q8;
    wire [2:0]  filter_type;
    wire        mimic_mode;
    wire        model_valid;
    wire [6:0]  sweep_result_count;
    wire [31:0] rls_avg_sq_err;

    wire [9:0]  capture_rd_addr;
    wire [9:0]  fft_rd_addr;
    wire [7:0]  ad_rd_data;
    wire [7:0]  ref_rd_data;

    wire signed [31:0] coeff_b0;
    wire signed [31:0] coeff_b1;
    wire signed [31:0] coeff_b2;
    wire signed [31:0] coeff_a1;
    wire signed [31:0] coeff_a2;
    wire        rls_busy;
    wire        rls_done;

    wire [7:0]  biquad_wave;
    wire [7:0]  da_src_data;

    wire [6:0]  cls_read_index;
    wire [31:0] cls_read_h_mag_q16;
    wire        cls_read_valid;
    wire        classifier_done;

    wire frame_last_for_rls = (f_word >= STOP_WORD);

    // ── OLED subsystem wires ────────────────────────────
    wire [9:0]  fb_wr_addr, fb_rd_addr;
    wire [7:0]  fb_wr_data, fb_rd_data;
    wire        fb_wren;
    wire        oled_refresh_req, ssd1306_bsy, ssd1306_init_done;
    // I2C byte-stream
    wire        i2c_tx_start;
    wire [7:0]  i2c_tx_dev, i2c_tx_byte;
    wire        i2c_tx_valid, i2c_tx_last, i2c_tx_ready;
    wire        i2c_bsy, i2c_done;
    // Font
    wire [6:0]  font_char;
    wire [3:0]  font_row;
    wire [7:0]  font_pixel;

    assign capture_rd_addr = fft_busy ? fft_rd_addr : 10'd0;
    assign da_src_data     = mimic_mode ? biquad_wave : dds_wave;

    // ══════════════════════════════════════════════════
    //  辨识流水线 (保持不变)
    // ══════════════════════════════════════════════════
    dds_sweep_ctrl #(
        .CLK_FREQ_HZ           (50000000),
        .START_FREQ_HZ         (20),
        .STOP_FREQ_HZ          (20000),
        .STEP_FREQ_HZ          (200),
        .STEP_PERIOD_CLKS      (2500000),
        .REPEAT_SWEEP          (1),
        .RESET_PHASE_EACH_STEP (1)
    ) u_dds_sweep_ctrl (
        .clk(sys_clk), .rst_n(sys_rst_n), .sweep_en(1'b1), .restart(sweep_restart),
        .f_word(f_word), .phase_clr(sweep_phase_clr), .step_sync(sweep_step_sync),
        .sweep_busy(sweep_busy), .sweep_done(sweep_done)
    );

    dds_top u_dds_top(
        .clk(sys_clk), .rst_n(sys_rst_n), .phase_clr(sweep_phase_clr),
        .f_word(f_word), .a_word(a_word), .wave_out(dds_wave)
    );

    acq_ctrl #(.STOP_WORD(STOP_WORD), .RLS_ERR_THRESHOLD(32'd26214400)) u_acq_ctrl(
        .clk(sys_clk), .rst_n(sys_rst_n), .f_word(f_word),
        .sweep_step_sync(sweep_step_sync), .ad_buf_full(ad_buf_full),
        .fft_done(fft_done), .rls_done(rls_done), .classifier_done(classifier_done),
        .rls_avg_sq_err(rls_avg_sq_err), .ad_acq_start(ad_acq_start),
        .ad_smp_div(ad_smp_div), .fft_start_en(fft_start_en),
        .rls_start_en(rls_start_en), .store_result_en(store_result_en),
        .classify_start(classify_start), .store_clear(store_clear),
        .sweep_restart(sweep_restart), .mimic_mode(mimic_mode), .model_valid(model_valid)
    );

    ad_wave_rec u_ad_wave_rec(
        .clk(sys_clk), .rst_n(sys_rst_n), .ad_data(ad_data), .ad_otr(ad_otr),
        .ref_data_in(dds_wave), .acq_start(ad_acq_start), .smp_div(ad_smp_div),
        .rd_addr(capture_rd_addr), .rd_en(1'b1), .ad_clk(ad_clk),
        .rd_data(ad_rd_data), .ref_rd_data(ref_rd_data),
        .buf_full(ad_buf_full), .otr_flag(ad_otr_flag)
    );

    fft_processor u_fft_processor(
        .clk(sys_clk), .rst_n(sys_rst_n), .fft_start_en(fft_start_en),
        .fft_busy(fft_busy), .fft_done(fft_done), .rd_addr(fft_rd_addr),
        .ref_rd_data(ref_rd_data), .rsp_rd_data(ad_rd_data),
        .peak_freq_idx(fft_peak_freq_idx), .peak_mag(), .peak_exp(),
        .ref_mag(), .rsp_mag(), .h_mag_q16(h_mag_q16),
        .ref_phase_deg_q8(), .rsp_phase_deg_q8(), .h_phase_deg_q8(h_phase_deg_q8)
    );

    sweep_result_store u_sweep_result_store(
        .clk(sys_clk), .rst_n(sys_rst_n), .clear(store_clear),
        .write_en(store_result_en), .freq_word(f_word),
        .peak_bin(fft_peak_freq_idx), .h_mag_q16(h_mag_q16),
        .h_phase_deg_q8(h_phase_deg_q8), .read_index(cls_read_index),
        .read_freq_word(), .read_peak_bin(), .read_h_mag_q16(cls_read_h_mag_q16),
        .read_h_phase_deg_q8(), .read_valid(cls_read_valid),
        .result_count(sweep_result_count)
    );

    filter_classifier u_filter_classifier(
        .clk(sys_clk), .rst_n(sys_rst_n), .start(classify_start),
        .result_count(sweep_result_count), .read_index(cls_read_index),
        .read_h_mag_q16(cls_read_h_mag_q16), .read_valid(cls_read_valid),
        .done(classifier_done), .filter_type(filter_type)
    );

    rls_estimator u_rls_estimator(
        .clk(sys_clk), .rst_n(sys_rst_n), .model_clear(store_clear),
        .rls_start_en(rls_start_en), .frame_last(frame_last_for_rls),
        .h_mag_q16(h_mag_q16), .h_phase_deg_q8(h_phase_deg_q8),
        .rls_busy(rls_busy), .rls_done(rls_done),
        .coeff_b0(coeff_b0), .coeff_b1(coeff_b1), .coeff_b2(coeff_b2),
        .coeff_a1(coeff_a1), .coeff_a2(coeff_a2), .avg_sq_err(rls_avg_sq_err)
    );

    biquad_emulator u_biquad_emulator(
        .clk(sys_clk), .rst_n(sys_rst_n), .coeff_valid(model_valid),
        .x_in(dds_wave), .coeff_b0(coeff_b0), .coeff_b1(coeff_b1),
        .coeff_b2(coeff_b2), .coeff_a1(coeff_a1), .coeff_a2(coeff_a2),
        .y_out(biquad_wave)
    );

    da_wave_send u_da_wave_send(
        .clk(sys_clk), .rd_data(da_src_data), .da_clk(da_clk), .da_data(da_data)
    );

    // ══════════════════════════════════════════════════
    //  OLED 显示子系统
    // ══════════════════════════════════════════════════
    fb_ram u_fb_ram (
        .clk(sys_clk),
        .wr_addr(fb_wr_addr), .wr_data(fb_wr_data), .wren(fb_wren),
        .rd_addr(fb_rd_addr), .rd_data(fb_rd_data)
    );

    i2c_master u_i2c (
        .clk(sys_clk), .rst_n(sys_rst_n),
        .tx_start(i2c_tx_start), .tx_dev_addr(i2c_tx_dev),
        .tx_byte(i2c_tx_byte), .tx_valid(i2c_tx_valid),
        .tx_ready(i2c_tx_ready), .tx_last(i2c_tx_last),
        .busy(i2c_bsy), .done(i2c_done),
        .scl(oled_scl), .sda(oled_sda)
    );

    font_8x16 u_font (
        .char_code(font_char), .row(font_row), .pixel_data(font_pixel)
    );

    ssd1306_cmd u_ssd1306 (
        .clk(sys_clk), .rst_n(sys_rst_n),
        .fb_addr(fb_rd_addr), .fb_data(fb_rd_data),
        .refresh_req(oled_refresh_req), .busy(ssd1306_bsy),
        .init_done(ssd1306_init_done),
        .i2c_tx_start(i2c_tx_start), .i2c_tx_dev(i2c_tx_dev),
        .i2c_tx_byte(i2c_tx_byte), .i2c_tx_valid(i2c_tx_valid),
        .i2c_tx_last(i2c_tx_last), .i2c_tx_ready(i2c_tx_ready),
        .i2c_bsy(i2c_bsy), .i2c_done(i2c_done)
    );

    oled_display u_oled_disp (
        .clk(sys_clk), .rst_n(sys_rst_n),
        .filter_type(filter_type), .model_valid(model_valid),
        .fb_wr_addr(fb_wr_addr), .fb_wr_data(fb_wr_data), .fb_wren(fb_wren),
        .refresh_req(oled_refresh_req),
        .ssd1306_busy(ssd1306_bsy), .ssd1306_init_done(ssd1306_init_done),
        .font_char(font_char), .font_row(font_row), .font_pixel(font_pixel)
    );

endmodule
