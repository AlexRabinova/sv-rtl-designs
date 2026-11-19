`timescale 1ns/1ps
module fsm_mealy (
    input  logic clk,
    input  logic rst_n, // Active-low asynchronous reset
    input  logic din,   // Serial bit stream input
    output logic dout   // Error output (1 = error, 0 = no error)
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        A    = 3'b001,
        B    = 3'b010,
        C    = 3'b011,
        D    = 3'b100
    } state_t;

    state_t current_state, next_state;

    // Sequential state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next-state and Output logic (Mealy: output depends on state & din)
    always_comb begin
        // Default assignments
        next_state = current_state;
        dout       = 1'b0;

        case (current_state)
            IDLE: begin
                if (din == 1'b0) begin
                    next_state = A;
                    dout       = 1'b0;
                end else begin
                    next_state = C;
                    dout       = 1'b0;
                end
            end

            A: begin
                if (din == 1'b0) begin
                    next_state = B;
                    dout       = 1'b0; // 2nd consecutive zero (Even -> Error!)
                end else begin
                    next_state = C;
                    dout       = 1'b0;
                end
            end

            B: begin
                if (din == 1'b0) begin
                    next_state = A;
                    dout       = 1'b0; // 3rd consecutive zero (Odd -> OK)
                end else begin
                    next_state = C;
                    dout       = 1'b1; // 4th consecutive zero (Even -> Error!)
                end
            end

            C: begin
                if (din == 1'b0) begin
                    next_state = A;
                    dout       = 1'b1; // 1st consecutive one (Odd -> Error!)
                end else begin
                    next_state = D;
                    dout       = 1'b0; // 2nd consecutive one (Even -> OK)
                end
            end

            D: begin // Note: If your state variable uses 3 bits or handles D separately
                // Mapping D as defined in your description
                if (din == 1'b0) begin
                    next_state = A;
                    dout       = 1'b0;
                end else begin
                    next_state = C;
                    dout       = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
                dout       = 1'b0;
            end
        endcase
    end

endmodule