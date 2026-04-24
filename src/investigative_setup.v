module investigative_setup(
    input                 sys_clk,
    input                 sys_rst_n,
    output                da_clk,
    output      [7:0]     da_data,
    input       [7:0]     ad_data,
    input                 ad_otr,
    output                ad_clk
);

wire [7:0]  rd_addr;
wire [7:0]  rd_data;
wire [7:0]  ad_rd_addr;
wire [7:0]  ad_rd_data;
wire        ad_buf_full;
wire [31:0] f_word;
wire        sweep_phase_clr;
wire        sweep_step_sync;
wire        sweep_busy;
wire        sweep_done;
wire [8:0]  a_word = 9'd256;
wire [7:0]  dds_wave;

dds_sweep_ctrl #(
    .CLK_FREQ_HZ           (50000000),
    .START_FREQ_HZ         (100),
    .STOP_FREQ_HZ          (10000),
    .STEP_FREQ_HZ          (100),
    .STEP_PERIOD_CLKS      (500000),
    .REPEAT_SWEEP          (1),
    .RESET_PHASE_EACH_STEP (1)
) u_dds_sweep_ctrl (
    .clk         (sys_clk),
    .rst_n       (sys_rst_n),
    .sweep_en    (1'b1),
    .restart     (1'b0),
    .f_word      (f_word),
    .phase_clr   (sweep_phase_clr),
    .step_sync   (sweep_step_sync),
    .sweep_busy  (sweep_busy),
    .sweep_done  (sweep_done)
);

dds_top u_dds_top(
    .clk         (sys_clk),
    .rst_n       (sys_rst_n),
    .phase_clr   (sweep_phase_clr),
    .f_word      (f_word),
    .a_word      (a_word),
    .wave_out    (dds_wave)
);

assign rd_data = dds_wave;

da_wave_send u_da_wave_send(
    .clk         (sys_clk),
    .rst_n       (sys_rst_n),
    .rd_data     (rd_data),
    .rd_addr     (rd_addr),
    .da_clk      (da_clk),
    .da_data     (da_data)
);

ad_wave_rec u_ad_wave_rec(
    .clk         (sys_clk),
    .rst_n       (sys_rst_n),
    .ad_data     (ad_data),
    .ad_otr      (ad_otr),
    .ad_clk      (ad_clk),
    .rd_addr     (ad_rd_addr),
    .rd_data     (ad_rd_data),
    .buf_full    (ad_buf_full)
);

assign ad_rd_addr = 8'd0;

endmodule