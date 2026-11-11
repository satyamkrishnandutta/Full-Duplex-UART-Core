module rx_sync (
    input wire clk,
    input wire rst,
    input wire rx_in,
    output reg rx_sync
);
    reg q1;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            rx_sync<=1'b1;
            q1<=1'b1;
        end
        else begin
            q1<=rx_in;
            rx_sync<=q1;
        end
    end
endmodule