`timescale 1ns/1ps
module fir_filter_folded #(
    parameter int DATA_WIDTH  = 16,
    parameter int NUM_TAPS    = 101,
    parameter int ADDR_WIDTH  = 7   // 7 bits can address up to 128 (enough for 101 taps)
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     valid_i,
    input  logic signed [DATA_WIDTH-1:0] x_i,
    input  logic signed [DATA_WIDTH-1:0] h_rom [NUM_TAPS], // Coefficient ROM
    output logic                     valid_o,
    output logic signed [37:0]       y_o          // 38-bit accumulated output
);

    // 1. Shift Register Delay Line for x[n]
    logic signed [DATA_WIDTH-1:0] shift_reg [NUM_TAPS];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_TAPS; i++) begin
                shift_reg[i] <= '0;
            end
        end else if (valid_i) begin
            shift_reg[0] <= x_i;
            for (int i = 1; i < NUM_TAPS; i++) begin
                shift_reg[i] <= shift_reg[i-1];
            end
        end
    end

    // 2. Counter / Address Generator (0 to 100)
    logic [ADDR_WIDTH-1:0] tap_counter;
    logic                  processing;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tap_counter <= '0;
            processing  <= 1'b0;
        end else begin
            if (valid_i) begin
                tap_counter <= '0;
                processing  <= 1'b1;
            end else if (processing) begin
                if (tap_counter == NUM_TAPS - 1) begin
                    tap_counter <= '0;
                    processing  <= 1'b0;
                end else begin
                    tap_counter <= tap_counter + 1'b1;
                end
            end
        end
    end

    // 3. Multiplexor (Selects x[n-k] based on counter address)
    logic signed [DATA_WIDTH-1:0] selected_x;
    assign selected_x = shift_reg[tap_counter];

    // 4. ROM Lookup for Coefficient h[n]
    logic signed [DATA_WIDTH-1:0] selected_h;
    assign selected_h = h_rom[tap_counter];

    // 5. Multiply Unit
    logic signed [31:0] mult_out;
    assign mult_out = selected_x * selected_h;

    // 6. Accumulator Register & Full Adder
    logic signed [37:0] acc_reg;
    logic signed [37:0] adder_out;

    // Clear accumulator at the start of a new computation cycle (tap_counter == 0), 
    // otherwise accumulate the running sum.
    assign adder_out = ((tap_counter == '0) ? '0 : acc_reg) + mult_out;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg <= '0;
        end else if (processing) begin
            acc_reg <= adder_out;
        end
    end

    // 7. Output Generation (Pulses valid_o when the 101-tap accumulation finishes)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_o     <= '0;
            valid_o <= 1'b0;
        end else begin
            if (processing && (tap_counter == NUM_TAPS - 1)) begin
                y_o     <= adder_out;
                valid_o <= 1'b1;
            end else begin
                valid_o <= 1'b0;
            end
        end
    end

endmodule