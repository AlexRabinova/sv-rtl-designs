module tb_apb_top;

    logic clk;
    logic rst_n;

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        rst_n = 0;
        #25;
        rst_n = 1;
    end

    // Interconnect Wires
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    // Master Command Signals
    logic        req_valid;
    logic [31:0] req_addr;
    logic [31:0] req_wdata;
    logic        req_write;
    logic        req_ready;

    // Instantiate Master
    apb_master u_master (
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_addr(req_addr),
        .req_wdata(req_wdata), .req_write(req_write),
        .req_ready(req_ready),
        .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata),
        .pready(pready), .pslverr(pslverr)
    );

    // Instantiate Slave
    apb_slave u_slave (
        .clk(clk), .rst_n(rst_n),
        .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata),
        .pready(pready), .pslverr(pslverr)
    );

    task apb_write(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        while (!req_ready) @(posedge clk);
        req_valid  = 1'b1;
        req_addr   = addr;
        req_wdata  = data;
        req_write  = 1'b1;
        @(posedge clk);
        req_valid  = 1'b0;
        @(posedge clk);
    endtask

    task apb_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        while (!req_ready) @(posedge clk);
        req_valid  = 1'b1;
        req_addr   = addr;
        req_wdata  = '0;
        req_write  = 1'b0;
        @(posedge clk);
        req_valid  = 1'b0;
        @(posedge clk);
        data = prdata;
    endtask

    initial begin
        logic [31:0] rdata;
        req_valid = 0;
        req_addr  = 0;
        req_wdata = 0;
        req_write = 0;

        @(posedge rst_n);
        repeat(2) @(posedge clk);

        $display("Starting APB Verification...");
        apb_write(32'h04, 32'hDEADBEEF);
        apb_write(32'h08, 32'hCAFE1234);

        apb_read(32'h04, rdata);
        if (rdata === 32'hDEADBEEF) $display("[PASS] 0x04 Match: 0x%08h", rdata);
        else $error("[FAIL] 0x04 Mismatch: 0x%08h", rdata);

        apb_read(32'h08, rdata);
        if (rdata === 32'hCAFE1234) $display("[PASS] 0x08 Match: 0x%08h", rdata);
        else $error("[FAIL] 0x08 Mismatch: 0x%08h", rdata);

        $display("Verification Completed.");
        $finish;
    end

    initial begin
        $dumpfile("apb_waveform.vcd");
        $dumpvars(0, tb_apb_top);
    end

endmodule