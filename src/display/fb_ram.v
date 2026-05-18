// Simple dual-port framebuffer RAM for OLED display
// 1024 × 8-bit, write port + read port, inferred BRAM

module fb_ram (
    input  wire        clk,
    // Write port
    input  wire [9:0]  wr_addr,
    input  wire [7:0]  wr_data,
    input  wire        wren,
    // Read port (combinational or registered)
    input  wire [9:0]  rd_addr,
    output reg  [7:0]  rd_data
);

    reg [7:0] mem [0:1023];

    // Write
    always @(posedge clk) begin
        if (wren) mem[wr_addr] <= wr_data;
    end

    // Read (registered, 1-cycle latency)
    always @(posedge clk) begin
        rd_data <= mem[rd_addr];
    end

endmodule
