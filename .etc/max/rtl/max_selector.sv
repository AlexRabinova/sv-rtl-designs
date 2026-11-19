`timescale 1ns/1ps
module max_selector #(
    parameter int WIDTH = 8
)(
    input  logic [WIDTH-1:0] A,
    input  logic [WIDTH-1:0] B,
    input  logic             signed_un_ctrl, // 0: Unsigned, 1: Signed
    output logic [WIDTH-1:0] max_out
);

    // 1. Invert B for subtraction (~B)
    logic [WIDTH-1:0] not_B;
    assign not_B = ~B;

    // 2. Full Adder Subtraction: A + ~B + 1
    // We use a (WIDTH+1)-bit vector to capture the carry-out (cout)
    logic [WIDTH:0] adder_result;
    assign adder_result = {1'b0, A} + {1'b0, not_B} + 1'b1;

    logic [WIDTH-1:0] diff;
    logic             cout;
    assign diff = adder_result[WIDTH-1:0];
    assign cout = adder_result[WIDTH];

    // 3. Unsigned Comparison (A >= B)
    // For unsigned numbers, A >= B is directly indicated by the carry-out of A + ~B + 1.
    logic unsigned_ge;
    assign unsigned_ge = cout;

    // 4. Signed Comparison (A >= B)
    // Extract sign bits
    logic a_sign, b_sign, diff_sign;
    assign a_sign    = A[WIDTH-1];
    assign b_sign    = B[WIDTH-1];
    assign diff_sign = diff[WIDTH-1];

    // Signed Less-Than (A < B) logic:
    // - If signs differ, the negative number is smaller.
    // - If signs are the same, the sign of the difference (diff_sign) determines which is smaller.
    logic signed_lt;
    assign signed_lt = (a_sign ^ b_sign) ? a_sign : diff_sign;

    // Signed Greater-or-Equal (A >= B) is the inverse of signed_lt
    logic signed_ge;
    assign signed_ge = ~signed_lt;

    // 5. Control Mux: Select between signed and unsigned comparison conditions
    logic a_ge_b;
    assign a_ge_b = signed_un_ctrl ? signed_ge : unsigned_ge;

    // 6. Output Mux: Select A if A >= B, otherwise B
    assign max_out = a_ge_b ? A : B;

endmodule