//这是一个AD采集模块，主要功能是产生AD时钟，驱动AD芯片进行数据采集。AD芯片的型号为AD9280，支持最大32Mhz的时钟频率。
//AD采集的数据通过ad_rd_data输出，当前版本中固定读取第一个采集值，后续可以根据需要添加读控制逻辑来读取更多的采集数据。
//----------------------------------------------------------------------------------------
//****************************************************************************************//    
module ad_wave_rec(
    //输入
    input                 clk         ,  //系统时钟 (假设为50MHz)
    input                 rst_n       ,  //复位信号，低电平有效  
    input         [7:0]   ad_data     ,  //AD输入数据  
    input                 ad_otr      ,  //0:在量程范围 1:超出量程
    
    input                 acq_start   ,  //新增：启动单次采集触发信号 (高脉冲有效)
    input         [15:0]  smp_div     ,  //新增：动态采样率分频系数 (由顶层扫频模块根据波形频率下发)
    input         [9:0]   rd_addr     ,  //读取采集缓存地址 (1024深度需10位地址)
    input                 rd_en       ,  //读使能

    //输出
    output  wire          ad_clk      ,  //AD(AD9280)驱动时钟(25MHz)
    output  wire [7:0]    rd_data     ,  //从采集缓存读取的数据，直接由RAM输出
    output  reg           buf_full    ,  //采集缓存已满标志
    output  reg           otr_flag       //新增：量程超限标志 (1表示当前缓存结果曾存在超波幅)
    );

//*****************************************************
//**                    main code 
//*****************************************************

reg [9:0] wr_addr;              // 10位写地址
reg       ram_wren;             // 写使能信号
reg [7:0] ad_data_reg;          // AD数据寄存器（用于切断跨钟域组合逻辑）
reg       ad_clk_reg;           // 内部时钟翻转寄存器
reg       acq_en;               // 采集进行中的使能状态
reg [15:0] smp_cnt;             // 新增：动态分档采样计数器

// 1. 产生连续的ADC物理驱动时钟 (建议该引脚通过ODDR输出，此处直接连线)
assign ad_clk = ad_clk_reg;

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        ad_clk_reg <= 1'b0;
    end else begin
        ad_clk_reg <= ~ad_clk_reg;
    end
end

// 2. 采集控制逻辑与数据采样
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        wr_addr     <= 10'd0;
        buf_full    <= 1'b0;
        ram_wren    <= 1'b0;
        acq_en      <= 1'b0;
        ad_data_reg <= 8'd0;
        otr_flag    <= 1'b0;
        smp_cnt     <= 16'd0;    // 初始化分频计数器
    end else begin
        // 处理多次采集的复位响应：收到新的一轮触发指令，重置内部指针
        if(acq_start) begin
            wr_addr  <= 10'd0;
            buf_full <= 1'b0;
            acq_en   <= 1'b1;
            otr_flag <= 1'b0;
            smp_cnt  <= 16'd0; // 同样重置抽样基准
        end
        
        // 安全采样时机：
        // AD9280在 ad_clk_reg 从0变1后输出新数据，经过十多个ns后数据绝对稳定。
        // 当 ad_clk_reg 此时等于 1，说明已经保持高电平了近20ns (假设50M系统钟)。
        // 这一刻采样，完美规避亚稳态和电平跳变沿。
        if(ad_clk_reg == 1'b1) begin
            // A. 将总线数据和OTR打入一级前向寄存器锁存，提升系统最大运行频率(Fmax)
            ad_data_reg <= ad_data;
            if(ad_otr) otr_flag <= 1'b1; // 当次采集中任一点超限，则拉高保持

            // B. 动态分档(抽空)存入RAM逻辑
            if(acq_en && !buf_full) begin
                if(smp_cnt >= smp_div) begin
                    // 计数到了分档阈值，此时抽取并写入1个点
                    smp_cnt  <= 16'd0; 
                    ram_wren <= 1'b1;
                    wr_addr  <= wr_addr + 10'd1;
                    // 写满1024个数后标志完成，关闭写入保护数据
                    if(wr_addr == 10'd1023) begin
                        acq_en   <= 1'b0;
                        buf_full <= 1'b1;
                    end
                end else begin
                    // 没到分频阈值时，数据不写入RAM，等效于降采样
                    smp_cnt  <= smp_cnt + 16'd1;
                    ram_wren <= 1'b0;
                end
            end else begin
                ram_wren <= 1'b0;
            end
        end else begin
            // ad_clk_reg 为低时，强制拉低写使能
            // 保证每获取一个有效点只发生1个周期(system_clk)的写入操作
            ram_wren <= 1'b0;
        end
    end
end

// 3. 例化刚才生成的1024深度双口RAM IP
ADC_RAM u_ADC_RAM(
    .data       (ad_data_reg),  // 写入同步锁存后绝对稳定的AD数据
    .rdaddress  (rd_addr    ),  // [9:0] 后续FFT处理模块给出的读地址
    .rdclock    (clk        ),  // 统一的系统主频时钟
    .rden       (rd_en      ),  
    .wraddress  (wr_addr    ),  
    .wrclock    (clk        ),  // 虽然AD时钟是25Mz，但是我们控制写使能频率来变相降频
    .wren       (ram_wren   ),  
    .q          (rd_data    )   
);

endmodule