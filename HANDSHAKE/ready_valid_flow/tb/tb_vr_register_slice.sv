`timescale 1ns/1ps

module tb_vr_register_slice;

    parameter int DATA_WIDTH = 32;
    parameter int NUM_TRANSACTIONS = 1000;

    // Signals
    logic                  clk;
    logic                  rst_n;
    
    // Upstream
    logic                  s_valid;
    logic                  s_ready;
    logic [DATA_WIDTH-1:0] s_data;
    
    // Downstream
    logic                  m_valid;
    logic                  m_ready;
    logic [DATA_WIDTH-1:0] m_data;

    // Instantiate the DUT (Device Under Test)
    vr_register_slice #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .*
    );

    // Clock Generation (100 MHz)
    always #5 clk = ~clk;

    // Scoreboard queues to track data integrity
    logic [DATA_WIDTH-1:0] ref_queue[$];
    int tx_count = 0;
    int rx_count = 0;

    initial begin
        // Initialize signals
        clk     = 0;
        rst_n   = 0;
        s_valid = 0;
        s_data  = '0;
        m_ready = 0;

        // Apply Reset
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Run concurrent driver and consumer threads
        fork
            // Thread 1: Upstream Producer (random valid/data generation)
            begin
                for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
                    // Wait for random delay or immediate send
                    @(posedge clk);
                    s_valid <= 1'b1;
                    s_data  <= $urandom;
                    ref_queue.push_back(s_data);
                    tx_count++;

                    // Handshake handshake wait loop
                    do begin
                        @(posedge clk);
                    end while (!(s_valid && s_ready));

                    // Optionally insert random bubbles (deassert s_valid)
                    if ($urandom_range(0, 2) == 0) begin
                        s_valid <= 1'b0;
                        repeat ($urandom_range(1, 3)) @(posedge clk);
                    end
                end
                s_valid <= 1'b0;
            end

            // Thread 2: Downstream Consumer (randomly stalls m_ready)
            begin
                while (rx_count < NUM_TRANSACTIONS) begin
                    @(posedge clk);
                    // Randomly decide whether to accept data (AXI style backpressure)
                    m_ready <= $urandom_range(0, 3); // 75% ready, 25% stall
                end
                m_ready <= 1'b0;
            end

            // Thread 3: Scorechecker / Monitor
            begin
                forever begin
                    @(posedge clk);
                    if (m_valid && m_ready) begin
                        logic [DATA_WIDTH-1:0] expected_data;
                        if (ref_queue.size() == 0) begin
                            $error("[%0t] Error: Received data 0x%0h when reference queue was empty!", $time, m_data);
                        end else begin
                            expected_data = ref_queue.pop_front();
                            if (m_data !== expected_data) begin
                                $error("[%0t] Mismatch! Expected: 0x%0h, Got: 0x%0h", $time, expected_data, m_data);
                            end else begin
                                $display("[%0t] Match verified: 0x%0h", $time, m_data);
                            end
                            rx_count++;
                            if (rx_count >= NUM_TRANSACTIONS) begin
                                $display("\n--- TEST PASSED SUCCESSFULLY (%0d transactions) ---", NUM_TRANSACTIONS);
                                $finish;
                            end
                        end
                    end
                end
            end
        join
    end

    // Timeout watchdog safety net
    initial begin
        #5000000;
        $error("Simulation timed out!");
        $finish;
    end
    initial begin
        $dumpfile("waveform.vcd"); // Specifies the output VCD file name
        $dumpvars(0, tb_vr_register_slice); // 0 dumps all signals recursively starting from tb_credit_flow
    end
endmodule