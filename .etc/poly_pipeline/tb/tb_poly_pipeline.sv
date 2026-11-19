
module tb_poly_pipeline;

    // Signals
    logic        clk;
    logic        rst_n;
    logic        valid_in;
    logic [7:0]  x_in;
    logic [7:0]  y_out;
    logic        valid_out;

    // Instantiate the Unit Under Test (UUT)
    // Assuming the pipelined module from earlier is named poly_pipeline_ii1
    poly_pipeline uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .x_in(x_in),
        .y_out(y_out),
        .valid_out(valid_out)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;



    // VCD Dump & Test Stimulus
    initial begin
        // Setup VCD dump file
        $dumpfile("poly_pipeline.vcd");
        $dumpvars(0, tb_poly_pipeline);

        // Initialize signals
        clk      = 1'b0;
        rst_n    = 1'b0;
        valid_in = 1'b0;
        x_in     = 8'd0;

        // Apply Reset
        #20;
        rst_n = 1'b1;
        #15;

        @(posedge clk);

        // Test Task: Send inputs and check pipeline behavior
        $display("=== Starting Pipeline Test ===");

        // Send a burst of back-to-back inputs (Testing II = 1 throughput)
        send_input(8'd0);
        send_input(8'd1);
        send_input(8'd2);
        send_input(8'd3);
        send_input(8'd5);
        send_input(8'd10);
        send_input(8'd15);

        // Idle gap
        valid_in = 1'b0;
        #30;

        // Send another single input
        send_input(8'd25);

        // Wait for pipeline to drain
        #40;

        $display("=== Test Completed Successfully ===");
        $finish;
    end

    // Task to drive inputs cleanly on clock edges
    task send_input(input [7:0] val);
        begin
            @(posedge clk);
            valid_in = 1'b1;
            x_in     = val;
        end
    endtask

    // Monitor / Scoreboard to verify outputs against golden model
    always_ff @(posedge clk) begin
        if (valid_out) begin
            $display("Time = %0t ns | x_out_valid = 1 | y_out = %0d (Hex: 0x%h)", 
                     $time, y_out, y_out);
        end
    end

endmodule