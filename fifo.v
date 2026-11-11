// ============================================================================
// Module: fifo
// Description: Synchronous circular FIFO buffer with parametric width (W)
//              and depth (2^B). Handles independent push and pop strobes
//              on a single clock domain with full/empty flag tracking.
// ============================================================================

module fifo #(
    parameter B = 4, // Address bit width (Storage Depth = 2^B = 16 words)
    parameter W = 8  // Data word width (8 bits for UART bytes)
)(
    input  wire         clk,     // System clock
    input  wire         rst,     // Active-high asynchronous reset
    input  wire         rd,      // Read (pop) enable pulse
    input  wire         wr,      // Write (push) enable pulse
    input  wire [W-1:0] w_data,  // Data byte input
    output wire         empty,   // High when buffer has 0 unread bytes
    output wire         full,    // High when buffer is at 100% capacity
    output wire [W-1:0] r_data   // Data byte output at read pointer
);

    // ------------------------------------------------------------------------
    // Internal Hardware Registers
    // ------------------------------------------------------------------------
    reg [W-1:0] array_reg [2**B-1:0]; // Memory matrix (16 x 8 bits)
    
    reg [B-1:0] w_ptr_reg, w_ptr_next;
    reg [B-1:0] r_ptr_reg, r_ptr_next;
    
    reg full_reg, full_next;
    reg empty_reg, empty_next;

    // ------------------------------------------------------------------------
    // Sequential Memory Array Write
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (wr && !full_reg) begin
            array_reg[w_ptr_reg] <= w_data;
        end
    end

    // ------------------------------------------------------------------------
    // Sequential Register Updates (Pointers & Status Flags)
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            w_ptr_reg <= {B{1'b0}};
            r_ptr_reg <= {B{1'b0}};
            full_reg  <= 1'b0;
            empty_reg <= 1'b1;
        end else begin
            w_ptr_reg <= w_ptr_next;
            r_ptr_reg <= r_ptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    // ------------------------------------------------------------------------
    // Next-State Logic for Pointers and Flags (Combinational)
    // ------------------------------------------------------------------------
    always @(*) begin
        // Retain current state by default
        w_ptr_next = w_ptr_reg;
        r_ptr_next = r_ptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        case ({wr, rd})
            // 2'b00: No Operation (retains state)

            // 2'b01: Read / Pop Operation
            2'b01: begin
                if (!empty_reg) begin
                    r_ptr_next = r_ptr_reg + 1'b1;
                    full_next  = 1'b0; // Pop guarantees buffer is no longer full
                    
                    if (r_ptr_next == w_ptr_reg) begin
                        empty_next = 1'b1; // Read pointer caught up to write pointer
                    end
                end
            end

            // 2'b10: Write / Push Operation
            2'b10: begin
                if (!full_reg) begin
                    w_ptr_next = w_ptr_reg + 1'b1;
                    empty_next = 1'b0; // Push guarantees buffer is no longer empty
                    
                    if (w_ptr_next == r_ptr_reg) begin
                        full_next = 1'b1; // Write pointer wrapped around to read pointer
                    end
                end
            end

            // 2'b11: Simultaneous Read and Write
            2'b11: begin
                if (empty_reg) begin
                    // Cannot pop while empty; process push only
                    w_ptr_next = w_ptr_reg + 1'b1;
                    empty_next = 1'b0;
                end else if (full_reg) begin
                    // Cannot push while full; process pop only
                    r_ptr_next = r_ptr_reg + 1'b1;
                    full_next  = 1'b0;
                end else begin
                    // Both pointers advance; net item count remains unchanged
                    w_ptr_next = w_ptr_reg + 1'b1;
                    r_ptr_next = r_ptr_reg + 1'b1;
                end
            end

            default: ;
        endcase
    end

    // ------------------------------------------------------------------------
    // Continuous Output Drivers
    // ------------------------------------------------------------------------
    assign r_data = array_reg[r_ptr_reg];
    assign empty  = empty_reg;
    assign full   = full_reg;

endmodule