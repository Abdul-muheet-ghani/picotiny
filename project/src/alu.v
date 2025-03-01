module alu(

    input             instr_sub,
    input             instr_sra,
    input             instr_srai,
    
    input             instr_beq,
    input             instr_bne, 
    input             instr_bge, 
    input             instr_bgeu,

    input is_slti_blt_slt,
	input is_sltiu_bltu_sltu,

    output reg alu_out_0,

    input             is_lui_auipc_jal_jalr_addi_add_sub,
    input             is_compare,
    input             instr_xor_i,
    input             instr_or_i,
    input             instr_and_i,

    input      [31:0] reg_op1,
    input      [31:0] reg_op2,

    output reg [31:0] alu_out
);

    reg [31:0] alu_add_sub;
	reg alu_eq, alu_ltu, alu_lts;

	always @* begin
		alu_add_sub = instr_sub ? reg_op1 - reg_op2 : reg_op1 + reg_op2;
		alu_eq = reg_op1 == reg_op2;
		alu_lts = $signed(reg_op1) < $signed(reg_op2);
		alu_ltu = reg_op1 < reg_op2;
	end

	always @* begin
		alu_out_0 = 'bx;
		(* parallel_case, full_case *)
		case (1'b1)
			instr_beq:
				alu_out_0 = alu_eq;
			instr_bne:
				alu_out_0 = !alu_eq;
			instr_bge:
				alu_out_0 = !alu_lts;
			instr_bgeu:
				alu_out_0 = !alu_ltu;
			is_slti_blt_slt:
				alu_out_0 = alu_lts;
			is_sltiu_bltu_sltu:
				alu_out_0 = alu_ltu;
		endcase

		alu_out = 'bx;
		(* parallel_case, full_case *)
		case (1'b1)
			is_lui_auipc_jal_jalr_addi_add_sub:
				alu_out = alu_add_sub;
			is_compare:
				alu_out = alu_out_0;
			instr_xor_i:
				alu_out = reg_op1 ^ reg_op2;
			instr_or_i:
				alu_out = reg_op1 | reg_op2;
			instr_and_i:
				alu_out = reg_op1 & reg_op2;
		endcase
	end

endmodule
