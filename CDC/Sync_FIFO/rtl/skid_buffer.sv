// Skid Buffer
module skid_buffer (
    input clk, rst_n,
    // Upstream (Input)
    input  i_valid,
    output o_ready,
    input  [31:0] i_data,
    // Downstream (Output)
    output o_valid,
    input  i_ready,
    output [31:0] o_data
);
    // 내부 상태: 0=Empty, 1=Busy(Normal), 2=Full(Skid Active)
    reg [1:0] state; 
    reg [31:0] main_reg, skid_reg;

    // Output Logic
    assign o_valid = (state != 0); 
    assign o_ready = (state != 2); 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
        end else begin
            case (state)
                0: if (i_valid) begin // Empty -> Load
                       main_reg <= i_data;
                       state <= 1; 
                   end
                1: begin // Normal Mode
                       if (i_ready && i_valid) main_reg <= i_data; // Pass-through
                       else if (!i_ready && i_valid) begin // Back-pressure! -> Skid
                           skid_reg <= i_data; // Save to Skid
                           state <= 2;
                       end
                       else if (i_ready && !i_valid) state <= 0; // Drain
                   end
                2: if (i_ready) begin // Full -> Output Skid
                       main_reg <= skid_reg; // Move Skid to Main
                       state <= 1;
                   end
            endcase
        end
    end
    assign o_data = main_reg;
endmodule