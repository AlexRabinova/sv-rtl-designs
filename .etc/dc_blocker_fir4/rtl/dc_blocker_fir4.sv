module dc_blocker_fir4 (
    input  logic        clk,
    input  logic        rst_n,      // Active-low asynchronous reset
    input  logic [7:0]  din,        // 8-bit unsigned ADC input
    output logic signed [8:0] dout  // 9-bit signed AC output (DC removed)
);

    // 4 registers for the 4-tap moving average delay line
    logic [7:0] reg0, reg1, reg2, reg3;

    // Shift register chain (Pipeline delay line)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg0 <= '0;
            reg1 <= '0;
            reg2 <= '0;
            reg3 <= '0;
        end else begin
            reg0 <= din;
            reg1 <= reg0;
            reg2 <= reg1;
            reg3 <= reg2;
        end
    end

    // Adder tree to calculate the cumulative sum of the 4 samples
    // Max sum = 4 * 255 = 1020, requiring 10 bits
    logic [9:0] sum;
    assign sum = {2'b00, reg0} + {2'b00, reg1} + {2'b00, reg2} + {2'b00, reg3};

    // Hardwired division by 4 (Equivalent to sum / 4)
    // Slices bits [9:2], discarding the 2 LSBs with zero gate overhead
    logic [7:0] dc_est;
    assign dc_est = sum[9:2];

    // Subtractor: dout = din - dc_est
    // Cast to signed to prevent unsigned underflow wrap-around when din < dc_est
    assign dout = $signed({1'b0, din}) - $signed({1'b0, dc_est});

endmodule