module fft_processor(
    input  wire        clk,
    input  wire        rst_n,
    
    // 触发与状态接口
    input  wire        fft_start_en,   // 由 acq_ctrl 产生的单次启动脉冲
    output reg         fft_busy,
    output reg         fft_done,       // 分析完成脉冲
    
    // ADC RAM 读取接口
    output wire [9:0]  ad_rd_addr,
    input  wire [7:0]  ad_rd_data,

    // 峰值频率与幅度输出 (用于频谱分析结果)
    output reg  [9:0]  peak_freq_idx,
    output reg  [31:0] peak_mag,
    output reg  [5:0]  peak_exp          // 块浮点指数 (用于还原真实幅度)
);

//==================================================
// FFT IP 接口
//==================================================
reg         sink_valid;
wire        sink_ready;
reg         sink_sop;
reg         sink_eop;
reg  [7:0]  sink_real;
wire [7:0]  sink_imag = 8'd0;    // 虚部恒接0
wire [0:0]  inverse   = 1'b0;    // 0代表正向FFT

wire        source_valid;
reg         source_ready;
wire        source_sop;
wire        source_eop;
wire [7:0]  source_real;
wire [7:0]  source_imag;
wire [5:0]  source_exp;

FFT u_fft (
    .clk          (clk),          
    .reset_n      (rst_n),        
    // 输入接口 (Sink)
    .sink_valid   (sink_valid),   
    .sink_ready   (sink_ready),   
    .sink_error   (2'b00),        
    .sink_sop     (sink_sop),     
    .sink_eop     (sink_eop),     
    .sink_real    (sink_real),    
    .sink_imag    (sink_imag),    
    .inverse      (inverse),      
    // 输出接口 (Source)
    .source_valid (source_valid), 
    .source_ready (source_ready), 
    .source_error (), 
    .source_sop   (source_sop),   
    .source_eop   (source_eop),   
    .source_real  (source_real),  
    .source_imag  (source_imag),  
    .source_exp   (source_exp)    
);

//==================================================
// Sink 控制：将 ADC RAM 数据送入 FFT
//==================================================
reg [2:0]  sink_state;
reg [10:0] addr_cnt;    // 请求地址计数器

// 给 RAM 两个周期的读取延迟对齐
reg [1:0] valid_shift;
reg [1:0] sop_shift;
reg [1:0] eop_shift;

assign ad_rd_addr = addr_cnt[9:0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sink_state  <= 3'd0;
        addr_cnt    <= 11'd0;
        fft_busy    <= 1'b0;
        valid_shift <= 2'b0;
        sop_shift   <= 2'b0;
        eop_shift   <= 2'b0;
        sink_valid  <= 1'b0;
        sink_sop    <= 1'b0;
        sink_eop    <= 1'b0;
    end else begin
        // 对齐 RAM 读延迟（假设 2 拍返回数据）
        sink_valid <= valid_shift[1];
        sink_sop   <= sop_shift[1];
        sink_eop   <= eop_shift[1];
        
        valid_shift[1] <= valid_shift[0];
        sop_shift[1]   <= sop_shift[0];
        eop_shift[1]   <= eop_shift[0];
        
        // ADC 是无符号(0~255)，转成二补码带符号定点数减去128去除直流分量
        sink_real  <= ad_rd_data - 8'd128;

        case (sink_state)
            3'd0: begin
                // 空闲状态，等待启动信号
                addr_cnt <= 11'd0;
                valid_shift[0] <= 1'b0;
                if (fft_start_en) begin
                    fft_busy   <= 1'b1;
                    sink_state <= 3'd1;
                end else begin
                    fft_busy   <= 1'b0;
                end
            end
            3'd1: begin
                // 发送数据过程，当 FFT 的 ready 信号高电平才发数据
                if (sink_ready) begin
                    valid_shift[0] <= 1'b1;
                    sop_shift[0]   <= (addr_cnt == 11'd0) ? 1'b1 : 1'b0;
                    eop_shift[0]   <= (addr_cnt == 11'd1023) ? 1'b1 : 1'b0;
                    
                    addr_cnt <= addr_cnt + 11'd1;
                    
                    if (addr_cnt == 11'd1023) begin
                        sink_state <= 3'd2; // 读完1024个点，等待清空流水线
                    end
                end else begin
                    valid_shift[0] <= 1'b0;
                    sop_shift[0]   <= 1'b0;
                    eop_shift[0]   <= 1'b0;
                end
            end
            3'd2: begin
                // 等待最后几个数据点被 FFT 接收完毕，清空流水线
                valid_shift[0] <= 1'b0;
                sop_shift[0]   <= 1'b0;
                eop_shift[0]   <= 1'b0;
                // FFT 完成后回到空闲
                if (fft_done) begin
                    sink_state <= 3'd0;
                end
            end
        endcase
    end
end

//==================================================
// Source 控制：接收 FFT 结果并计算峰值
//==================================================
reg [10:0] recv_cnt;
wire signed [7:0] s_real = source_real;
wire signed [7:0] s_imag = source_imag;

// 乘法器暂存 (8位 x 8位 = 16位)
reg [15:0] mult_real_sq;
reg [15:0] mult_imag_sq;
reg [16:0] add_sq_sum;
reg [9:0]  curr_freq;
reg        calc_valid_1;
reg        calc_valid_2;
reg [5:0]  latched_exp; // 锁存该帧的指数
reg        source_eop_d1;
reg        source_eop_d2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        source_ready <= 1'b1; // 始终准备好接收
        recv_cnt     <= 11'd0;
        curr_freq    <= 10'd0;
        peak_mag     <= 32'd0;
        peak_freq_idx<= 10'd0;
        peak_exp     <= 6'd0;
        latched_exp  <= 6'd0;
        source_eop_d1 <= 1'b0;
        source_eop_d2 <= 1'b0;
        calc_valid_1 <= 1'b0;
        calc_valid_2 <= 1'b0;
        fft_done     <= 1'b0;
    end else begin
        source_eop_d1 <= source_valid && source_eop;
        source_eop_d2 <= source_eop_d1;
        fft_done      <= calc_valid_2 && source_eop_d2;
        
        // 步骤 A: 拉取数据
        if (source_valid && source_ready) begin
            if (source_sop) begin
                recv_cnt <= 11'd0;
                latched_exp <= source_exp; // 锁存当前FFT帧的缩放指数
            end
            
            // 只看前半部分频谱 (0~511)，奈奎斯特频率以内的实数信号频谱是对称的
            // 为了过滤掉第0点的直流分量(由于减去128可能不彻底或泄漏)，我们从第1点开始统计
            if (recv_cnt > 0 && recv_cnt < 512) begin
                mult_real_sq <= s_real * s_real;
                mult_imag_sq <= s_imag * s_imag;
                curr_freq    <= recv_cnt[9:0];
                calc_valid_1 <= 1'b1;
            end else begin
                calc_valid_1 <= 1'b0;
            end
            
            recv_cnt <= recv_cnt + 11'd1;
        end else begin
            calc_valid_1 <= 1'b0;
        end
        
        // 步骤 B: 乘法累加 (得到模的平方)
        if (calc_valid_1) begin
            add_sq_sum   <= mult_real_sq + mult_imag_sq;
            calc_valid_2 <= 1'b1;
        end else begin
            calc_valid_2 <= 1'b0;
        end
        
        // 步骤 C: 找最大值 (省去开根号直接比较平方大小即可)
        if (source_sop && source_valid) begin
            // 每次出现SOP时，清除上一轮的峰值记录，准备本轮计算
            peak_mag <= 0;
            peak_freq_idx <= 0;
        end else if (calc_valid_2) begin
            if (add_sq_sum > peak_mag) begin
                peak_mag      <= add_sq_sum;  // 保存内部表示的平方和
                peak_freq_idx <= curr_freq;   // 保存峰值位置
                peak_exp      <= latched_exp; // 更新锁存的指数输出
            end
        end
        
        // 步骤 D: 接收完毕标志
    end
end

endmodule