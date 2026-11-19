`timescale 1ns/1ps

module tb_max_selector;

    // Parameters
    parameter int WIDTH = 8;

    // Testbench Signals
    logic [WIDTH-1:0] A;
    logic [WIDTH-1:0] B;
    logic             signed_un_ctrl;
    logic [WIDTH-1:0] max_out;

    // Instantiate the DUT (Design Under Test)
    max_selector #(
        .WIDTH(WIDTH)
    ) dut (
        .A(A),
        .B(B),
        .signed_un_ctrl(signed_un_ctrl),
        .max_out(max_out)
    );

    // Task to run and check test vectors automatically
    task run_test(
        input [WIDTH-1:0] test_A,
        input [WIDTH-1:0] test_B,
        input             ctrl,
        input [WIDTH-1:0] expected_max
    );
        begin
            A = test_A;
            B = test_B;
            signed_un_ctrl = ctrl;
            #10; // Wait for combinational logic propagation

            if (max_out !== expected_max) begin
                $error("FAIL: Mode=%s | A=%0d (0x%h), B=%0d (0x%h) | Got=%0d (0x%h), Expected=%0d (0x%h)",
                       ctrl ? "SIGNED" : "UNSIGNED",
                       ctrl ? $signed(test_A) : test_A, test_A,
                       ctrl ? $signed(test_B) : test_B, test_B,
                       ctrl ? $signed(max_out) : max_out, max_out,
                       ctrl ? $signed(expected_max) : expected_max, expected_max);
            end else begin
                $display("PASS: Mode=%s | A=%0d, B=%0d | Max=%0d",
                       ctrl ? "SIGNED" : "UNSIGNED",
                       ctrl ? $signed(test_A) : test_A,
                       ctrl ? $signed(test_B) : test_B,
                       ctrl ? $signed(max_out) : max_out);
            end
        end
    endtask

    initial begin
        $display("=== STARTING MAX_SELECTOR TESTBENCH ===");

        // --- VCD FILE GENERATION SETUP ---
        $dumpfile("max_selector_wave.vcd"); // Name of the generated VCD file
        // Dump all variables in this testbench module and its instances (depth 0 means entire hierarchy)
        $dumpvars(0, tb_max_selector);

        // ==========================================
        // 1. UNSIGNED TESTS (signed_un_ctrl = 0)
        // ==========================================
        $display("\n--- Testing Unsigned Mode ---");
        run_test(8'd50,  8'd100, 1'b0, 8'd100); // B is larger
        run_test(8'd200, 8'd100, 1'b0, 8'd200); // A is larger
        run_test(8'd128, 8'd128, 1'b0, 8'd128); // Equal
        
        // Unsigned Boundaries / Extremes (Overflow check simulation)
        run_test(8'h00,  8'hFF,  1'b0, 8'hFF);  // 0 vs 255 (Max unsigned)
        run_test(8'hFF,  8'h01,  1'b0, 8'hFF);  // 255 vs 1
        run_test(8'hFE,  8'hFF,  1'b0, 8'hFF);  // 254 vs 255

        // ==========================================
        // 2. SIGNED TESTS (signed_un_ctrl = 1)
        // Range for 8-bit signed: -128 to 127
        // ==========================================
        $display("\n--- Testing Signed Mode ---");
        run_test(8'd10,  8'd20,  1'b1, 8'd20);  // Positive vs Positive
        run_test(8'd20,  8'd10,  1'b1, 8'd20);  // Positive vs Positive (rev)
        
        // Positive vs Negative (Negative is smaller, Positive wins)
        // 8'shF6 is -10 in decimal
        run_test(8'd10,  8'hF6,  1'b1, 8'd10);  // 10 vs -10 -> Max is 10
        run_test(8'hF6,  8'd10,  1'b1, 8'd10);  // -10 vs 10 -> Max is 10

        // Negative vs Negative
        // 8'shF6 = -10, 8'shEC = -20. (-10 is greater than -20)
        run_test(8'hF6,  8'hEC,  1'b1, 8'hF6);  // -10 vs -20 -> Max is -10
        run_test(8'hEC,  8'hF6,  1'b1, 8'hF6);  // -20 vs -10 -> Max is -10

        // ==========================================
        // 3. SIGNED OVERFLOW / EXTREME BOUNDARY TESTS
        // ==========================================
        $display("\n--- Testing Signed Extremes & Overflow Boundaries ---");
        // Signed Max (127 = 8'h7F) vs Signed Min (-128 = 8'h80)
        run_test(8'h80,  8'h7F,  1'b1, 8'h7F);  // -128 vs 127 -> Max is 127
        run_test(8'h7F,  8'h80,  1'b1, 8'h7F);  // 127 vs -128 -> Max is 127

        // Checking values around signed minimum boundary (-128 vs -127)
        // -127 is 8'h81, -128 is 8'h80 (-127 is greater)
        run_test(8'h80,  8'h81,  1'b1, 8'h81);  // -128 vs -127 -> Max is -127
        run_test(8'h81,  8'h80,  1'b1, 8'h81);  // -127 vs -128 -> Max is -127

        // Checking values around signed maximum boundary (126 vs 127)
        run_test(8'h7E,  8'h7F,  1'b1, 8'h7F);  // 126 vs 127 -> Max is 127
        run_test(8'h7F,  8'h7E,  1'b1, 8'h7F);  // 127 vs 126 -> Max is 127

        $display("\n=== ALL TESTS COMPLETED ===");
        $finish;
    end

endmodule