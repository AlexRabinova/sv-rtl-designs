module tb_poly_system;

    logic        clk;
    logic        rst_n;
    logic        valid;
    logic [7:0]  x;
    logic [7:0]  y;
    logic        hold;
    logic        finish;

    // Instantiate Unit Under Test (UUT)
    poly_system uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid(valid),
        .x(x),
        .y(y),
        .hold(hold),
        .finish(finish)
    );

    // 100 MHz Clock Generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        // Initialize Signals
        clk   = 0;
        rst_n = 0;
        valid = 0;
        x     = 8'd0;

        // Apply Reset
        #20;
        rst_n = 1;
        #10;

        // --- Test Case 1: x = 2 ---
        // Expected Math: y = (2^3) + (2^2) + 2 = 8 + 4 + 2 = 14
        @(posedge clk);
        x     = 8'd2;
        valid = 1; // Trigger calculation
        
        @(posedge clk);
        valid = 0; // Drop valid after cycle 1

        // Wait for finish signal
        @(posedge finish);
        #1;
        $display("[%0t] Test 1 -> Input x = %0d | Output y = %0d (Expected: 14)", $time, x, y);

        #20;

        // --- Test Case 2: x = 3 ---
        // Expected Math: y = (3^3) + (3^2) + 3 = 27 + 9 + 3 = 39
        @(posedge clk);
        x     = 8'd3;
        valid = 1;

        @(posedge clk);
        valid = 0;

        @(posedge finish);
        #1;
        $display("[%0t] Test 2 -> Input x = %0d | Output y = %0d (Expected: 39)", $time, x, y);

        #50;
        $finish;
    end

    initial begin
        $dumpfile("poly_system.vcd"); // Name of the generated VCD file
        $dumpvars(0, tb_poly_system);   // Dumps all signals in the testbench hierarchy (level 0 = all nested modules)
    end

endmodule