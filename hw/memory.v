module memory (
    input clk,
    input resetn,

    // Processor Interface
    input mem_valid,
    input mem_instr,
    output reg mem_ready,
    input [31:0] mem_addr,
    input [31:0] mem_wdata,
    input [3:0] mem_wstrb,
    output reg [31:0] mem_rdata
);

    // Memory Array (64KB)
    reg [31:0] mem [0:16383]; // 16KB memory (64KB / 4 bytes per word)

    // Internal Signals
    reg [31:0] addr_reg;
    reg [31:0] wdata_reg;
    reg [3:0] wstrb_reg;
    reg valid_reg;

    // Memory Initialization
    initial begin
        $readmemh("program.hex", mem); // Load program from hex file
    end

    // Memory Read/Write Logic
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            mem_ready <= 0;
            mem_rdata <= 32'h00000000;
        end else begin
            if (mem_valid && !mem_ready) begin
                // Capture address and data
                addr_reg <= mem_addr;
                wdata_reg <= mem_wdata;
                wstrb_reg <= mem_wstrb;
                valid_reg <= 1;

                // Memory Read
                if (!mem_wstrb) begin
                    mem_rdata <= mem[mem_addr[15:2]]; // Word-aligned address
                end
                // Memory Write
                else begin
                    if (wstrb_reg[0]) mem[addr_reg[15:2]][7:0] <= wdata_reg[7:0];
                    if (wstrb_reg[1]) mem[addr_reg[15:2]][15:8] <= wdata_reg[15:8];
                    if (wstrb_reg[2]) mem[addr_reg[15:2]][23:16] <= wdata_reg[23:16];
                    if (wstrb_reg[3]) mem[addr_reg[15:2]][31:24] <= wdata_reg[31:24];
                end

                mem_ready <= 1;
            end else begin
                mem_ready <= 0;
                valid_reg <= 0;
            end
        end
    end

endmodule