module fixed_priority_arbiter (
    input  logic [3:0] req,    // 4-bit Request vector
    output logic [3:0] grant,  // One-hot grant vector
    output logic       valid   // High if any grant is active
);

    always @(*) begin
        grant = 4'b0000;
        valid = 1'b0;

        if (req[0]) begin
            grant[0] = 1'b1;
            valid    = 1'b1;
        end else if (req[1]) begin
            grant[1] = 1'b1;
            valid    = 1'b1;
        end else if (req[2]) begin
            grant[2] = 1'b1;
            valid    = 1'b1;
        end else if (req[3]) begin
            grant[3] = 1'b1;
            valid    = 1'b1;
        end
    end

endmodule