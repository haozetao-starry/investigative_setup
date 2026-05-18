// I2C Master — simplified byte-stream interface
// 400kHz SCL from 50MHz clock

module i2c_master (
    input  wire        clk,
    input  wire        rst_n,
    // Transaction control
    input  wire        tx_start,       // pulse: start transaction with dev_addr
    input  wire [7:0]  tx_dev_addr,    // 7-bit addr << 1 (0x78 for SSD1306)
    // Byte stream (from ssd1306_cmd)
    input  wire [7:0]  tx_byte,        // byte to send
    input  wire        tx_valid,       // byte is valid
    output reg         tx_ready,       // can accept next byte
    input  wire        tx_last,        // this is the last byte of transaction
    // Status
    output reg         busy,
    output reg         done,           // pulse on transaction complete
    // I2C bus
    output reg         scl,
    inout  wire        sda
);

    localparam SCL_DIV = 64;
    reg [6:0] scl_cnt;
    wire scl_tick = (scl_cnt == SCL_DIV - 1);

    localparam [2:0] S_IDLE      = 3'd0;
    localparam [2:0] S_START     = 3'd1;
    localparam [2:0] S_SEND      = 3'd2;
    localparam [2:0] S_ACK       = 3'd3;
    localparam [2:0] S_STOP      = 3'd4;
    localparam [2:0] S_DONE_S    = 3'd5;

    reg [2:0] state;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;

    reg sda_out, sda_oen;
    assign sda = sda_oen ? 1'bz : sda_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            busy      <= 1'b0;
            done      <= 1'b0;
            scl       <= 1'b1;
            sda_out   <= 1'b1;
            sda_oen   <= 1'b1;
            bit_cnt   <= 3'd0;
            tx_ready  <= 1'b0;
            scl_cnt   <= 7'd0;
        end else begin
            done     <= 1'b0;
            tx_ready <= 1'b0;

            if (state != S_IDLE) begin
                if (scl_tick) scl_cnt <= 7'd0; else scl_cnt <= scl_cnt + 7'd1;
            end

            case (state)
                S_IDLE: begin
                    scl <= 1'b1; sda_out <= 1'b1; sda_oen <= 1'b1; busy <= 1'b0;
                    if (tx_start && tx_valid) begin
                        busy      <= 1'b1;
                        shift_reg <= tx_dev_addr;
                        byte_valid<= 1'b1;
                        scl_cnt   <= 7'd0;
                        state     <= S_START;
                    end
                end

                S_START: begin  // Generate START condition
                    if (scl_tick) begin
                        if (scl) begin
                            sda_out <= 1'b0; sda_oen <= 1'b0;
                            scl <= 1'b0; bit_cnt <= 3'd0; state <= S_SEND;
                        end else begin
                            scl <= 1'b1;
                        end
                    end
                end

                S_SEND: begin  // Send 8 bits
                    if (scl_tick) begin
                        if (scl) begin
                            scl <= 1'b0;
                            if (bit_cnt == 3'd7) state <= S_ACK;
                            else bit_cnt <= bit_cnt + 3'd1;
                        end else begin
                            sda_out <= shift_reg[7]; sda_oen <= 1'b0;
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            scl <= 1'b1;
                        end
                    end
                end

                S_ACK: begin  // Read ACK bit
                    if (scl_tick) begin
                        if (scl) begin
                            scl <= 1'b0;
                            tx_ready <= 1'b1;  // signal we can take next byte
                            sda_oen <= 1'b0; sda_out <= 1'b0;
                        end else begin
                            sda_oen <= 1'b1;  // release for ACK
                            scl <= 1'b1;
                            if (tx_ready && tx_valid) begin
                                shift_reg <= tx_byte;
                                byte_valid<= 1'b1;
                                if (tx_last) state <= S_STOP;
                                else state <= S_SEND;
                            end else if (tx_last) begin
                                state <= S_STOP;
                            end else begin
                                state <= S_ACK;  // wait for next byte
                            end
                        end
                    end
                end

                S_STOP: begin  // Generate STOP condition
                    if (scl_tick) begin
                        if (scl) begin
                            sda_out <= 1'b0; sda_oen <= 1'b0; scl <= 1'b0;
                        end else begin
                            sda_out <= 1'b1; sda_oen <= 1'b0;
                            scl <= 1'b1; state <= S_DONE_S;
                        end
                    end
                end

                S_DONE_S: begin
                    sda_oen <= 1'b1; scl <= 1'b1; busy <= 1'b0; done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
