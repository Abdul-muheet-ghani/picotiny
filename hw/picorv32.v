/*
 *  PicoRV32 -- A Small RISC-V (RV32I) Processor Core
 *
 *  Copyright (C) 2015  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

/* verilator lint_off WIDTH */
/* verilator lint_off PINMISSING */
/* verilator lint_off CASEOVERLAP */
/* verilator lint_off CASEINCOMPLETE */

`timescale 1 ns / 1 ps

module picorv32 #(
	parameter [31:0] PROGADDR_RESET = 32'h 0000_0000
) (
	input clk, resetn,
	
	output reg        mem_valid,
	output reg        mem_instr,
	input             mem_ready,

	output reg [31:0] mem_addr,
	output reg [31:0] mem_wdata,
	output reg [ 3:0] mem_wstrb,
	input      [31:0] mem_rdata,

	// Look-Ahead Interface
	output            mem_la_read,
	output            mem_la_write,
	output     [31:0] mem_la_addr,
	output reg [31:0] mem_la_wdata,
	output reg [ 3:0] mem_la_wstrb

);
	localparam integer regfile_size = 32;
	localparam integer regindex_bits = 5;

	reg [31:0] count_cycle, count_instr;
	reg [31:0] reg_pc, reg_next_pc, reg_op1, reg_op2, reg_out;
	reg [4:0] reg_sh;

	wire [31:0] next_pc;
	reg [31:0] cpuregs [0:regfile_size-1];

	// Memory Interface

	reg [1:0] mem_state;
	reg [1:0] mem_wordsize;
	reg [31:0] mem_rdata_word;
	wire [31:0] mem_rdata_q;
	reg mem_do_prefetch;
	reg mem_do_rinst;
	reg mem_do_rdata;
	reg mem_do_wdata;

	wire mem_xfer;
	assign mem_xfer = (mem_valid && mem_ready);

	wire mem_done = resetn && ((mem_xfer && |mem_state && (mem_do_rinst || mem_do_rdata || mem_do_wdata)) || (&mem_state && mem_do_rinst));

	assign mem_la_write = resetn && !mem_state && mem_do_wdata;
	assign mem_la_read = resetn && ((!mem_state && (mem_do_rinst || mem_do_prefetch || mem_do_rdata)));
	assign mem_la_addr = (mem_do_prefetch || mem_do_rinst) ? {next_pc[31:2], 2'b00} : {reg_op1[31:2], 2'b00};

	always @* begin
		(* full_case *)
		case (mem_wordsize)
			0: begin
				mem_la_wdata = reg_op2;
				mem_la_wstrb = 4'b1111;
				mem_rdata_word = mem_rdata;
			end
			1: begin
				mem_la_wdata = {2{reg_op2[15:0]}};
				mem_la_wstrb = reg_op1[1] ? 4'b1100 : 4'b0011;
				case (reg_op1[1])
					1'b0: mem_rdata_word = {16'b0, mem_rdata[15: 0]};
					1'b1: mem_rdata_word = {16'b0, mem_rdata[31:16]};
				endcase
			end
			2: begin
				mem_la_wdata = {4{reg_op2[7:0]}};
				mem_la_wstrb = 4'b0001 << reg_op1[1:0];
				case (reg_op1[1:0])
					2'b00: mem_rdata_word = {24'b0, mem_rdata[ 7: 0]};
					2'b01: mem_rdata_word = {24'b0, mem_rdata[15: 8]};
					2'b10: mem_rdata_word = {24'b0, mem_rdata[23:16]};
					2'b11: mem_rdata_word = {24'b0, mem_rdata[31:24]};
				endcase
			end
		endcase
	end

	decoder i_decoder(
		.clk 			(clk),
		.resetn			(resetn		),
		.mem_xfer   	(mem_xfer),

		.mem_do_rinst	(mem_do_rinst),
		.mem_done		(mem_done),

		.decoder_trigger (decoder_trigger),
		.decoder_pseudo_trigger (decoder_pseudo_trigger),

		.instr_lui						(instr_lui),
		.instr_auipc					(instr_auipc),
		.instr_jal						(instr_jal),
		.instr_jalr						(instr_jalr),
		.is_beq_bne_blt_bge_bltu_bgeu	(is_beq_bne_blt_bge_bltu_bgeu),
		.is_lb_lh_lw_lbu_lhu			(is_lb_lh_lw_lbu_lhu),
		.is_sb_sh_sw					(is_sb_sh_sw),
		.is_alu_reg_imm					(is_alu_reg_imm),
		.is_alu_reg_reg					(is_alu_reg_reg),

		.instr_beq						(instr_beq),
		.instr_bne						(instr_bne),
		.instr_blt						(instr_blt),
		.instr_bge						(instr_bge),
		.instr_bltu						(instr_bltu),
		.instr_bgeu						(instr_bgeu),

		.instr_lb						(instr_lb),
		.instr_lh						(instr_lh),
		.instr_lw						(instr_lw),
		.instr_lbu						(instr_lbu),
		.instr_lhu						(instr_lhu),

		.instr_sb						(instr_sb),
		.instr_sh						(instr_sh),
		.instr_sw						(instr_sw),

		.instr_addi						(instr_addi),
		.instr_slti						(instr_slti),
		.instr_sltiu						(instr_sltiu),
		.instr_xori						(instr_xori),
		.instr_ori						(instr_ori),
		.instr_andi						(instr_andi),

		.instr_slli						(instr_slli),
		.instr_srli						(instr_srli),
		.instr_srai						(instr_srai),

		.instr_add						(instr_add),
		.instr_sub						(instr_sub),
		.instr_sll						(instr_sll),
		.instr_slt						(instr_slt),
		.instr_sltu						(instr_sltu),
		.instr_xor						(instr_xor),
		.instr_srl						(instr_srl),
		.instr_sra						(instr_sra),
		.instr_or						(instr_or),
		.instr_and						(instr_and),

		.instr_rdcycle					(instr_rdcycle),
		.instr_rdinstr					(instr_rdinstr),

		.is_slli_srli_srai				(is_slli_srli_srai),
		.is_jalr_addi_slti_sltiu_xori_ori_andi	(is_jalr_addi_slti_sltiu_xori_ori_andi),
		.is_sll_srl_sra					(is_sll_srl_sra),

		.decoded_rd						(decoded_rd),
		.decoded_rs1					(decoded_rs1),
		.decoded_rs2					(decoded_rs2),

		.decoded_imm_j					(decoded_imm_j),

		.mem_rdata 						(mem_rdata),
		.mem_rdata_q 					(mem_rdata_q)
	);

	always @(posedge clk) begin
		if (!resetn) begin
			mem_state <= 0;
			if (!resetn || mem_ready)
				mem_valid <= 0;
		end else begin
			if (mem_la_read || mem_la_write) begin
				mem_addr <= mem_la_addr;
				mem_wstrb <= mem_la_wstrb & {4{mem_la_write}};
			end
			if (mem_la_write) begin
				mem_wdata <= mem_la_wdata;
			end
			case (mem_state)
				0: begin
					if (mem_do_prefetch || mem_do_rinst || mem_do_rdata) begin
						mem_valid <= 1'b1;
						mem_instr <= mem_do_prefetch || mem_do_rinst;
						mem_wstrb <= 0;
						mem_state <= 1;
					end
					if (mem_do_wdata) begin
						mem_valid <= 1;
						mem_instr <= 0;
						mem_state <= 2;
					end
				end
				1: begin
					if (mem_xfer) begin
						mem_valid <= 0;
						mem_state <= mem_do_rinst || mem_do_rdata ? 0 : 3;
					end
				end
				2: begin
					if (mem_xfer) begin
						mem_valid <= 0;
						mem_state <= 0;
					end
				end
				3: begin
					if (mem_do_rinst) begin
						mem_state <= 0;
					end
				end
			endcase
		end
	end


	// Instruction Decoder

	wire instr_lui, instr_auipc, instr_jal, instr_jalr;
	wire instr_beq, instr_bne, instr_blt, instr_bge, instr_bltu, instr_bgeu;
	wire instr_lb, instr_lh, instr_lw, instr_lbu, instr_lhu, instr_sb, instr_sh, instr_sw;
	wire instr_addi, instr_slti, instr_sltiu, instr_xori, instr_ori, instr_andi, instr_slli, instr_srli, instr_srai;
	wire instr_add, instr_sub, instr_sll, instr_slt, instr_sltu, instr_xor, instr_srl, instr_sra, instr_or, instr_and;
	wire instr_rdcycle, instr_rdinstr;
	wire instr_trap;

	wire [regindex_bits-1:0] decoded_rd, decoded_rs1, decoded_rs2;
	wire [31:0] decoded_imm_j;
	reg [31:0] decoded_imm;
	reg decoder_trigger;
	reg decoder_pseudo_trigger;

	reg is_lui_auipc_jal;
	wire is_lb_lh_lw_lbu_lhu;
	wire is_slli_srli_srai;
	wire is_jalr_addi_slti_sltiu_xori_ori_andi;
	wire is_sb_sh_sw;
	wire is_sll_srl_sra;
	reg is_lui_auipc_jal_jalr_addi_add_sub;
	reg is_slti_blt_slt;
	reg is_sltiu_bltu_sltu;
	wire is_beq_bne_blt_bge_bltu_bgeu;
	reg is_lbu_lhu_lw;
	wire is_alu_reg_imm;
	wire is_alu_reg_reg;
	reg is_compare;

	assign instr_trap = !{instr_lui, instr_auipc, instr_jal, instr_jalr,
			instr_beq, instr_bne, instr_blt, instr_bge, instr_bltu, instr_bgeu,
			instr_lb, instr_lh, instr_lw, instr_lbu, instr_lhu, instr_sb, instr_sh, instr_sw,
			instr_addi, instr_slti, instr_sltiu, instr_xori, instr_ori, instr_andi, instr_slli, instr_srli, instr_srai,
			instr_add, instr_sub, instr_sll, instr_slt, instr_sltu, instr_xor, instr_srl, instr_sra, instr_or, instr_and,
			instr_rdcycle, instr_rdinstr};

	wire is_rdcycle_rdcycleh_rdinstr_rdinstrh;
	assign is_rdcycle_rdcycleh_rdinstr_rdinstrh = |{instr_rdcycle, instr_rdinstr};

	wire launch_next_insn;

	always @(posedge clk) begin
		is_lui_auipc_jal <= |{instr_lui, instr_auipc, instr_jal};
		is_lui_auipc_jal_jalr_addi_add_sub <= |{instr_lui, instr_auipc, instr_jal, instr_jalr, instr_addi, instr_add, instr_sub};
		is_slti_blt_slt <= |{instr_slti, instr_blt, instr_slt};
		is_sltiu_bltu_sltu <= |{instr_sltiu, instr_bltu, instr_sltu};
		is_lbu_lhu_lw <= |{instr_lbu, instr_lhu, instr_lw};
		is_compare <= |{is_beq_bne_blt_bge_bltu_bgeu, instr_slti, instr_slt, instr_sltiu, instr_sltu};

		if (decoder_trigger && !decoder_pseudo_trigger) begin
			is_lui_auipc_jal_jalr_addi_add_sub <= 0;
			is_compare <= 0;

			(* parallel_case *)
			case (1'b1)
				instr_jal:
					decoded_imm <= decoded_imm_j;
				|{instr_lui, instr_auipc}:
					decoded_imm <= mem_rdata_q[31:12] << 12;
				|{instr_jalr, is_lb_lh_lw_lbu_lhu, is_alu_reg_imm}:
					decoded_imm <= $signed(mem_rdata_q[31:20]);
				is_beq_bne_blt_bge_bltu_bgeu:
					decoded_imm <= $signed({mem_rdata_q[31], mem_rdata_q[7], mem_rdata_q[30:25], mem_rdata_q[11:8], 1'b0});
				is_sb_sh_sw:
					decoded_imm <= $signed({mem_rdata_q[31:25], mem_rdata_q[11:7]});
				default:
					decoded_imm <= 1'bx;
			endcase
		end

		if (!resetn) begin
			is_compare <= 0;
		end
	end


	// Main State Machine

	localparam cpu_state_trap   = 8'b10000000;
	localparam cpu_state_fetch  = 8'b01000000;
	localparam cpu_state_ld_rs1 = 8'b00100000;
	localparam cpu_state_ld_rs2 = 8'b00010000;
	localparam cpu_state_exec   = 8'b00001000;
	localparam cpu_state_shift  = 8'b00000100;
	localparam cpu_state_stmem  = 8'b00000010;
	localparam cpu_state_ldmem  = 8'b00000001;

	reg [7:0] cpu_state;
	reg set_mem_do_rinst;
	reg set_mem_do_rdata;
	reg set_mem_do_wdata;

	reg latched_store;
	reg latched_stalu;
	reg latched_branch;
	reg latched_trace;
	reg latched_is_lu;
	reg latched_is_lh;
	reg latched_is_lb;
	reg [regindex_bits-1:0] latched_rd;

	reg [31:0] current_pc;
	assign next_pc = latched_store && latched_branch ? reg_out & ~1 : reg_next_pc;

	wire [31:0] alu_out;
	reg  [31:0] alu_out_q;
	wire 		alu_out_0; 
	reg  		alu_out_0_q;

	alu i_alu (
		.instr_sub	(instr_sub	),
		.instr_sra	(instr_sra	),
		.instr_srai	(instr_srai	),

		.instr_beq	(instr_beq	),
		.instr_bne	(instr_bne	),
		.instr_bge	(instr_bge	),
		.instr_bgeu	(instr_bgeu	),

		.is_slti_blt_slt	(is_slti_blt_slt	),
		.is_sltiu_bltu_sltu	(is_sltiu_bltu_sltu	),

		.alu_out_0	(alu_out_0),

		.is_lui_auipc_jal_jalr_addi_add_sub	(is_lui_auipc_jal_jalr_addi_add_sub),
		.is_compare		(is_compare				),
		.instr_xor_i	(instr_xori || instr_xor),
		.instr_or_i		(instr_ori  || instr_or ),
		.instr_and_i	(instr_andi || instr_and),

		.reg_op1		(reg_op1	),
		.reg_op2		(reg_op2	),

		.alu_out		(alu_out)
	);

	// write back
	reg cpuregs_write;
	reg [31:0] cpuregs_wrdata;
	reg [31:0] cpuregs_rs1;
	reg [31:0] cpuregs_rs2;

	always @* begin
		cpuregs_write = 0;
		cpuregs_wrdata = 'bx;

		if (cpu_state == cpu_state_fetch) begin
			(* parallel_case *)
			case (1'b1)
				latched_branch: begin
					cpuregs_wrdata = reg_pc + 4;
					cpuregs_write = 1;
				end
				latched_store && !latched_branch: begin
					cpuregs_wrdata = latched_stalu ? alu_out_q : reg_out;
					cpuregs_write = 1;
				end
			endcase
		end
	end

	always @(posedge clk) begin
		if (resetn && cpuregs_write && latched_rd)
			cpuregs[latched_rd] <= cpuregs_wrdata;
	end

	always @* begin
			cpuregs_rs1 = decoded_rs1 ? cpuregs[decoded_rs1] : 0;
			cpuregs_rs2 = decoded_rs2 ? cpuregs[decoded_rs2] : 0;
	end

	assign launch_next_insn = cpu_state == cpu_state_fetch && decoder_trigger;

	always @(posedge clk) begin
		reg_sh <= 'bx;
		reg_out <= 'bx;
		set_mem_do_rinst = 0;
		set_mem_do_rdata = 0;
		set_mem_do_wdata = 0;

		alu_out_0_q <= alu_out_0;
		alu_out_q <= alu_out;

		count_cycle <= resetn ? count_cycle + 1 : 0;


		decoder_trigger <= mem_do_rinst && mem_done;
		decoder_pseudo_trigger <= 0;

		if (!resetn) begin
			reg_pc <= PROGADDR_RESET;
			reg_next_pc <= PROGADDR_RESET;
			count_instr <= 0;
			latched_store <= 0;
			latched_stalu <= 0;
			latched_branch <= 0;
			latched_trace <= 0;
			latched_is_lu <= 0;
			latched_is_lh <= 0;
			latched_is_lb <= 0;
			cpu_state <= cpu_state_fetch;
		end else
		(* parallel_case, full_case *)
		case (cpu_state)
			cpu_state_fetch: begin
				mem_do_rinst <= !decoder_trigger;
				mem_wordsize <= 0;

				current_pc = reg_next_pc;

				(* parallel_case *)
				case (1'b1)
					latched_branch: begin
						current_pc = latched_store ? (latched_stalu ? alu_out_q : reg_out) & ~1 : reg_next_pc;
					end
					latched_store && !latched_branch: begin
					end
				endcase

				reg_pc <= current_pc;
				reg_next_pc <= current_pc;

				latched_store <= 0;
				latched_stalu <= 0;
				latched_branch <= 0;
				latched_is_lu <= 0;
				latched_is_lh <= 0;
				latched_is_lb <= 0;
				latched_rd <= decoded_rd;

				if (decoder_trigger) begin
					reg_next_pc <= current_pc + 4;
					count_instr <= count_instr + 1;
					if (instr_jal) begin
						mem_do_rinst <= 1;
						reg_next_pc <= current_pc + decoded_imm_j;
						latched_branch <= 1;
					end else begin
						mem_do_rinst <= 0;
						mem_do_prefetch <= !instr_jalr;
						cpu_state <= cpu_state_ld_rs1;
					end
				end
			end

			cpu_state_ld_rs1: begin
				reg_op1 <= 'bx;
				reg_op2 <= 'bx;

				(* parallel_case *)
				case (1'b1)
					instr_trap: begin
						cpu_state <= cpu_state_trap;
					end
					is_rdcycle_rdcycleh_rdinstr_rdinstrh: begin
						(* parallel_case, full_case *)
						case (1'b1)
							instr_rdcycle:
								reg_out <= count_cycle[31:0];
							instr_rdinstr:
								reg_out <= count_instr[31:0];
						endcase
						latched_store <= 1;
						cpu_state <= cpu_state_fetch;
					end
					is_lui_auipc_jal: begin
						reg_op1 <= instr_lui ? 0 : reg_pc;
						reg_op2 <= decoded_imm;
						mem_do_rinst <= mem_do_prefetch;
						cpu_state <= cpu_state_exec;
					end
					is_lb_lh_lw_lbu_lhu && !instr_trap: begin
						reg_op1 <= cpuregs_rs1;
						cpu_state <= cpu_state_ldmem;
						mem_do_rinst <= 1;
					end
					is_slli_srli_srai: begin
						reg_op1 <= cpuregs_rs1;
						reg_sh <= decoded_rs2;
						cpu_state <= cpu_state_shift;
					end
					is_jalr_addi_slti_sltiu_xori_ori_andi: begin
						reg_op1 <= cpuregs_rs1;
						reg_op2 <= decoded_imm;
						mem_do_rinst <= mem_do_prefetch;
						cpu_state <= cpu_state_exec;
					end
					default: begin
						reg_op1 <= cpuregs_rs1;
						reg_sh <= cpuregs_rs2;
						reg_op2 <= cpuregs_rs2;
						(* parallel_case *)
						case (1'b1)
							is_sb_sh_sw: begin
								cpu_state <= cpu_state_stmem;
								mem_do_rinst <= 1;
							end
							is_sll_srl_sra: begin
								cpu_state <= cpu_state_shift;
							end
							default: begin
								mem_do_rinst <= mem_do_prefetch;
								cpu_state <= cpu_state_exec;
							end
						endcase
					end
				endcase
			end

			cpu_state_ld_rs2: begin
				reg_sh <= cpuregs_rs2;
				reg_op2 <= cpuregs_rs2;

				(* parallel_case *)
				case (1'b1)
					is_sb_sh_sw: begin
						cpu_state <= cpu_state_stmem;
						mem_do_rinst <= 1;
					end
					is_sll_srl_sra: begin
						cpu_state <= cpu_state_shift;
					end
					default: begin
						mem_do_rinst <= mem_do_prefetch;
						cpu_state <= cpu_state_exec;
					end
				endcase
			end

			cpu_state_exec: begin
				reg_out <= reg_pc + decoded_imm;
				if (is_beq_bne_blt_bge_bltu_bgeu) begin
					latched_rd <= 0;
					latched_store <= alu_out_0;
					latched_branch <= alu_out_0;
					if (mem_done)
						cpu_state <= cpu_state_fetch;
					if (alu_out_0) begin
						decoder_trigger <= 0;
						set_mem_do_rinst = 1;
					end
				end else begin
					latched_branch <= instr_jalr;
					latched_store <= 1;
					latched_stalu <= 1;
					cpu_state <= cpu_state_fetch;
				end
			end

			cpu_state_shift: begin
				latched_store <= 1;
				if (reg_sh == 0) begin
					reg_out <= reg_op1;
					mem_do_rinst <= mem_do_prefetch;
					cpu_state <= cpu_state_fetch;
				end else begin
					(* parallel_case, full_case *)
					case (1'b1)
						instr_slli || instr_sll: reg_op1 <= reg_op1 << 1;
						instr_srli || instr_srl: reg_op1 <= reg_op1 >> 1;
						instr_srai || instr_sra: reg_op1 <= $signed(reg_op1) >>> 1;
					endcase
					reg_sh <= reg_sh - 1;
				end
			end

			cpu_state_stmem: begin
				if (!mem_do_prefetch || mem_done) begin
					if (!mem_do_wdata) begin
						(* parallel_case, full_case *)
						case (1'b1)
							instr_sb: mem_wordsize <= 2;
							instr_sh: mem_wordsize <= 1;
							instr_sw: mem_wordsize <= 0;
						endcase
						reg_op1 <= reg_op1 + decoded_imm;
						set_mem_do_wdata = 1;
					end
					if (!mem_do_prefetch && mem_done) begin
						cpu_state <= cpu_state_fetch;
						decoder_trigger <= 1;
						decoder_pseudo_trigger <= 1;
					end
				end
			end

			cpu_state_ldmem: begin
				latched_store <= 1;
				if (!mem_do_prefetch || mem_done) begin
					if (!mem_do_rdata) begin
						(* parallel_case, full_case *)
						case (1'b1)
							instr_lb || instr_lbu: mem_wordsize <= 2;
							instr_lh || instr_lhu: mem_wordsize <= 1;
							instr_lw: mem_wordsize <= 0;
						endcase
						latched_is_lu <= is_lbu_lhu_lw;
						latched_is_lh <= instr_lh;
						latched_is_lb <= instr_lb;
						reg_op1 <= reg_op1 + decoded_imm;
						set_mem_do_rdata = 1;
					end
					if (!mem_do_prefetch && mem_done) begin
						(* parallel_case, full_case *)
						case (1'b1)
							latched_is_lu: reg_out <= mem_rdata_word;
							latched_is_lh: reg_out <= $signed(mem_rdata_word[15:0]);
							latched_is_lb: reg_out <= $signed(mem_rdata_word[7:0]);
						endcase
						decoder_trigger <= 1;
						decoder_pseudo_trigger <= 1;
						cpu_state <= cpu_state_fetch;
					end
				end
			end
		endcase

		if (resetn && (mem_do_rdata || mem_do_wdata)) begin
			if (mem_wordsize == 0 && reg_op1[1:0] != 0) begin
					cpu_state <= cpu_state_trap;
			end
			if (mem_wordsize == 1 && reg_op1[0] != 0) begin
					cpu_state <= cpu_state_trap;
			end
		end
		if (resetn && mem_do_rinst && (|reg_pc[1:0])) begin
				cpu_state <= cpu_state_trap;
		end

		if (!resetn || mem_done) begin
			mem_do_prefetch <= 0;
			mem_do_rinst <= 0;
			mem_do_rdata <= 0;
			mem_do_wdata <= 0;
		end

		if (set_mem_do_rinst)
			mem_do_rinst <= 1;
		if (set_mem_do_rdata)
			mem_do_rdata <= 1;
		if (set_mem_do_wdata)
			mem_do_wdata <= 1;

		current_pc = 'bx;
	end


endmodule


