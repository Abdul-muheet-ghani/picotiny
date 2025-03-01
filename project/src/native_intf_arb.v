module native_intf_arb #(
    parameter XLEN = 32,
    parameter BOOT_ADDRESS = 32'h8000_0000
)(
    input                 mem_instr_valid,
    output reg            mem_instr_ready,
    input      [XLEN-1:0] mem_instr_addr,
    output reg [XLEN-1:0] mem_instr_data,   
    output reg            mem_instr_resp, // Response for instruction fetch

    input                 mem_data_wr_valid,
    output reg            mem_data_wr_ready,
    input      [XLEN-1:0] mem_data_wr_addr,
    input      [XLEN-1:0] mem_data_wr_data,
    output reg            mem_data_wr_resp, // Response for write transactions

    input                 mem_data_rd_valid,
    output reg            mem_data_rd_ready,
    input      [XLEN-1:0] mem_data_rd_addr,
    output reg [XLEN-1:0] mem_data_resp, // Response data for reads
    output reg            mem_data_rd_resp, // Response for read transactions

    output reg            mem_instr_valid_o,
    output reg            mem_instr_o,
    input                 mem_instr_ready_o, 
    output     [XLEN-1:0] mem_data_addr_o,
    output reg [XLEN-1:0] mem_data_wr_data_o,
    input      [XLEN-1:0] mem_data_rd_data_i,
    output reg [(XLEN/8)-1:0] mem_data_wr_strb_o
);

    reg [XLEN-1:0] mem_data_addr;
    assign mem_data_addr_o = mem_data_addr | BOOT_ADDRESS;

    always @(*) begin
        // Default values (no request is active)
        mem_instr_ready    = 1'b0;
        mem_data_wr_ready  = 1'b0;
        mem_data_rd_ready  = 1'b0;
        mem_instr_o        = 1'b0;

        mem_instr_valid_o  = 1'b0;
        mem_instr_resp     = 1'b0;

        mem_data_addr    = {XLEN{1'b0}};
        mem_data_wr_data_o = {XLEN{1'b0}};
        mem_instr_data     = {XLEN{1'b0}};
        mem_data_wr_strb_o = {XLEN/8{1'b0}};

        mem_data_resp      = {XLEN{1'b0}};
        mem_data_rd_resp   = 1'b0;
        mem_data_wr_resp   = 1'b0;

        // Priority Arbitration
        if (mem_data_wr_valid) begin
            // Data Write has the highest priority
            mem_data_wr_ready  = 1'b1;
            mem_data_addr    = mem_data_wr_addr;
            mem_data_wr_data_o = mem_data_wr_data;
            mem_data_wr_strb_o = {XLEN/8{1'b1}}; // All bits high for a full write
            mem_data_wr_resp   = 1'b1; // Indicate successful write transaction

        end else if (mem_data_rd_valid) begin
            // Data Read has second priority
            mem_data_rd_ready = 1'b1;
            mem_data_addr   = mem_data_rd_addr;
            mem_data_resp     = mem_data_rd_data_i; // Pass read data
            mem_data_rd_resp  = 1'b1; // Indicate successful read transaction

        end else if (mem_instr_valid) begin
            // Instruction Fetch has the lowest priority
            mem_instr_valid_o = 1'b1;
            mem_data_addr   = mem_instr_addr;
            if (mem_instr_ready_o) begin
                mem_instr_ready   = 1'b1;
                //mem_instr_valid_o = 1'b1;
                mem_instr_o       = 1'b1;
                //mem_data_addr   = mem_instr_addr;
                mem_instr_data    = mem_data_rd_data_i; // Fetch instruction data
                mem_instr_resp    = 1'b1; // Indicate successful fetch
            end
        end
    end

endmodule
