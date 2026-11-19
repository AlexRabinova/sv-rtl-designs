`timescale 1ns/1ns
module fibonacci_gen #(
    parameter WIDTH = 16
) (
    input  logic              clk,
    input  logic              rst_n,      // Active-low asynchronous reset
    input  logic              cin,        // Carry-in used to bootstrap the first '1'
    output logic [WIDTH-1:0]  fib_out     // System output from Register B
);

    // Internal signals for registers and adder
    logic [WIDTH-1:0] reg_a;
    logic [WIDTH-1:0] reg_b;
    logic [WIDTH:0]   adder_sum;          // Includes 1 extra bit for potential overflow, though c_out is dropped

    // Full Adder logic: Input A (reg_a) + Input B (reg_b) + cin
    // We drop the carry-out (c_out) by taking only the lower WIDTH bits of the sum.
    assign adder_sum = {1'b0, reg_a} + {1'b0, reg_b} + {1'b0, {(WIDTH-1){1'b0}}, cin};

    // Sequential logic for Register A and Register B
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_a <= '0;
            reg_b <= '0;
        end else begin
            reg_a <= adder_sum[WIDTH-1:0]; // Register A input connects to the full adder output
            reg_b <= reg_a;                // Register B input connects to Register A's output
        end
    end

    // The output of Register B is the system output
    assign fib_out = reg_b;

endmodule