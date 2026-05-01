module biquad_emulator #(
    parameter integer FRAC_BITS = 16
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              coeff_valid,
    input  wire [7:0]        x_in,
    input  wire signed [31:0] coeff_b0,
    input  wire signed [31:0] coeff_b1,
    input  wire signed [31:0] coeff_b2,
    input  wire signed [31:0] coeff_a1,
    input  wire signed [31:0] coeff_a2,
    output reg  [7:0]        y_out
);

    localparam signed [31:0] ONE_Q = 32'sd65536;

    reg signed [31:0] x0_q;
    reg signed [31:0] x1_q;
    reg signed [31:0] x2_q;
    reg signed [31:0] y1_q;
    reg signed [31:0] y2_q;
    reg signed [31:0] y0_q;
    reg signed [63:0] acc64;
    reg signed [8:0]  centered;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x0_q <= 32'sd0;
            x1_q <= 32'sd0;
            x2_q <= 32'sd0;
            y1_q <= 32'sd0;
            y2_q <= 32'sd0;
            y0_q <= 32'sd0;
            y_out <= 8'd128;
        end else if(!coeff_valid) begin
            x0_q <= 32'sd0;
            x1_q <= 32'sd0;
            x2_q <= 32'sd0;
            y1_q <= 32'sd0;
            y2_q <= 32'sd0;
            y0_q <= 32'sd0;
            y_out <= x_in;
        end else begin
            centered = $signed({1'b0, x_in}) - 9'sd128;
            x0_q     <= $signed(centered) * ONE_Q;

            acc64 = ($signed(coeff_b0) * ($signed(centered) * ONE_Q)) +
                    ($signed(coeff_b1) * $signed(x1_q)) +
                    ($signed(coeff_b2) * $signed(x2_q)) -
                    ($signed(coeff_a1) * $signed(y1_q)) -
                    ($signed(coeff_a2) * $signed(y2_q));

            y0_q <= acc64 >>> FRAC_BITS;

            x2_q <= x1_q;
            x1_q <= $signed(centered) * ONE_Q;
            y2_q <= y1_q;
            y1_q <= acc64 >>> FRAC_BITS;

            if((acc64 >>> FRAC_BITS) > (32'sd127 <<< FRAC_BITS))
                y_out <= 8'd255;
            else if((acc64 >>> FRAC_BITS) < -(32'sd128 <<< FRAC_BITS))
                y_out <= 8'd0;
            else
                y_out <= (((acc64 >>> FRAC_BITS) >>> FRAC_BITS) + 9'sd128);
        end
    end

endmodule
