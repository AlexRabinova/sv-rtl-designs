
module tb_dc_blocker_fir4;

    // Testbench signals
    logic        clk;
    logic        rst_n;
    logic [7:0]  din;
    logic signed [8:0] dout;

    // Instantiate the Device Under Test (DUT)
    dc_blocker_fir4 uut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .dout(dout)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk   = 0;
        rst_n = 0;
        din   = 8'd128; // Initial baseline value

        // Apply reset
        #20;
        rst_n = 1;
        #15;

        $display("----------------------------------------");
        $display("Time(ns)\tDIN\tDOUT");
        $display("----------------------------------------");
        $monitor("%0t\t\t%0d\t%0d", $time, din, dout);

        // Step change in DC baseline (letting the filter fill its 4 registers)
        repeat (5) begin
            din = 8'd150; 
            @(posedge clk);
        end

        // Apply AC fluctuations around the 150 DC offset
        din = 8'd170; @(posedge clk); // Above DC -> positive output expected
        din = 8'd130; @(posedge clk); // Below DC -> negative output expected
        din = 8'd160; @(posedge clk);
        din = 8'd140; @(posedge clk);
        din = 8'd155; @(posedge clk);
        din = 8'd145; @(posedge clk);
        din = 8'd150; @(posedge clk);
        din = 8'd150; @(posedge clk);

        #40;
        $finish;
    end

    initial begin
        $dumpfile("dc_blocker_fir4.vcd"); // Name of the generated VCD file
        $dumpvars(0, tb_dc_blocker_fir4);   // Dumps all signals in the testbench hierarchy (level 0 = all nested modules)
    end


endmodule