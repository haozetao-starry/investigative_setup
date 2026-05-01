module acq_ctrl #(
    parameter [31:0] STOP_WORD          = 32'd858993,
    parameter [31:0] RLS_ERR_THRESHOLD  = 32'd26214400
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] f_word,
    input  wire        sweep_step_sync,
    input  wire        ad_buf_full,
    input  wire        fft_done,
    input  wire        rls_done,
    input  wire        classifier_done,
    input  wire [31:0] rls_avg_sq_err,
    output reg         ad_acq_start,
    output reg  [15:0] ad_smp_div,
    output reg         fft_start_en,
    output reg         rls_start_en,
    output reg         store_result_en,
    output reg         classify_start,
    output reg         store_clear,
    output reg         sweep_restart,
    output reg         mimic_mode,
    output reg         model_valid
);

    localparam [2:0] ST_IDLE          = 3'd0;
    localparam [2:0] ST_PULSE_ACQ     = 3'd1;
    localparam [2:0] ST_WAIT_BUF      = 3'd2;
    localparam [2:0] ST_WAIT_FFT      = 3'd3;
    localparam [2:0] ST_WAIT_RLS      = 3'd4;
    localparam [2:0] ST_WAIT_CLASSIFY = 3'd5;

    reg [2:0] state;
    reg       frame_is_last;

    wire [31:0] rls_err_limit = RLS_ERR_THRESHOLD;

    always @(*) begin
        if (f_word >= 32'd8589934)
            ad_smp_div = 16'd0;
        else if (f_word >= 32'd858993)
            ad_smp_div = 16'd9;
        else if (f_word >= 32'd85899)
            ad_smp_div = 16'd99;
        else
            ad_smp_div = 16'd999;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state           <= ST_IDLE;
            frame_is_last   <= 1'b0;
            ad_acq_start    <= 1'b0;
            fft_start_en    <= 1'b0;
            rls_start_en    <= 1'b0;
            store_result_en <= 1'b0;
            classify_start  <= 1'b0;
            store_clear     <= 1'b0;
            sweep_restart   <= 1'b0;
            mimic_mode      <= 1'b0;
            model_valid     <= 1'b0;
        end else begin
            ad_acq_start    <= 1'b0;
            fft_start_en    <= 1'b0;
            rls_start_en    <= 1'b0;
            store_result_en <= 1'b0;
            classify_start  <= 1'b0;
            store_clear     <= 1'b0;
            sweep_restart   <= 1'b0;

            case(state)
                ST_IDLE: begin
                    if(!mimic_mode && sweep_step_sync) begin
                        frame_is_last <= (f_word >= STOP_WORD);
                        state         <= ST_PULSE_ACQ;
                    end
                end

                ST_PULSE_ACQ: begin
                    ad_acq_start <= 1'b1;
                    state        <= ST_WAIT_BUF;
                end

                ST_WAIT_BUF: begin
                    if(ad_buf_full) begin
                        fft_start_en <= 1'b1;
                        state        <= ST_WAIT_FFT;
                    end
                end

                ST_WAIT_FFT: begin
                    if(fft_done) begin
                        store_result_en <= 1'b1;
                        rls_start_en    <= 1'b1;
                        state           <= ST_WAIT_RLS;
                    end
                end

                ST_WAIT_RLS: begin
                    if(rls_done) begin
                        if(frame_is_last) begin
                            if(rls_avg_sq_err > rls_err_limit) begin
                                store_clear   <= 1'b1;
                                sweep_restart <= 1'b1;
                                mimic_mode    <= 1'b0;
                                model_valid   <= 1'b0;
                                state         <= ST_IDLE;
                            end else begin
                                classify_start <= 1'b1;
                                state          <= ST_WAIT_CLASSIFY;
                            end
                        end else begin
                            state <= ST_IDLE;
                        end
                    end
                end

                ST_WAIT_CLASSIFY: begin
                    if(classifier_done) begin
                        mimic_mode  <= 1'b1;
                        model_valid <= 1'b1;
                        state       <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
