`timescale 1ns/1ps

module tb_cdc_req_ack;

    // Parameters
    parameter int DATA_WIDTH = 8;
    parameter time CLK_SRC_PERIOD = 10.0; // 100 MHz
    parameter time CLK_DST_PERIOD = 30.0; // ~33.3 MHz

    // Signals
    logic                  clk_src;
    logic                  rst_src_n;
    logic                  valid_src_i;
    logic [DATA_WIDTH-1:0] data_src_i;
    logic                  ready_src_o;

    logic                  clk_dst;
    logic                  rst_dst_n;
    logic                  valid_dst_o;
    logic [DATA_WIDTH-1:0] data_dst_o;

    // Instantiate DUT
    cdc_req_ack #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk_src(clk_src),
        .rst_src_n(rst_src_n),
        .valid_src_i(valid_src_i),
        .data_src_i(data_src_i),
        .ready_src_o(ready_src_o),

        .clk_dst(clk_dst),
        .rst_dst_n(rst_dst_n),
        .valid_dst_o(valid_dst_o),
        .data_dst_o(data_dst_o)
    );

    // Clock Generation: 100 MHz Source Clock
    initial begin
        clk_src = 1'b0;
        forever #(CLK_SRC_PERIOD / 2.0) clk_src = ~clk_src;
    end

    // Clock Generation: ~33.3 MHz Destination Clock (Asynchronous)
    initial begin
        clk_dst = 1'b0;
        // Introduce a small phase offset to emphasize asynchronous nature
        #(CLK_DST_PERIOD / 3.0);
        forever #(CLK_DST_PERIOD / 2.0) clk_dst = ~clk_dst;
    end

    // Task to send a packet across CDC
    task automatic send_data(input [DATA_WIDTH-1:0] val);
        begin
            // Wait until source is ready
            @(posedge clk_src);
            while (!ready_src_o) begin
                @(posedge clk_src);
            end

            // Drive valid and data for one cycle
            valid_src_i <= 1'b1;
            data_src_i  <= val;
            
            $display("[%0t ns] [SRC] Sending data: 0x%0h", $time, val);
            
            @(posedge clk_src);
            valid_src_i <= 1'b0;
        end
    endtask

    // Monitor destination reception
    always @(posedge clk_dst) begin
        if (valid_dst_o) begin
            $display("[%0t ns] [DST] Received data: 0x%0h", $time, data_dst_o);
        end
    end

    // Test Sequence
    initial begin
        // Initialize signals
        rst_src_n   = 1'b0;
        rst_dst_n   = 1'b0;
        valid_src_i = 1'b0;
        data_src_i  = '0;

        // Apply Resets asynchronously
        #45;
        rst_src_n = 1'b1;
        #20;
        rst_dst_n = 1'b1;

        $display("[%0t ns] Resets released. Starting test sequence...", $time);
        @(posedge clk_src);

        // Send a sequence of values
        send_data(8'hA5);
        
        // Wait long enough for the handshake to clear before sending next
        #150;
        send_data(8'h3C);

        #150;
        send_data(8'hFF);

        // Test back-to-back requests (should respect ready signal backpressure)
        #150;
        send_data(8'h12);
        send_data(8'h34); // This will wait until previous handshake completes

        #300;
        $display("[%0t ns] Testbench finished successfully.", $time);
        $finish;
    end

endmodule