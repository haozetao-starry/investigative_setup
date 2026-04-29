module dds_amp(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  wave_in,
    input  wire [8:0]  a_word,
    output reg  [7:0]  wave_out
);

    wire signed [8:0]  wave_signed = {1'b0, wave_in} - 9'sd128;
    wire signed [18:0] mult_result = wave_signed * $signed({1'b0, a_word});
    wire signed [9:0]  scaled_wave = $signed(mult_result[16:8]) + 10'sd128;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            wave_out <= 8'd128;
        else if(scaled_wave < 0)
            wave_out <= 8'd0;
        else if(scaled_wave > 10'sd255)
            wave_out <= 8'd255;
        else
            wave_out <= scaled_wave[7:0];
    end

endmodule
