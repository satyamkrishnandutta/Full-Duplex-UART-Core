// ============================================================================
// Module: uart_rx
// Description: 8N1 UART Receiver core with 16x oversampling.
//              Expects 'rx' to be pre-synchronized via a 2-stage FF CDC sync.
//              's_tick' pulses once per baud clock tick (16 ticks per bit period).
// ============================================================================

module uart_rx (
    input  wire       clk,          // System clock
    input  wire       rst,          // Active-high asynchronous reset
    input  wire       rx,           // Synchronized serial input
    input  wire       s_tick,       // 16x oversampling tick from baud rate generator
    output reg        rx_done_tick, // High for 1 clk cycle when byte reception completes
    output reg  [7:0] dout          // Received byte output register
);

    // FSM encoding
    parameter IDLE  = 2'b00,
              START = 2'b01,
              DATA  = 2'b10,
              STOP  = 2'b11;

    reg [1:0] present_state, next_state;
    reg [3:0] tcount; // Oversampling tick counter (0 to 15)
    reg [2:0] bcount; // Data bit index counter (0 to 7)
    reg [7:0] b_reg;  // Internal shift register for incoming data

    // ------------------------------------------------------------------------
    // Block 1: State Register (Sequential)
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            present_state <= IDLE;
        end else begin
            present_state <= next_state;
        end
    end

    // ------------------------------------------------------------------------
    // Block 2: Next State Logic (Combinational)
    // ------------------------------------------------------------------------
    always @(*) begin
        case (present_state)
            // Wait for start bit falling edge (rx line dropping low)
            IDLE : next_state = (rx == 1'b0) ? START : IDLE;

            // Wait 8 ticks to locate the center of the START bit
            START: next_state = (s_tick && tcount == 4'd7) ? DATA : START;

            // Sample 8 data bits (16 ticks per bit period)
            DATA : next_state = (s_tick && bcount == 3'd7 && tcount == 4'd15) ? STOP : DATA;

            // Wait out 16 ticks for the STOP bit mid-point / duration
            STOP : next_state = (s_tick && tcount == 4'd15) ? IDLE : STOP;

            default : next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // Block 3: Datapath Registers (Sequential)
    // Counters advance only on s_tick pulses to align with baud rate
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tcount <= 4'd0;
            bcount <= 3'd0;
            b_reg  <= 8'd0;
        end else if (s_tick) begin
            case (present_state)
                IDLE: begin
                    tcount <= 4'd0;
                    bcount <= 3'd0;
                end

                START: begin
                    if (tcount == 4'd7)
                        tcount <= 4'd0; // Reset tick count for data bit alignment
                    else
                        tcount <= tcount + 1'b1;
                end

                DATA: begin
                    if (tcount == 4'd15) begin
                        tcount <= 4'd0;
                        b_reg  <= {rx, b_reg[7:1]}; // LSB-first shift register
                        if (bcount == 3'd7)
                            bcount <= 3'd0;
                        else
                            bcount <= bcount + 1'b1;
                    end else begin
                        tcount <= tcount + 1'b1;
                    end
                end

                STOP: begin
                    if (tcount == 4'd15)
                        tcount <= 4'd0;
                    else
                        tcount <= tcount + 1'b1;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Block 4: Output Decoding
    // Registered flag generation avoids glitches during state transitions
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_done_tick <= 1'b0;
            dout         <= 8'd0;
        end else begin
            rx_done_tick <= 1'b0; // Default output state (1 clock cycle strobe)
            
            // Pulse rx_done_tick when STOP bit completion is reached
            if (present_state == STOP && s_tick && tcount == 4'd15) begin
                rx_done_tick <= 1'b1;
                dout         <= b_reg;
            end
        end
    end

endmodule