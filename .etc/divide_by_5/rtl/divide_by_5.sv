`timescale 1ns / 1ps

module divide_by_5 (
    input  wire clk,
    input  wire rst_n,
    output wire clk_out
);

    reg [2:0] count_p;
    reg       clkA;
    reg       clkB;

    // 1. Mod-5 Counter on Rising Edge
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_p <= 3'd0;
            clkA    <= 1'b0;
        end else begin
            if (count_p == 3'd4) begin
                count_p <= 3'd0;
            end else begin
                count_p <= count_p + 1'b1;
            end
            
            // clkA is high when count is 2 or 3 (2 cycles high out of 5)
            if (count_p == 3'd2 || count_p == 3'd3)
                clkA <= 1'b1;
            else
                clkA <= 1'b0;
        end
    end

    // 2. Sample clkA on the Falling Edge to get a half-cycle delay
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clkB <= 1'b0;
        end else begin
            clkB <= clkA;
        end
    end

    // 3. Combine both signals to achieve 50% duty cycle
    assign clk_out = clkA | clkB;

endmodule