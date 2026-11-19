module tb_fwft_fifo;

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4; // Depth = 16 + 1 reg = 17 capacity

    logic                   clk;
    logic                   rst_n;
    logic                   rd_en;
    logic [DATA_WIDTH-1:0]  dout;
    logic                   empty;
    logic                   wr_en;
    logic [DATA_WIDTH-1:0]  din;
    logic                   full;

    // Instantiate Design Under Test (DUT)
    fwftf_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rd_en(rd_en),
        .dout(dout),
        .empty(empty),
        .wr_en(wr_en),
        .din(din),
        .full(full)
    );

    // Clock Generation (10ns period -> 100MHz)
    always #5 clk = ~clk;

    // Reference Queue to check golden results
    logic [DATA_WIDTH-1:0] ref_q[$];

    // Task: Single Write
    task write_fifo;
        input [DATA_WIDTH-1:0] val;
        begin
            @(negedge clk);
            while (full) @(negedge clk); // wait if full
            wr_en = 1'b1;
            din   = val;
            ref_q.push_back(val);
            @(negedge clk);
            wr_en = 1'b0;
        end
    endtask

    // Task: Single Read (1-cycle pulse)
    task read_fwft;
        output [DATA_WIDTH-1:0] val;
        begin
            @(negedge clk);
            while (empty) @(negedge clk); // wait if empty
            rd_en = 1'b1;
            val   = dout; // Zero-latency check: data is valid combinationally right now
            @(negedge clk);
            rd_en = 1'b0;
        end
    endtask

    // Task: Multi-cycle Burst Read (Holds rd_en high for exactly 4 cycles)
    task read_4_cycle_burst;
        int k;
        logic [DATA_WIDTH-1:0] exp_val, act_val;
        begin
            @(negedge clk);
            while (empty) @(negedge clk); // wait if empty
            
            // Assert rd_en and hold it high across 4 consecutive clock cycles
            rd_en = 1'b1;
            
            for (k = 0; k < 4; k++) begin
                // Capture data present on the output bus during this cycle
                act_val = dout;
                exp_val = ref_q.pop_front();
                
                if (act_val !== exp_val) begin
                    $error("4-Cycle Burst Mismatch at index %0d! Expected: 0x%h, Got: 0x%h", k, exp_val, act_val);
                end else begin
                    $display("Successfully read 4-cycle burst data [%0d]: 0x%h", k, act_val);
                end
                
                @(negedge clk); // Advance to next cycle while keeping rd_en high
            end
            
            // Drop rd_en after 4 cycles
            rd_en = 1'b0;
        end
    endtask

    // Variables declared at module level for strict parser compliance
    logic [DATA_WIDTH-1:0] exp_val;
    logic [DATA_WIDTH-1:0] act_val;
    int i;

    // Test Sequence
    initial begin
        // VCD Waveform Generation
        $dumpfile("fifo_zero_latency.vcd");
        $dumpvars(0, tb_fwft_fifo);

        // Initialize Signals
        clk   = 0;
        rst_n = 0;
        wr_en = 0;
        din   = 0;
        rd_en = 0;

        // Apply Reset (aligned with negedge)
        @(negedge clk);
        rst_n = 0;
        #22;
        @(negedge clk);
        rst_n = 1;
        #20;

        $display("=== TEST 1: True Zero-Latency Single Write Check ===");
        write_fifo(8'h55);

        // Verify that data appears instantly without requiring a read enable or clock wait
        #1;
        if (empty || dout !== 8'h55) begin
            $error("FAIL: Expected 0-cycle availability of 0x55, got empty=%b, dout=0x%h", empty, dout);
        end else begin
            $display("PASS: Zero-latency check successful! 0x55 appeared instantly.");
        end

        // Drain the single item
        read_fwft(act_val);
        if (act_val !== 8'h55) begin
            $error("Mismatch! Expected 0x55, Got 0x%h", act_val);
        end else begin
            $display("Successfully read single item: 0x%h", act_val);
        end

        #20;
        $display("=== TEST 2: Multi-Cycle Burst Read (Holding rd_en high for 4 cycles) ===");
        // Write 10 items into the FIFO
        for (i = 0; i < 10; i++) begin
            write_fifo(8'hA0 + i[7:0]);
        end

        // Read 4 items continuously by holding rd_en high for 4 cycles
        read_4_cycle_burst();

        #20;
        $display("=== TEST 3: Draining Remaining Items Singly ===");
        // Drain the remaining 6 items one by one
        repeat (6) begin
            exp_val = ref_q.pop_front();
            read_fwft(act_val);
            if (act_val !== exp_val) begin
                $error("Drain Mismatch! Expected: 0x%h, Got: 0x%h", exp_val, act_val);
            end else begin
                $display("Successfully read remaining data: 0x%h", act_val);
            end
        end

        #50;
        $display("=== ALL TESTS PASSED SUCCESSFULLY ===");
        $finish;
    end

endmodule