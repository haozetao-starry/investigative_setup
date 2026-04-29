module investigative_setup(
    input                 sys_clk,
    input                 sys_rst_n,
    output                da_clk,
    output      [7:0]     da_data,
    input       [7:0]     ad_data,
    input                 ad_otr,
    output                ad_clk
);

//==================================================
// 内部信号定义
//==================================================
// DDS与DAC相关信号
wire [31:0] f_word;
wire [8:0]  a_word = 9'd256;
wire [7:0]  dds_wave;
wire        sweep_phase_clr;
wire        sweep_step_sync;
wire        sweep_busy;
wire        sweep_done;

// ADC 缓存与控制相关信号
wire [9:0]  ad_rd_addr;    // 1024深度需要10位地址
wire [7:0]  ad_rd_data;
wire        ad_buf_full;
wire        ad_otr_flag;
wire        ad_acq_start;  // ADC采集启动触发 (由 acq_ctrl 驱动)
wire [15:0] ad_smp_div;    // ADC动态降采样率分频系数 (由 acq_ctrl 驱动)
wire        fft_start_en;  // 给FFT预留的触发信号 (由 acq_ctrl 驱动)

//==================================================
// 1. DDS 扫频控制与波形产生
//==================================================
dds_sweep_ctrl #(
    .CLK_FREQ_HZ           (50000000),
    .START_FREQ_HZ         (100),
    .STOP_FREQ_HZ          (10000),
    .STEP_FREQ_HZ          (100),
    .STEP_PERIOD_CLKS      (2500000), // 为了兼顾低频采样(需要更长的时间)，加大单个步进的停留时间(50ms)
    .REPEAT_SWEEP          (1),
    .RESET_PHASE_EACH_STEP (1)
) u_dds_sweep_ctrl (
    .clk         (sys_clk),
    .rst_n       (sys_rst_n),
    .sweep_en    (1'b1),
    .restart     (1'b0),
    .f_word      (f_word),
    .phase_clr   (sweep_phase_clr),
    .step_sync   (sweep_step_sync), // 频率切换同步脉冲
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

// 将DDS波形直通DAC发送模块
da_wave_send u_da_wave_send(
    .clk         (sys_clk),
    .rst_n       (sys_rst_n),
    .rd_data     (dds_wave),
    .da_clk      (da_clk),
    .da_data     (da_data)
);

//==================================================
// 2. ADC 采集触发与全局状态控制 (独立模块)
//==================================================
acq_ctrl u_acq_ctrl(
    .clk              (sys_clk        ),
    .rst_n            (sys_rst_n      ),
    
    // 与 DDS 交互
    .f_word           (f_word         ),
    .sweep_step_sync  (sweep_step_sync),
    
    // 与 ADC 交互
    .ad_buf_full      (ad_buf_full    ),
    .ad_acq_start     (ad_acq_start   ),
    .ad_smp_div       (ad_smp_div     ),
    
    // 为以后预留
    .fft_start_en     (fft_start_en   )
);

//==================================================
// 3. ADC 波形接收与缓存 
//==================================================
ad_wave_rec u_ad_wave_rec(
    .clk         (sys_clk),
    .rst_n       (sys_rst_n),
    .ad_data     (ad_data),
    .ad_otr      (ad_otr),
    
    .acq_start   (ad_acq_start), // 连接触发模块发来的启动脉冲
    .smp_div     (ad_smp_div),   // 连接动态计算的分频系数
    .rd_addr     (ad_rd_addr),
    .rd_en       (1'b1),         // 为以后FFT模块准备的读使能，暂时常开
    
    .ad_clk      (ad_clk),
    .rd_data     (ad_rd_data),
    .buf_full    (ad_buf_full),
    .otr_flag    (ad_otr_flag)
);

// 暂时接零，待加入FFT时，ad_rd_addr 由FFT读取逻辑控制
assign ad_rd_addr = 10'd0;

endmodule