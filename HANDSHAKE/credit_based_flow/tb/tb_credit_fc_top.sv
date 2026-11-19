`timescale 1ns/1ps

module tb_credit_flow;

    localparam int DATA_WIDTH  = 32;
    localparam int BUFFER_DEPTH = 8;

    logic                  clk;
    logic                  rst_n;

    // Producer Interface
    logic [DATA_WIDTH-1:0] tx_data_in;
    logic                  tx_valid_in;
    logic                  tx_ready_out;

    // Interconnect Link Signals
    logic [DATA_WIDTH-1:0] link_data;
    logic                  link_valid;
    logic                  link_credit_ret;

    // Consumer Interface
    logic [DATA_WIDTH-1:0] rx_data_out;
    logic                  rx_valid_out;
    logic                  rx_pop_in;

    // Instantiate Transmitter
    credit_tx #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_CREDITS(BUFFER_DEPTH)
    ) u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data_in(tx_data_in),
        .tx_valid_in(tx_valid_in),
        .tx_ready_out(tx_ready_out),
        .link_data(link_data),
        .link_valid(link_valid),
        .link_credit_ret(link_credit_ret)
    );

    // Instantiate Receiver
    credit_rx #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(BUFFER_DEPTH)
    ) u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .link_data(link_data),
        .link_valid(link_valid),
        .link_credit_ret(link_credit_ret),
        .rx_data_out(rx_data_out),
        .rx_valid_out(rx_valid_out),
        .rx_pop_in(rx_pop_in)
    );

    // Clock Generation (100 MHz)
    always #5 clk = ~clk;

    // Testbench Variables & Queues
    logic [DATA_WIDTH-1:0] expected_queue[$];
    int match_count = 0;

    // Stimulus & Drivers
    initial begin
        clk         = 0;
        rst_n       = 0;
        tx_data_in  = '0;
        tx_valid_in = 0;
        rx_pop_in   = 0;

        #20;
        rst_n = 1;
        #10;

        $display("--- Test 1: Fill Credit Buffer to Capacity ---");
        for (int i = 0; i < BUFFER_DEPTH; i++) begin
            @(posedge clk);
            tx_valid_in <= 1'b1;
            tx_data_in  <= 32'hA000 + i;
            expected_queue.push_back(32'hA000 + i);
        end

        @(posedge clk);
        tx_valid_in <= 1'b0;

        // Check if tx_ready drops when credits run out
        @(posedge clk);
        if (tx_ready_out == 0) begin
            $display("[PASS] Tx correctly stalled when credits reached 0.");
        end else begin
            $error("[FAIL] Tx failed to drop tx_ready when credits emptied.");
        end

        #30;

        $display("--- Test 2: Drain Receiver FIFO and Return Credits ---");
        while (rx_valid_out) begin
            @(posedge clk);
            rx_pop_in <= 1'b1;
        end
        @(posedge clk);
        rx_pop_in <= 1'b0;

        #20;

        $display("--- Test 3: Continuous Streaming with Random Consumer Stall ---");
        fork
            // Producer Thread
            begin
                for (int j = 0; j < 50; j++) begin
                    @(posedge clk);
                    while (!tx_ready_out) @(posedge clk); // Wait if out of credits
                    tx_valid_in <= 1'b1;
                    tx_data_in  <= 32'hC000 + j;
                    expected_queue.push_back(32'hC000 + j);
                end
                @(posedge clk);
                tx_valid_in <= 1'b0;
            end

            // Consumer Thread with Randomized Backpressure
            begin
                while (match_count < 58) begin // 8 from Test 1 + 50 from Test 3
                    @(posedge clk);
                    rx_pop_in <= ($urandom_range(0, 100) > 40) && rx_valid_out;
                end
                @(posedge clk);
                rx_pop_in <= 1'b0;
            end
        join

        #50;
        $display("--- SUCCESS: All %0d words transferred and verified correctly! ---", match_count);
        $finish;
    end

    // Receiver Scoreboard Monitor
    always_ff @(posedge clk) begin
        if (rst_n && rx_valid_out && rx_pop_in) begin
            logic [DATA_WIDTH-1:0] expected_val;
            expected_val = expected_queue.pop_front();
            if (rx_data_out === expected_val) begin
                match_count++;
            end else begin
                $error("[MISMATCH] Expected %0h, Received %0h at time %0t", expected_val, rx_data_out, $time);
            end
        end
    end

  
  	// Waveform Generation Block
    initial begin
        $dumpfile("waveform.vcd"); // Specifies the output VCD file name
        $dumpvars(0, tb_credit_flow); // 0 dumps all signals recursively starting from tb_credit_flow
    end
endmodule