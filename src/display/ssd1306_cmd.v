// SSD1306 OLED Controller — Init sequence + framebuffer refresh
// Drives i2c_master byte-by-byte via valid/ready handshake

module ssd1306_cmd (
    input  wire        clk,
    input  wire        rst_n,
    // Framebuffer read
    output reg  [9:0]  fb_addr,
    input  wire [7:0]  fb_data,
    input  wire        refresh_req,
    output reg         busy,
    output reg         init_done,
    // I2C byte-stream interface
    output reg         i2c_tx_start,
    output reg  [7:0]  i2c_tx_dev,
    output reg  [7:0]  i2c_tx_byte,
    output reg         i2c_tx_valid,
    output reg         i2c_tx_last,
    input  wire        i2c_tx_ready,
    input  wire        i2c_bsy,
    input  wire        i2c_done
);

    localparam PWRUP_DELAY = 24'd10000000;
    localparam INIT_CMDS    = 23;

    localparam [2:0] S_PWRUP    = 3'd0;
    localparam [2:0] S_INIT     = 3'd1;
    localparam [2:0] S_IDLE     = 3'd2;
    localparam [2:0] S_REFRESH  = 3'd3;

    reg [2:0]  state;
    reg [23:0] pwrup_cnt;
    reg [4:0]  init_idx;
    reg [9:0]  fb_idx;

    // ── I2C byte sequencer ─────────────────────────────
    reg [4:0]  byte_seq_idx;
    reg [4:0]  byte_seq_len;
    reg [7:0]  byte_seq [0:31];

    // ── Init command table ─────────────────────────────
    reg [7:0] init_cmds [0:INIT_CMDS-1];
    integer i;
    initial begin
        init_cmds[0]=8'hAE; init_cmds[1]=8'hD5; init_cmds[2]=8'h80;
        init_cmds[3]=8'hA8; init_cmds[4]=8'h3F; init_cmds[5]=8'hD3;
        init_cmds[6]=8'h00; init_cmds[7]=8'h40; init_cmds[8]=8'h8D;
        init_cmds[9]=8'h14; init_cmds[10]=8'h20; init_cmds[11]=8'h00;
        init_cmds[12]=8'hA1; init_cmds[13]=8'hC8; init_cmds[14]=8'hDA;
        init_cmds[15]=8'h12; init_cmds[16]=8'h81; init_cmds[17]=8'hCF;
        init_cmds[18]=8'hD9; init_cmds[19]=8'hF1; init_cmds[20]=8'hDB;
        init_cmds[21]=8'h30; init_cmds[22]=8'hAF;  // Display ON (skip A4/A6/set-range for now)
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_PWRUP;
            pwrup_cnt  <= 24'd0;
            init_idx   <= 5'd0;
            init_done  <= 1'b0;
            busy       <= 1'b0;
            i2c_tx_start <= 1'b0;
            i2c_tx_valid <= 1'b0;
            fb_idx     <= 10'd0;
        end else begin
            i2c_tx_start <= 1'b0;
            i2c_tx_valid <= 1'b0;

            case (state)
                S_PWRUP: begin
                    busy <= 1'b1;
                    if (pwrup_cnt >= PWRUP_DELAY) begin
                        state <= S_INIT; init_idx <= 5'd0; pwrup_cnt <= 24'd0;
                    end else pwrup_cnt <= pwrup_cnt + 24'd1;
                end

                S_INIT: begin
                    if (!i2c_bsy) begin
                        if (init_idx == 0) begin
                            // Start first transaction
                            i2c_tx_start <= 1'b1;
                            i2c_tx_dev   <= 8'h78;
                            i2c_tx_byte  <= 8'h00;  // ctrl byte: command mode
                            i2c_tx_valid <= 1'b1;
                            i2c_tx_last  <= 1'b0;
                            byte_seq_idx <= 5'd0;
                            byte_seq_len <= 5'd23;  // INIT_CMDS
                            for (i = 0; i < INIT_CMDS; i = i + 1)
                                byte_seq[i] <= init_cmds[i];
                            init_idx <= 5'd1;  // ← FIX: prevent re-entering this branch
                        end else if (i2c_tx_ready) begin
                            if (byte_seq_idx < byte_seq_len) begin
                                i2c_tx_byte  <= byte_seq[byte_seq_idx];
                                i2c_tx_valid <= 1'b1;
                                i2c_tx_last  <= (byte_seq_idx == byte_seq_len - 1);
                                byte_seq_idx <= byte_seq_idx + 5'd1;
                            end
                        end else if (i2c_done) begin
                            init_done <= 1'b1; busy <= 1'b0; state <= S_IDLE;
                        end
                    end
                end

                S_IDLE: begin
                    busy <= 1'b0;
                    if (refresh_req && init_done) begin
                        busy <= 1'b1; fb_idx <= 10'd0; state <= S_REFRESH;
                    end
                end

                S_REFRESH: begin
                    if (!i2c_bsy && !i2c_tx_valid) begin
                        if (fb_idx == 0) begin
                            // Start: send column+page range commands then data
                            i2c_tx_start <= 1'b1;
                            i2c_tx_dev   <= 8'h78;
                            i2c_tx_byte  <= 8'h00;  // command mode
                            i2c_tx_valid <= 1'b1;
                            i2c_tx_last  <= 1'b0;
                            byte_seq_len <= 6;   // 6 cmd bytes for addr setup
                            byte_seq[0]<=8'h21; byte_seq[1]<=8'h00; byte_seq[2]<=8'h7F;
                            byte_seq[3]<=8'h22; byte_seq[4]<=8'h00; byte_seq[5]<=8'h07;
                            byte_seq_idx <= 5'd0;
                        end else if (i2c_tx_ready) begin
                            if (byte_seq_idx < byte_seq_len) begin
                                i2c_tx_byte  <= byte_seq[byte_seq_idx];
                                i2c_tx_valid <= 1'b1;
                                i2c_tx_last  <= (byte_seq_idx == byte_seq_len - 1);
                                byte_seq_idx <= byte_seq_idx + 5'd1;
                            end
                        end else if (i2c_done) begin
                            // Now send 2nd transaction: data mode, 1024 bytes
                            if (fb_idx < 1024) begin
                                i2c_tx_start <= 1'b1;
                                i2c_tx_dev   <= 8'h78;
                                i2c_tx_byte  <= 8'h40;  // data mode
                                i2c_tx_valid <= 1'b1;
                                i2c_tx_last  <= 1'b0;
                            end else begin
                                busy <= 1'b0; state <= S_IDLE;
                            end
                        end
                    end

                    // During data-mode transaction, feed FB bytes
                    if (i2c_tx_ready && !i2c_tx_start) begin
                        fb_addr <= fb_idx;
                        i2c_tx_byte  <= fb_data;
                        i2c_tx_valid <= 1'b1;
                        i2c_tx_last  <= (fb_idx == 10'd1023);
                        fb_idx <= fb_idx + 10'd1;
                    end
                end

                default: state <= S_PWRUP;
            endcase
        end
    end

endmodule
