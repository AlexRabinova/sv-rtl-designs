`timescale 100ps/100ps
module freq_doubler_xor #(
    parameter time TPD = 1ns // Propagation delay for edge generation
) (
    input  logic clk_in,
    output logic clk_out
);
    logic clk_delayed;

    // Introduce propagation delay using inertial/transport delay assignment
    assign #TPD clk_delayed = clk_in;

    // XOR gate to produce pulses on rising and falling edges
    assign clk_out = clk_in ^ clk_delayed;

endmodule
