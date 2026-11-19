`timescale 1ns/1ps

module tb_fsm;

    // Testbench signals
    logic clk;
    logic rst_n;
    logic din;
    
    logic dout_mealy;
    logic dout_moore;

    // Instantiate Mealy FSM
    fsm_mealy uut_mealy (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .dout(dout_mealy)
    );

    // Instantiate Moore FSM
    fsm_moore uut_moore (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .dout(dout_moore)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // Stimulus pattern from assignment image: Input = 00011111000001
    logic [14:0] test_input   = 15'b00011111000001; 
    logic [14:0] expected_out = 15'b00010000100000; //[cite: 1]

    initial begin
        // Initialize signals
        clk   = 0;
        rst_n = 0;
        din   = 0;

        // Apply reset
        #12;
        rst_n = 1;

        // Feed input vector bit by bit synchronously
        for (int i = 14; i >= 0; i--) begin
            din = test_input[i];
            @(posedge clk);
            #1; // Small delay after clock edge to sample stable values
            
            $display("Time=%0t ns | Input din=%b | Mealy [State: %-5s | dout: %b] | Moore [State: %-5s | dout: %b] | Expected=%b", 
                     $time, 
                     din, 
                     uut_mealy.current_state.name(), 
                     dout_mealy, 
                     uut_moore.current_state.name(), 
                     dout_moore, 
                     expected_out[i]);
        end

        #20;
        $display("Simulation finished successfully.");
        $finish;
    end

    initial begin
        // --- VCD Waveform Generation Block ---
        $dumpfile("fsm_waveforms.vcd"); // Name of the generated VCD file
        $dumpvars(0, tb_fsm);           // Dump all signals starting from the tb_fsm module down
    end

endmodule