`timescale 1ns/1ps
module fsm_moore (
    input  logic clk,
    input  logic rst_n,
    input  logic din,
    output logic dout
);

    // State encoding (6 states: IDLE, A, B, C, D, E, F -> 3 bits)
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        A    = 3'b001,
        B    = 3'b010,
        C    = 3'b011,
        D    = 3'b100,
        E    = 3'b101,
        F    = 3'b110
    } state_t;

    state_t current_state, next_state;

    // Sequential state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next-state logic
    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: next_state = (din == 1'b0) ? A : D;
            A:    next_state = (din == 1'b0) ? B : D;
            B:    next_state = (din == 1'b0) ? A : C;
            C:    next_state = (din == 1'b0) ? F : E;
            D:    next_state = (din == 1'b0) ? F : E;
            E:    next_state = (din == 1'b0) ? A : D;
            F:    next_state = (din == 1'b0) ? B : D;
            default: next_state = IDLE;
        endcase
    end

    // Output logic (Moore: depends ONLY on current state)
    always_comb begin
        case (current_state)
            IDLE: dout = 1'b0;
            A:    dout = 1'b0;
            B:    dout = 1'b0;
            C:    dout = 1'b1;
            D:    dout = 1'b0;
            E:    dout = 1'b0;
            F:    dout = 1'b1;
            default: dout = 1'b0;
        endcase
    end

endmodule