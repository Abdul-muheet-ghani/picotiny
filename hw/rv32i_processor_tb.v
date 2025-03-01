module tb_rv32i_processor;

    // Inputs
    reg clk;
    reg resetn;

    // Memory Interface
    wire mem_valid;
    wire mem_instr;
    wire mem_ready; // Declare as wire (driven by memory module)
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;
    wire [31:0] mem_rdata;

    // Instantiate the RV32I Processor
    picorv32 uut (
        .clk(clk),
        .resetn(resetn),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata)
    );

    // Instantiate the Memory Module
    memory mem_inst (
        .clk(clk),
        .resetn(resetn),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end

    // Testbench Logic
    initial begin
        // Initialize Inputs
        resetn = 0;
        #20;
        resetn = 1;

        // Generate VCD File for GTKWave
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_rv32i_processor);

        // Run Simulation
        #1000; // Adjust simulation time as needed
        $display("Testbench completed successfully.");
        $finish;
    end

endmodule