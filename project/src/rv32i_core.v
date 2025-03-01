//////////////////////////////////////////////////////////////////////////////////
// Company: MERL-UITU
// Engineer: Abdul Muheet Ghani
// 
// Design Name: RV32IMACZicsr for Linux
// Module Name: RV32I-top
// Project Name: RV32IMACZicsr for linux
// Target Devices: 
// Description: 
// 
//////////////////////////////////////////////////////////////////////////////////

module rv32i_core #(
   parameter XLEN = 32,
   parameter BOOT_ADDRESS = 32'h0000_0000
)
(
    input                     clk,
    input                     reset_n,

	 output                    mem_valid,
	 input                     mem_ready,

	 output     [XLEN-1:0]     mem_addr,
	 output     [XLEN-1:0]     mem_wdata,
	 output     [(XLEN/8)-1:0] mem_wstrb,
	 input      [XLEN-1:0]     mem_rdata
    
);

   /////////////////////////////////////////////////////////
   //ports
   /////////////////////////////////////////////////////////

   wire [14:0]     control_unit_out;
   wire [XLEN-1:0] data_in;
   wire [XLEN-1:0] fetch_address;
   wire [XLEN-1:0] OUT_T;
   wire [XLEN-1:0] addr;
   wire [XLEN-1:0] offset_adder;
   wire [XLEN-1:0] inst_out;
   wire [XLEN-1:0] I_type;
   wire [XLEN-1:0] S_type;
   wire [XLEN-1:0] SB_type;
   wire [XLEN-1:0] UJ_type;
   wire [XLEN-1:0] U_type;
   wire [XLEN-1:0] operand1;
   wire [XLEN-1:0] operand2;
   wire [XLEN-1:0] reg_1;
   wire [XLEN-1:0] reg_2;
   wire [XLEN-1:0] immediate_data;
   wire [XLEN-1:0] ALU_OUTPUT;
   wire [XLEN-1:0] write_adder;
   wire [XLEN-1:0] write_back;
   wire [8:0]      contrl_decoder;
   wire [4:0]      rd ;          //destination register
   wire            branch_true;
   wire [XLEN-1:0] csr_data_out;
   reg [XLEN-1:0]  wb,address_q,instr_q,fetch_address_q;
   wire [XLEN-1:0] instruction_fetch;
   wire [XLEN-1:0] read_data;
   reg [1:0]       pc_sel=0;

   wire            external_int_in;
   wire            software_int_in;
   wire            timer_int_in;

   wire            illegal_instruction_in;
   wire            ecall_in;
   wire            ebreak_in;
   wire            mret_in;

   wire [31:0]     return_address;
   wire [31:0]     trap_address;
   wire [31:0]     PC;
   wire            trap_true;
   wire            return_trap;
   wire            fetch_valid;
   wire            fetch_ready;
   wire            mem_instr_resp;
   wire            mem_data_rd_resp;

   /////////////////////////////////////////////////////////
   //procedural assignment
   /////////////////////////////////////////////////////////

   // assign offset_adder = (we) ? 0 : address_q + 4; 
   // assign addr = (pc_sel == 2'b00) ? offset_adder :
   //               (pc_sel == 2'b01) ? UJ_type :
   //               (pc_sel == 2'b10) ? OUT_T :
   //               (pc_sel == 2'b11) ? I_type + reg_1 : 0;

   // assign PC   = (trap_true) ? trap_address : (return_trap)
   //                           ? return_address : addr;

   // output of control unit 10:9 is for operand a selection
    assign reg_1 = operand1;
   //assign reg_1 = (control_unit_out[10:9] == 2'b00) ? operand1 :
   //               (control_unit_out[10:9] == 2'b01) ? offset_adder :
   //               (control_unit_out[10:9] == 2'b10) ? OUT_T :
   //               (control_unit_out[10:9] == 2'b11) ? 32'b0 : 0;

   // output of control unit [1:0] is for immediate select
   assign immediate_data = (control_unit_out[1:0] == 2'b00) ? 32'b0 :
                      (control_unit_out[1:0] == 2'b01) ? U_type :
                      (control_unit_out[1:0] == 2'b10) ? I_type :
                      (control_unit_out[1:0] == 2'b11) ? S_type : 0;
               
   // Output of control unit bit 8 presents operand b selection 
   // either be it immediate or reg2            
   assign reg_2 = (control_unit_out[8]) ? immediate_data : operand2;

   // Output of control unit control_unit_out[12] present mem_write enable
   // Output of control unit control_unit_out[13] present mem_to_reg enable
   assign write_back = (control_unit_out[12]) ? 32'b0 : 
                       (control_unit_out[13]) ? write_adder : ALU_OUTPUT;

   //assign OUT_T = (branch_p) ? SB_type : offset_adder;

   // 11:7 destination register
   assign rd = contrl_decoder[3] ? 5'b00001 : instr_q[11:7];

   /////////////////////////////////////////////////////////
   //Module Instantiation
   /////////////////////////////////////////////////////////

   rv32i_fetch fetch_i(
      .clk_in          (clk),
      .reset_n         (reset_n),

      .branch_true     (branch_true),
      .pc_sel          (pc_sel),

      .UJ_immediate_in (UJ_type),
      .SB_immediate_in (SB_type),
      .I_immediate_in  (I_type),
      .rs1_in          (reg_1),

      .fetch_ready_o   (fetch_ready),
      .fetch_valid_o   (fetch_valid),
      .fetch_address_o (fetch_address)
   );

   //Address of instruction_mem from 2 to 13 because of offset = 4
  /* ram instruction_mem(.clk_in          (clk),
                       .address_in      (mem_addr[13:2]),
                       .data_in         (data_in),
                       .instruction_out (instruction_fetch),
                       .we_in           (we)
                     ); */

   control i_control_decoder(.opcode_in      (instr_q),
                             .illegal_ins_out(illegal_instruction_in),
                             .ecall_out      (ecall_in),
                             .ebreak_out     (ebreak_in),
                             .mret_out       (mret_in),
                             .decoded_out    (contrl_decoder)
                           );

   unit i_control_unit(.type_decode_in (contrl_decoder),
                     .function_3_in    (instr_q[14:12]),
                     .function_7_in    (instr_q[30]),
                     .control_unit_out (control_unit_out)
                     );

   // Output of control unit 5:2 is ALU operand for selecting operation (i.e +,-,or,xor etc)
   ALU i_ALU(.alu_operand_in(control_unit_out[5:2]),
           .operand1_in   (reg_1),
           .operand2_in   (reg_2),
           .alu_result_out(ALU_OUTPUT)
           );

   // 14:12 function 3
   // Ouput of control unit bit 11 presents branch enable
   branch i_branch(.operand1_in     (reg_1),
                 .operand2_in     (reg_2),
                 .function_3_in   (instr_q[14:12]),
                 .branch_en_in    (control_unit_out[11]),
                 .branch_taken_out(branch_true)
                 );

   // Output of control unit control_unit_out[12] present mem_write enable
   // output of control unit control_unit_out[13] present mem_to_reg enable
   /*data_mem i_data_mem(.clk_in        (clk),
                     .address_in    (mem_addr),
                     .store_data_in (mem_wdata),
                     .store_en_in   (mem_valid & (&mem_wstrb)),
                     .load_en_in    (mem_valid & !(&mem_wstrb)),
                     .data_out      (read_data)
                     );*/

   //assign mem_rdata = mem_instr ? instruction_fetch : read_data;

   native_intf_arb i_arb (
     .mem_instr_valid   (fetch_valid   ),
     .mem_instr_ready   (fetch_ready   ),
     .mem_instr_addr    (fetch_address ),
     .mem_instr_data    (inst_out      ),
     .mem_instr_resp    (mem_instr_resp),

     .mem_data_wr_valid (control_unit_out[12]), // store_en_in
     .mem_data_wr_addr  (ALU_OUTPUT          ), // ALU_OUTPUT
     .mem_data_wr_data  (operand2            ), // store_data_in
     .mem_data_wr_ready (),                     // high priority
     .mem_data_wr_resp  (),

     .mem_data_rd_valid (control_unit_out[13]), //load_en_in
     .mem_data_rd_addr  (ALU_OUTPUT          ), // address_in
     .mem_data_rd_ready (),                     // high priority
     .mem_data_resp     (write_adder         ),
     .mem_data_rd_resp  (mem_data_rd_resp    ),

     .mem_instr_valid_o  (mem_valid           ),
     .mem_instr_o        (mem_instr           ),
     .mem_instr_ready_o  (mem_ready           ),
     .mem_data_addr_o    (mem_addr            ),   
     .mem_data_wr_data_o (mem_wdata           ),   
     .mem_data_rd_data_i (mem_rdata           ),
     .mem_data_wr_strb_o (mem_wstrb           )   
   );

   always @(posedge clk, negedge reset_n) begin
      if(!reset_n)begin
         instr_q <= 0;
         fetch_address_q <= 0;
      end
      else begin
         if(mem_instr) begin
            instr_q <= inst_out;
            fetch_address_q <= fetch_address;
         end
         else begin
            instr_q <= 0;
            fetch_address_q <= 0;
         end
      end
   end

   // 19:15 rs1 address
   // 24:20 rs2 address
   reg_file i_reg_file(.clk_in               (clk),
                     .reset_in               (reset_n),
                     .rs1_address_in         (instr_q[19:15]),
                     .rs2_address_in         (instr_q[24:20]),
                     .destination_register_in(rd),
                     .input_data_in          (wb),
                     .rs1_data_out           (operand1),
                     .rs2_data_out           (operand2)
                     );

   immediate i_immediate(.instruction_in    (instr_q),
                       .pc_in             (fetch_address_q),
                       .I_type_imm_out    (I_type),
                       .S_type_imm_out    (S_type),
                       .SB_type_imm_out   (SB_type),
                       .UJ_type_imm_out   (UJ_type),
                       .U_type_imm_out    (U_type)
                       );

   /////////////////////////////////////////////////////////
   //always block
   /////////////////////////////////////////////////////////

   always @(posedge clk) begin
      if(!reset_n)
      begin
         address_q = 32'b0;
      end
      else begin
         address_q = PC;
      end
   end

   always @* begin
      pc_sel = control_unit_out[7:6];

      // bit 3 is for jump
      if (contrl_decoder[3]) begin
         wb = address_q + 4;
      end else begin
         wb = write_back;
      end
   end 

endmodule