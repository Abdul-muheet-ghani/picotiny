//////////////////////////////////////////////////////////////////////////////////
// Company: MERL-UITU
// Engineer: Abdul Muheet Ghani
// 
// Design Name: RV32IMACZicsr for Linux
// Module Name: type decoder
// Project Name: RV32IMACZicsr for linux
// Target Devices: 
// Description: 
// 
//////////////////////////////////////////////////////////////////////////////////


module control (
   input      [31:0] opcode_in,

   output reg        illegal_ins_out,
   output reg        ecall_out,
   output reg        ebreak_out,
   output reg        mret_out,
   output reg [8:0] decoded_out
 );

   /////////////////////////////////////////////////////////
   //always block
   /////////////////////////////////////////////////////////

   always @* begin
      case (opcode_in[6:0])
         `OPCODE_RTYPE  : decoded_out = 9'b100000000;
         `OPCODE_ITYPE  : decoded_out = 9'b010000000;
         `OPCODE_LOAD   : decoded_out = 9'b001000000;
         `OPCODE_STORE  : decoded_out = 9'b000100000;
         `OPCODE_BRANCH : decoded_out = 9'b000010000;
         `OPCODE_JAL    : decoded_out = 9'b000001000;
         `OPCODE_JALR   : decoded_out = 9'b000000100;
         `OPCODE_LUI    : decoded_out = 9'b000000010;
         `OPCODE_AUIPC  : decoded_out = 9'b000000001;
         default: decoded_out = 9'b0;
      endcase
   end

   always @* begin
      ecall_out  = (opcode_in == `OPCODE_SYSTEM) && (opcode_in[14:12] == 0) && (opcode_in[21:20] == 2'b00);
      ebreak_out = (opcode_in == `OPCODE_SYSTEM) && (opcode_in[14:12] == 0) && (opcode_in[21:20] == 2'b01);
      mret_out   = (opcode_in == `OPCODE_SYSTEM) && (opcode_in[14:12] == 0) && (opcode_in[21:20] == 2'b10);
   end

endmodule
