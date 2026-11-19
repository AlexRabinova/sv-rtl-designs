module log2_floor_tb;

    parameter int WIDTH = 8;
    localparam int LOG_WIDTH = $clog2(WIDTH);

    logic                    clk;
    logic                    rst_n;
    logic                    start;
    logic [WIDTH-1:0]        din;
    logic [LOG_WIDTH-1:0]    dout;
    logic                    done;

    // Instantiate Device Under Test (DUT)
    log2_floor #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .din(din),
        .dout(dout),
        .done(done)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // Task to apply test vector and display results
    task run_test(input [WIDTH-1:0] test_val);
        begin
            @(posedge clk);
            din   = test_val;
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            
            // Wait until computation is finished
            @(posedge done);
            @(posedge clk);
            $display("Time = %0t ns | M = %03d (0x%02h) | floor(log2(M)) = %0d", 
                     $time, test_val, test_val, dout);
        end
    endtask

    initial begin
        // Initialize signals
        clk   = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        din   = '0;

        // Apply Reset
        #20;
        rst_n = 1'b1;
        #20;

        $display("=== Starting Shift-Right Log2 Floor Simulation ===");

        // Test boundary values, powers of two, and intermediate numbers
        run_test(8'd1);   // log2(1)   = 0
        run_test(8'd2);   // log2(2)   = 1
        run_test(8'd3);   // log2(3)   = 1
        run_test(8'd4);   // log2(4)   = 2
        run_test(8'd7);   // log2(7)   = 2
        run_test(8'd8);   // log2(8)   = 3 (Corrected from the textbook typo!)
        run_test(8'd15);  // log2(15)  = 3
        run_test(8'd16);  // log2(16)  = 4
        run_test(8'd127); // log2(127) = 6
        run_test(8'd128); // log2(128) = 7
        run_test(8'd255); // log2(255) = 7

        #50;
        $display("=== Simulation Completed Successfully ===");
        $finish;
    end

    initial begin
        $dumpfile("log2_floor_wave.vcd");
        $dumpvars(0, log2_floor_tb); // Dumps all signals in the testbench hierarchy
    end

endmodule