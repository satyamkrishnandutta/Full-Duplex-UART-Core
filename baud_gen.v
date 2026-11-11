module baud_gen #(
    parameter N = 6,  // Number of counter bits (2^N >= M)
    parameter M = 54  // Modulo divider limit: M = f_clk / (16 * Baud)
)(
    input clk,
    input rst,
    output tick
);
    reg [N-1:0] count=0;

    always @(posedge clk or posedge rst)begin
        if(rst)begin
            count<=0;
        end
        else begin
            if(count<M-1)begin
                count<=count+1;
            end
            else if(count==M-1)begin
                count<=0; 
            end
        end
    end
    
    assign tick = (count==M-1);
    
endmodule

