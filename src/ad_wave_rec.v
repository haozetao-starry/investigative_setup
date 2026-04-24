//这是一个AD采集模块，主要功能是产生AD时钟，驱动AD芯片进行数据采集。AD芯片的型号为AD9280，支持最大32Mhz的时钟频率。
//AD采集的数据通过ad_rd_data输出，当前版本中固定读取第一个采集值，后续可以根据需要添加读控制逻辑来读取更多的采集数据。
//----------------------------------------------------------------------------------------
//****************************************************************************************//    
module ad_wave_rec(
    //输入
    input                 clk         ,  //系统时钟
    input                 rst_n       ,  //复位信号，低电平有效  
    input         [7:0]   ad_data     ,  //AD输入数据  
    //模拟输入电压超出量程标志
    input                 ad_otr      ,  //0:在量程范围 1:超出量程
    input         [7:0]   rd_addr     ,  //读取采集缓存地址

    //输出
    output   reg          ad_clk      ,  //AD(AD9280)驱动时钟,最大支持32Mhz时钟
    output  reg [7:0]     rd_data     ,  //从采集缓存读取的数据
    output  reg           buf_full      //采集缓存已满标志
    );

//*****************************************************
//**                    main code 
//*****************************************************

reg [7:0] wr_addr;
reg [7:0] ad_buf [0:255];

//时钟分频(2分频,时钟频率为25Mhz),产生AD时钟
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        ad_clk   <= 1'b0;
        wr_addr  <= 8'd0;
        buf_full <= 1'b0;
    end else begin
        // 当 ad_clk 由低变高时，采集一组 AD 数据
        if((ad_clk == 1'b0) && (buf_full == 1'b0)) begin
            ad_buf[wr_addr] <= ad_data;
            wr_addr <= wr_addr + 8'd1;
            if(wr_addr == 8'hFF)
                buf_full <= 1'b1;
        end
        ad_clk <= ~ad_clk;
    end
end

// 读取采集缓存数据，供后续 FFT 或处理使用
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        rd_data <= 8'd0;
    else
        rd_data <= ad_buf[rd_addr];
end

endmodule