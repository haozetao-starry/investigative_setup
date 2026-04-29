module acq_ctrl(
    input  wire        clk,
    input  wire        rst_n,
    
    // 与DDS扫频模块交互
    input  wire [31:0] f_word,
    input  wire        sweep_step_sync,
    
    // 与ADC采集模块交互
    input  wire        ad_buf_full,
    output reg         ad_acq_start,
    output reg  [15:0] ad_smp_div,
    
    // 预留给后续FFT模块的启动触发信号
    output reg         fft_start_en
);

//==================================================
// 1. 动态计算ADC降采样分频系数
//==================================================
// 根据当前 DDS 输出的频率字 f_word，动态评估频率段，控制ADC分频采样
// F_out = (f_word * 50MHz) / 2^32 
// 100kHz = 8,589,934
// 10kHz  = 858,993
// 1kHz   = 85,899
always @(*) begin
    if (f_word >= 32'd8589934) begin
        // >100kHz: 不分频 (有效采样率 25MHz)
        ad_smp_div = 16'd0;
    end else if (f_word >= 32'd858993) begin
        // 10kHz~100kHz: 10分频 (有效采样率 2.5MHz)
        ad_smp_div = 16'd9;
    end else if (f_word >= 32'd85899) begin
        // 1kHz~10kHz: 100分频 (有效采样率 250kHz)
        ad_smp_div = 16'd99;
    end else begin
        // <1kHz: 1000分频 (有效采样率 25kHz)
        ad_smp_div = 16'd999;
    end
end

//==================================================
// 2. 全局协调采样状态机
//==================================================
reg [1:0] acq_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        acq_state    <= 2'd0;
        ad_acq_start <= 1'b0;
        fft_start_en <= 1'b0;
    end else begin
        case (acq_state)
            2'd0: begin
                ad_acq_start <= 1'b0;
                fft_start_en <= 1'b0;
                // 当频率发生跃变时，DDS扫频模块会发出 step_sync 脉冲
                if (sweep_step_sync) begin
                    acq_state <= 2'd1;
                end
            end
            2'd1: begin
                // 发出采样启动触发给ADC缓存模块（高脉冲1个周期），清空RAM指针
                ad_acq_start <= 1'b1;
                acq_state    <= 2'd2;
            end
            2'd2: begin
                ad_acq_start <= 1'b0;
                // 等待ADC由于频率低慢速采样直到1024全部填满缓冲
                if (ad_buf_full) begin
                    fft_start_en <= 1'b1; // 触发 FFT 执行模块 !!
                    acq_state    <= 2'd3;
                end
            end
            2'd3: begin
                // 脉冲恢复
                fft_start_en <= 1'b0; 
                // 等待 FFT 执行完毕等后续操作，目前暂且复位等待下一次扫频触发
                // (后续可以加入等待FFT done信号再返回0状态的逻辑)
                acq_state <= 2'd0;
            end
            default: acq_state <= 2'd0;
        endcase
    end
end

endmodule