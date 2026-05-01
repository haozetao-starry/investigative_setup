module fft_processor(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              fft_start_en,
    output reg               fft_busy,
    output reg               fft_done,
    output wire [9:0]        rd_addr,
    input  wire [7:0]        ref_rd_data,
    input  wire [7:0]        rsp_rd_data,
    output reg  [9:0]        peak_freq_idx,
    output reg  [31:0]       peak_mag,
    output reg  [5:0]        peak_exp,
    output reg  [31:0]       ref_mag,
    output reg  [31:0]       rsp_mag,
    output reg  [31:0]       h_mag_q16,
    output reg  signed [15:0] ref_phase_deg_q8,
    output reg  signed [15:0] rsp_phase_deg_q8,
    output reg  signed [15:0] h_phase_deg_q8
);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_RUN  = 2'd1;

    reg [1:0] state;
    reg       frame_sel;
    reg [10:0] req_addr;
    reg [10:0] out_bin;
    reg        input_done;

    reg        sink_valid;
    wire       sink_ready;
    reg        sink_sop;
    reg        sink_eop;
    reg [7:0]  sink_real;
    wire [7:0] sink_imag = 8'd0;
    wire [0:0] inverse   = 1'b0;

    wire       source_valid;
    wire       source_sop;
    wire       source_eop;
    reg        source_ready;
    wire [7:0] source_real;
    wire [7:0] source_imag;
    wire [5:0] source_exp;

    reg [1:0] valid_pipe;
    reg [1:0] sop_pipe;
    reg [1:0] eop_pipe;

    reg [31:0] ref_mag_raw;
    reg [5:0]  ref_exp_raw;
    reg signed [7:0] ref_real_raw;
    reg signed [7:0] ref_imag_raw;

    reg [31:0] rsp_mag_raw;
    reg [5:0]  rsp_exp_raw;
    reg signed [7:0] rsp_real_raw;
    reg signed [7:0] rsp_imag_raw;

    assign rd_addr = req_addr[9:0];

    FFT u_fft (
        .clk          (clk),
        .reset_n      (rst_n),
        .sink_valid   (sink_valid),
        .sink_ready   (sink_ready),
        .sink_error   (2'b00),
        .sink_sop     (sink_sop),
        .sink_eop     (sink_eop),
        .sink_real    (sink_real),
        .sink_imag    (sink_imag),
        .inverse      (inverse),
        .source_valid (source_valid),
        .source_ready (source_ready),
        .source_error (),
        .source_sop   (source_sop),
        .source_eop   (source_eop),
        .source_real  (source_real),
        .source_imag  (source_imag),
        .source_exp   (source_exp)
    );

    function [31:0] mag_sq_from_iq;
        input signed [7:0] i_val;
        input signed [7:0] q_val;
        reg   signed [15:0] i_sq;
        reg   signed [15:0] q_sq;
        begin
            i_sq = i_val * i_val;
            q_sq = q_val * q_val;
            mag_sq_from_iq = i_sq + q_sq;
        end
    endfunction

    function [31:0] apply_exp_to_mag;
        input [31:0] mag_raw_in;
        input [5:0]  exp_in;
        reg   [31:0] mag_shifted;
        reg   [5:0]  shift_amt;
        begin
            shift_amt = exp_in << 1;
            if (shift_amt >= 16)
                mag_shifted = mag_raw_in << 16;
            else
                mag_shifted = mag_raw_in << shift_amt;
            apply_exp_to_mag = mag_shifted;
        end
    endfunction

    function [31:0] mag_ratio_q16_fn;
        input [31:0] num_mag_raw;
        input [5:0]  num_exp_in;
        input [31:0] den_mag_raw;
        input [5:0]  den_exp_in;
        reg   [63:0] num_scaled;
        reg   [63:0] den_scaled;
        integer delta_exp;
        integer shift_amt;
        begin
            if (den_mag_raw == 0) begin
                mag_ratio_q16_fn = 32'd0;
            end else begin
                num_scaled = num_mag_raw;
                den_scaled = den_mag_raw;
                delta_exp  = num_exp_in - den_exp_in;
                if (delta_exp >= 0) begin
                    shift_amt = delta_exp << 1;
                    if (shift_amt < 24)
                        num_scaled = num_scaled << shift_amt;
                end else begin
                    shift_amt = (-delta_exp) << 1;
                    if (shift_amt < 24)
                        den_scaled = den_scaled << shift_amt;
                end
                mag_ratio_q16_fn = (num_scaled << 16) / den_scaled;
            end
        end
    endfunction

    function signed [15:0] atan2_deg_q8_fn;
        input signed [7:0] y_val;
        input signed [7:0] x_val;
        integer abs_x;
        integer abs_y;
        integer base_q8;
        integer ratio_q8;
        integer angle_q8;
        integer pi_q8;
        integer half_pi_q8;
        integer quarter_pi_q8;
        begin
            pi_q8       = 46080;
            half_pi_q8  = 23040;
            quarter_pi_q8 = 11520;
            abs_x = (x_val < 0) ? -x_val : x_val;
            abs_y = (y_val < 0) ? -y_val : y_val;

            if ((abs_x == 0) && (abs_y == 0)) begin
                angle_q8 = 0;
            end else if (abs_x >= abs_y) begin
                ratio_q8 = (abs_y << 8) / ((abs_x == 0) ? 1 : abs_x);
                base_q8  = (ratio_q8 * quarter_pi_q8) >>> 8;
                if (x_val >= 0)
                    angle_q8 = (y_val >= 0) ? base_q8 : -base_q8;
                else
                    angle_q8 = (y_val >= 0) ? (pi_q8 - base_q8) : (base_q8 - pi_q8);
            end else begin
                ratio_q8 = (abs_x << 8) / ((abs_y == 0) ? 1 : abs_y);
                base_q8  = half_pi_q8 - ((ratio_q8 * quarter_pi_q8) >>> 8);
                if (y_val >= 0)
                    angle_q8 = (x_val >= 0) ? base_q8 : (pi_q8 - base_q8);
                else
                    angle_q8 = (x_val >= 0) ? -base_q8 : (base_q8 - pi_q8);
            end

            atan2_deg_q8_fn = angle_q8[15:0];
        end
    endfunction

    function signed [15:0] wrap_phase_q8_fn;
        input signed [16:0] phase_q8_in;
        reg   signed [16:0] wrapped_q8;
        begin
            wrapped_q8 = phase_q8_in;
            if (wrapped_q8 > 17'sd46080)
                wrapped_q8 = wrapped_q8 - 17'sd92160;
            else if (wrapped_q8 < -17'sd46080)
                wrapped_q8 = wrapped_q8 + 17'sd92160;
            wrap_phase_q8_fn = wrapped_q8[15:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state            <= ST_IDLE;
            frame_sel        <= 1'b0;
            req_addr         <= 11'd0;
            out_bin          <= 11'd0;
            input_done       <= 1'b0;
            fft_busy         <= 1'b0;
            fft_done         <= 1'b0;
            sink_valid       <= 1'b0;
            sink_sop         <= 1'b0;
            sink_eop         <= 1'b0;
            sink_real        <= 8'd0;
            source_ready     <= 1'b1;
            valid_pipe       <= 2'b00;
            sop_pipe         <= 2'b00;
            eop_pipe         <= 2'b00;
            peak_freq_idx    <= 10'd0;
            peak_mag         <= 32'd0;
            peak_exp         <= 6'd0;
            ref_mag          <= 32'd0;
            rsp_mag          <= 32'd0;
            h_mag_q16        <= 32'd0;
            ref_phase_deg_q8 <= 16'sd0;
            rsp_phase_deg_q8 <= 16'sd0;
            h_phase_deg_q8   <= 16'sd0;
            ref_mag_raw      <= 32'd0;
            ref_exp_raw      <= 6'd0;
            ref_real_raw     <= 8'sd0;
            ref_imag_raw     <= 8'sd0;
            rsp_mag_raw      <= 32'd0;
            rsp_exp_raw      <= 6'd0;
            rsp_real_raw     <= 8'sd0;
            rsp_imag_raw     <= 8'sd0;
        end else begin
            fft_done    <= 1'b0;
            source_ready<= 1'b1;

            sink_valid <= valid_pipe[1];
            sink_sop   <= sop_pipe[1];
            sink_eop   <= eop_pipe[1];
            sink_real  <= (frame_sel ? rsp_rd_data : ref_rd_data) - 8'd128;

            valid_pipe[1] <= valid_pipe[0];
            sop_pipe[1]   <= sop_pipe[0];
            eop_pipe[1]   <= eop_pipe[0];
            valid_pipe[0] <= 1'b0;
            sop_pipe[0]   <= 1'b0;
            eop_pipe[0]   <= 1'b0;

            case(state)
                ST_IDLE: begin
                    fft_busy  <= 1'b0;
                    req_addr  <= 11'd0;
                    out_bin   <= 11'd0;
                    input_done<= 1'b0;
                    frame_sel <= 1'b0;
                    if(fft_start_en) begin
                        fft_busy         <= 1'b1;
                        peak_freq_idx    <= 10'd0;
                        peak_mag         <= 32'd0;
                        peak_exp         <= 6'd0;
                        ref_mag          <= 32'd0;
                        rsp_mag          <= 32'd0;
                        h_mag_q16        <= 32'd0;
                        ref_phase_deg_q8 <= 16'sd0;
                        rsp_phase_deg_q8 <= 16'sd0;
                        h_phase_deg_q8   <= 16'sd0;
                        ref_mag_raw      <= 32'd0;
                        ref_exp_raw      <= 6'd0;
                        ref_real_raw     <= 8'sd0;
                        ref_imag_raw     <= 8'sd0;
                        rsp_mag_raw      <= 32'd0;
                        rsp_exp_raw      <= 6'd0;
                        rsp_real_raw     <= 8'sd0;
                        rsp_imag_raw     <= 8'sd0;
                        valid_pipe       <= 2'b00;
                        sop_pipe         <= 2'b00;
                        eop_pipe         <= 2'b00;
                        state            <= ST_RUN;
                    end
                end

                ST_RUN: begin
                    if(!input_done && sink_ready) begin
                        valid_pipe[0] <= 1'b1;
                        sop_pipe[0]   <= (req_addr == 11'd0);
                        eop_pipe[0]   <= (req_addr == 11'd1023);
                        if(req_addr == 11'd1023) begin
                            input_done <= 1'b1;
                        end else begin
                            req_addr <= req_addr + 11'd1;
                        end
                    end

                    if(source_valid && source_ready) begin
                        if(source_sop)
                            out_bin <= 11'd0;

                        if(!frame_sel) begin
                            if((out_bin > 0) && (out_bin < 11'd512) && (mag_sq_from_iq(source_real, source_imag) > ref_mag_raw)) begin
                                ref_mag_raw      <= mag_sq_from_iq(source_real, source_imag);
                                ref_exp_raw      <= source_exp;
                                ref_real_raw     <= source_real;
                                ref_imag_raw     <= source_imag;
                                peak_freq_idx    <= out_bin[9:0];
                            end
                        end else begin
                            if((out_bin[9:0] == peak_freq_idx) && (out_bin > 0)) begin
                                rsp_mag_raw      <= mag_sq_from_iq(source_real, source_imag);
                                rsp_exp_raw      <= source_exp;
                                rsp_real_raw     <= source_real;
                                rsp_imag_raw     <= source_imag;
                            end
                        end

                        if(source_eop) begin
                            if(!frame_sel) begin
                                frame_sel  <= 1'b1;
                                req_addr   <= 11'd0;
                                out_bin    <= 11'd0;
                                input_done <= 1'b0;
                                valid_pipe <= 2'b00;
                                sop_pipe   <= 2'b00;
                                eop_pipe   <= 2'b00;
                            end else begin
                                ref_mag          <= apply_exp_to_mag(ref_mag_raw, ref_exp_raw);
                                rsp_mag          <= apply_exp_to_mag(rsp_mag_raw, rsp_exp_raw);
                                ref_phase_deg_q8 <= atan2_deg_q8_fn(ref_imag_raw, ref_real_raw);
                                rsp_phase_deg_q8 <= atan2_deg_q8_fn(rsp_imag_raw, rsp_real_raw);
                                h_mag_q16        <= mag_ratio_q16_fn(rsp_mag_raw, rsp_exp_raw, ref_mag_raw, ref_exp_raw);
                                h_phase_deg_q8   <= wrap_phase_q8_fn($signed(atan2_deg_q8_fn(rsp_imag_raw, rsp_real_raw)) - $signed(atan2_deg_q8_fn(ref_imag_raw, ref_real_raw)));
                                peak_mag         <= apply_exp_to_mag(rsp_mag_raw, rsp_exp_raw);
                                peak_exp         <= rsp_exp_raw;
                                fft_busy         <= 1'b0;
                                fft_done         <= 1'b1;
                                state            <= ST_IDLE;
                            end
                        end else begin
                            out_bin <= out_bin + 11'd1;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
