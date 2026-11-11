// ============================================================================
// Module: uart
// Description: Top-level wrapper instantiating baud_gen, uart_rx, uart_tx,
//              and dual FIFOs (RX & TX) to create a non-blocking 8N1 UART core.
// ============================================================================

module uart #(
    parameter DBIT    = 8,   // Number of data bits
              SB_TICK = 16,  // Stop bit ticks (16 for 1 stop bit)
              DVSR    = 54,  // Baud rate divisor (100MHz / (16 * 115200) = 54)
              FIFO_W  = 4    // FIFO depth parameter (2^4 = 16 words)
)(
    input  wire       clk,      // 100MHz system clock
    input  wire       rst,      // Active-high asynchronous reset
    input  wire       rx,       // Serial RX line
    input  wire       rd_uart,  // Read strobe from system logic (pops RX FIFO)
    input  wire       wr_uart,  // Write strobe from system logic (pushes TX FIFO)
    input  wire [7:0] w_data,   // Parallel byte input for transmission
    output wire       tx,       // Serial TX line
    output wire       rx_empty, // High when no received bytes are available
    output wire       tx_full,  // High when TX buffer cannot accept more bytes
    output wire [7:0] r_data    // Parallel byte output read from RX FIFO
);

    // ------------------------------------------------------------------------
    // Internal Interconnect Signals
    // ------------------------------------------------------------------------
    wire       s_tick;
    wire       rx_done_tick;
    wire [7:0] rx_dout;
    wire       tx_done_tick;
    wire       tx_fifo_empty;
    wire [7:0] tx_fifo_rdata;
    
    reg        tx_fifo_rd;
    reg        tx_start;

    // ------------------------------------------------------------------------
    // Module Instantiations
    // ------------------------------------------------------------------------

    // 1. Baud Rate Generator (16x oversampling tick generator)
    baud_gen #(
        .N(7),           // Counter width (2^7 = 128 > 54)
        .M(DVSR)
    ) baud_gen_unit (
        .clk(clk),
        .rst(rst),
        .max_tick(s_tick)
    );

    // 2. UART Receiver Core
    uart_rx #(
        .DBIT(DBIT),
        .SB_TICK(SB_TICK)
    ) uart_rx_unit (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .s_tick(s_tick),
        .rx_done_tick(rx_done_tick),
        .dout(rx_dout)
    );

    // 3. Receive FIFO (Buffers incoming bytes from uart_rx)
    fifo #(
        .B(FIFO_W),
        .W(DBIT)
    ) fifo_rx_unit (
        .clk(clk),
        .rst(rst),
        .rd(rd_uart),
        .wr(rx_done_tick),
        .w_data(rx_dout),
        .empty(rx_empty),
        .full(),              // Open / Unused (overruns handled at system level)
        .r_data(r_data)
    );

    // 4. Transmit FIFO (Buffers outgoing bytes from system logic)
    fifo #(
        .B(FIFO_W),
        .W(DBIT)
    ) fifo_tx_unit (
        .clk(clk),
        .rst(rst),
        .rd(tx_fifo_rd),
        .wr(wr_uart),
        .w_data(w_data),
        .empty(tx_fifo_empty),
        .full(tx_full),
        .r_data(tx_fifo_rdata)
    );

    // 5. UART Transmitter Core
    uart_tx #(
        .DBIT(DBIT),
        .SB_TICK(SB_TICK)
    ) uart_tx_unit (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .s_tick(s_tick),
        .din(tx_fifo_rdata),
        .tx_done_tick(tx_done_tick),
        .tx(tx)
    );

    // ------------------------------------------------------------------------
    // TX Auto-Feeder Control Logic (FSM)
    // ------------------------------------------------------------------------
    // Automatically pops bytes from tx_fifo and triggers uart_tx whenever 
    // tx_fifo is non-empty and uart_tx is idle.
    
    localparam IDLE = 1'b0,
               WAIT = 1'b1;

    reg state_reg, state_next;

    always @(posedge clk or posedge rst) begin
        if (rst)
            state_reg <= IDLE;
        else
            state_reg <= state_next;
    end

    always @(*) begin
        state_next = state_reg;
        tx_fifo_rd = 1'b0;
        tx_start   = 1'b0;

        case (state_reg)
            IDLE: begin
                if (!tx_fifo_empty) begin
                    tx_fifo_rd = 1'b1; // Pop byte from FIFO
                    tx_start   = 1'b1; // Trigger transmitter
                    state_next = WAIT;
                end
            end

            WAIT: begin
                // Hold until current byte serialization completes over the wire
                if (tx_done_tick)
                    state_next = IDLE;
            end
        endcase
    end

endmodule