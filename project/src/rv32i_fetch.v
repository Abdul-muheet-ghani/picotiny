module rv32i_fetch
#(
    parameter XLEN = 32
)
(   
    input             clk_in,
    input             reset_n,

    input             branch_true,
    input  [1:0]      pc_sel,

    input  [XLEN-1:0] UJ_immediate_in,
    input  [XLEN-1:0] SB_immediate_in,
    input  [XLEN-1:0] I_immediate_in,
    input  [XLEN-1:0] rs1_in,

    input             fetch_ready_o,
    output reg        fetch_valid_o,
    output [XLEN-1:0] fetch_address_o
);

    reg  [XLEN-1:0] pcplus4,fetch_address;

    assign fetch_address_o = fetch_address;

    always @(posedge clk_in, negedge reset_n)
    begin
        if (!reset_n)
        begin
            pcplus4 <= 0;
        end
        else if (fetch_ready_o)
        begin
            pcplus4 <= fetch_address + 4;
        end
        else begin
            pcplus4 <= pcplus4;
        end
    end

    always @(*)
    begin
        case (pc_sel)
            2'b00: fetch_address = pcplus4;
            2'b01: fetch_address = UJ_immediate_in;
            2'b10: fetch_address = SB_immediate_in;
            2'b11: fetch_address = I_immediate_in + rs1_in;
            default: fetch_address = 0;
        endcase
    end

    always @(*) begin
        fetch_valid_o = reset_n;
    end

endmodule