module rls_estimator #(
    parameter [31:0] ONE_Q16 = 32'd65536
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               model_clear,
    input  wire               rls_start_en,
    input  wire               frame_last,
    input  wire [31:0]        h_mag_q16,
    input  wire signed [15:0] h_phase_deg_q8,
    output reg                rls_busy,
    output reg                rls_done,
    output reg signed [31:0]  coeff_b0,
    output reg signed [31:0]  coeff_b1,
    output reg signed [31:0]  coeff_b2,
    output reg signed [31:0]  coeff_a1,
    output reg signed [31:0]  coeff_a2,
    output reg [31:0]         avg_sq_err
);

    reg [63:0]        sum_gain_q16;
    reg signed [31:0] sum_phase_q8;
    reg [63:0]        sum_gain_sq_q32;
    reg [7:0]         frame_count;
    reg [31:0]        avg_gain_q16;
    reg signed [15:0] avg_phase_q8;
    reg [63:0]        mean_sq_q32;
    reg [63:0]        avg_gain_sq_q32;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sum_gain_q16    <= 64'd0;
            sum_phase_q8    <= 32'sd0;
            sum_gain_sq_q32 <= 64'd0;
            frame_count     <= 8'd0;
            avg_gain_q16    <= ONE_Q16;
            avg_phase_q8    <= 16'sd0;
            mean_sq_q32     <= 64'd0;
            avg_gain_sq_q32 <= 64'd0;
            coeff_b0        <= $signed(ONE_Q16);
            coeff_b1        <= 32'sd0;
            coeff_b2        <= 32'sd0;
            coeff_a1        <= 32'sd0;
            coeff_a2        <= 32'sd0;
            avg_sq_err      <= 32'd0;
            rls_busy        <= 1'b0;
            rls_done        <= 1'b0;
        end else begin
            rls_done <= 1'b0;

            if(model_clear) begin
                sum_gain_q16    <= 64'd0;
                sum_phase_q8    <= 32'sd0;
                sum_gain_sq_q32 <= 64'd0;
                frame_count     <= 8'd0;
                avg_gain_q16    <= ONE_Q16;
                avg_phase_q8    <= 16'sd0;
                mean_sq_q32     <= 64'd0;
                avg_gain_sq_q32 <= 64'd0;
                coeff_b0        <= $signed(ONE_Q16);
                coeff_b1        <= 32'sd0;
                coeff_b2        <= 32'sd0;
                coeff_a1        <= 32'sd0;
                coeff_a2        <= 32'sd0;
                avg_sq_err      <= 32'd0;
                rls_busy        <= 1'b0;
            end else if(rls_start_en) begin
                rls_busy        <= 1'b1;
                sum_gain_q16    <= sum_gain_q16 + h_mag_q16;
                sum_phase_q8    <= sum_phase_q8 + $signed({{16{h_phase_deg_q8[15]}}, h_phase_deg_q8});
                sum_gain_sq_q32 <= sum_gain_sq_q32 + (h_mag_q16 * h_mag_q16);
                frame_count     <= frame_count + 8'd1;

                if(frame_last) begin
                    if(frame_count == 0) begin
                        avg_gain_q16 <= h_mag_q16;
                        avg_phase_q8 <= h_phase_deg_q8;
                        avg_sq_err   <= 32'd0;
                        coeff_b0     <= $signed(h_mag_q16);
                    end else begin
                        avg_gain_q16 <= (sum_gain_q16 + h_mag_q16) / (frame_count + 8'd1);
                        avg_phase_q8 <= (sum_phase_q8 + $signed({{16{h_phase_deg_q8[15]}}, h_phase_deg_q8})) / $signed({24'd0, (frame_count + 8'd1)});
                        avg_gain_sq_q32 <= (sum_gain_sq_q32 + (h_mag_q16 * h_mag_q16)) / (frame_count + 8'd1);
                        mean_sq_q32     <= (((sum_gain_q16 + h_mag_q16) / (frame_count + 8'd1)) * ((sum_gain_q16 + h_mag_q16) / (frame_count + 8'd1)));
                        if((((sum_gain_sq_q32 + (h_mag_q16 * h_mag_q16)) / (frame_count + 8'd1))) >
                           ((((sum_gain_q16 + h_mag_q16) / (frame_count + 8'd1)) * ((sum_gain_q16 + h_mag_q16) / (frame_count + 8'd1))))) begin
                            avg_sq_err <= (((sum_gain_sq_q32 + (h_mag_q16 * h_mag_q16)) / (frame_count + 8'd1))) -
                                          ((((sum_gain_q16 + h_mag_q16) / (frame_count + 8'd1)) * ((sum_gain_q16 + h_mag_q16) / (frame_count + 8'd1))));
                        end else begin
                            avg_sq_err <= 32'd0;
                        end
                        coeff_b0 <= $signed((sum_gain_q16 + h_mag_q16) / (frame_count + 8'd1));
                    end

                    coeff_b1 <= 32'sd0;
                    coeff_b2 <= 32'sd0;
                    coeff_a1 <= 32'sd0;
                    coeff_a2 <= 32'sd0;
                    rls_busy  <= 1'b0;
                end

                rls_done <= 1'b1;
            end
        end
    end

endmodule
