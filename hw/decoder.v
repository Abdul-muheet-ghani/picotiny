module decoder(
    input clk,
    input resetn,
    input mem_xfer,

    input mem_do_rinst,
    input mem_done,

    input decoder_trigger,
    input decoder_pseudo_trigger,

    output reg instr_lui, 
    output reg instr_auipc, 
    output reg instr_jal, 
    output reg instr_jalr,
    output reg is_beq_bne_blt_bge_bltu_bgeu,
    output reg is_lb_lh_lw_lbu_lhu,
    output reg is_sb_sh_sw,
    output reg is_alu_reg_imm,
    output reg is_alu_reg_reg,

    output reg instr_beq,
    output reg instr_bne,
    output reg instr_blt,
    output reg instr_bge,
    output reg instr_bltu,
    output reg instr_bgeu,

    output reg instr_lb,
    output reg instr_lh,
    output reg instr_lw,
    output reg instr_lbu,
    output reg instr_lhu,

    output reg instr_sb,
    output reg instr_sh,
    output reg instr_sw,

    output reg instr_addi,
    output reg instr_slti,
    output reg instr_sltiu,
    output reg instr_xori,
    output reg instr_ori,
    output reg instr_andi,

    output reg instr_slli,
    output reg instr_srli,
    output reg instr_srai,

    output reg instr_add,
    output reg instr_sub,
    output reg instr_sll,
    output reg instr_slt,
    output reg instr_sltu,
    output reg instr_xor,
    output reg instr_srl,
    output reg instr_sra,
    output reg instr_or,
    output reg instr_and,

    output reg instr_rdcycle,
    output reg instr_rdinstr,

    output reg is_slli_srli_srai,
    output reg is_jalr_addi_slti_sltiu_xori_ori_andi,
    output reg is_sll_srl_sra,
    
    output reg [4:0] decoded_rd, 
    output reg [4:0] decoded_rs1, 
    output reg [4:0] decoded_rs2,

    
    input      [31:0] mem_rdata,
    output reg [31:0] decoded_imm_j,
    output reg [31:0] mem_rdata_q
);

    wire [31:0] mem_rdata_latched;

    assign mem_rdata_latched = (mem_xfer) ? mem_rdata : mem_rdata_q;

    always @(posedge clk) begin
		if (mem_xfer) begin
			mem_rdata_q <= mem_rdata;
		end
	end

    always @(posedge clk) begin
        if(!resetn)begin
            is_beq_bne_blt_bge_bltu_bgeu <= 0;
            instr_beq   <= 0;
			instr_bne   <= 0;
			instr_blt   <= 0;
			instr_bge   <= 0;
			instr_bltu  <= 0;
			instr_bgeu  <= 0;

			instr_addi  <= 0;
			instr_slti  <= 0;
			instr_sltiu <= 0;
			instr_xori  <= 0;
			instr_ori   <= 0;
			instr_andi  <= 0;

			instr_add   <= 0;
			instr_sub   <= 0;
			instr_sll   <= 0;
			instr_slt   <= 0;
			instr_sltu  <= 0;
			instr_xor   <= 0;
			instr_srl   <= 0;
			instr_sra   <= 0;
			instr_or    <= 0;
			instr_and   <= 0;
        end
        else begin
    	    if (mem_do_rinst && mem_done) begin
		    	instr_lui     <= mem_rdata_latched[6:0] == 7'b0110111;
		    	instr_auipc   <= mem_rdata_latched[6:0] == 7'b0010111;
		    	instr_jal     <= mem_rdata_latched[6:0] == 7'b1101111;
		    	instr_jalr    <= mem_rdata_latched[6:0] == 7'b1100111 && mem_rdata_latched[14:12] == 3'b000;

		    	is_beq_bne_blt_bge_bltu_bgeu <= mem_rdata_latched[6:0] == 7'b1100011;
		    	is_lb_lh_lw_lbu_lhu          <= mem_rdata_latched[6:0] == 7'b0000011;
		    	is_sb_sh_sw                  <= mem_rdata_latched[6:0] == 7'b0100011;
		    	is_alu_reg_imm               <= mem_rdata_latched[6:0] == 7'b0010011;
		    	is_alu_reg_reg               <= mem_rdata_latched[6:0] == 7'b0110011;

		    	{ decoded_imm_j[31:20], decoded_imm_j[10:1], decoded_imm_j[11], decoded_imm_j[19:12], decoded_imm_j[0] } <= $signed({mem_rdata_latched[31:12], 1'b0});

		    	decoded_rd <= mem_rdata_latched[11:7];
		    	decoded_rs1 <= mem_rdata_latched[19:15];
		    	decoded_rs2 <= mem_rdata_latched[24:20];
		    end
            if (decoder_trigger && !decoder_pseudo_trigger) begin
		    	instr_beq   <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b000;
		    	instr_bne   <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b001;
		    	instr_blt   <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b100;
		    	instr_bge   <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b101;
		    	instr_bltu  <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b110;
		    	instr_bgeu  <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b111;
    
		    	instr_lb    <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b000;
		    	instr_lh    <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b001;
		    	instr_lw    <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b010;
		    	instr_lbu   <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b100;
		    	instr_lhu   <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b101;
    
		    	instr_sb    <= is_sb_sh_sw && mem_rdata_q[14:12] == 3'b000;
		    	instr_sh    <= is_sb_sh_sw && mem_rdata_q[14:12] == 3'b001;
		    	instr_sw    <= is_sb_sh_sw && mem_rdata_q[14:12] == 3'b010;
    
		    	instr_addi  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b000;
		    	instr_slti  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b010;
		    	instr_sltiu <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b011;
		    	instr_xori  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b100;
		    	instr_ori   <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b110;
		    	instr_andi  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b111;
    
		    	instr_slli  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b001 && mem_rdata_q[31:25] == 7'b0000000;
		    	instr_srli  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0000000;
		    	instr_srai  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0100000;
    
		    	instr_add   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b000 && mem_rdata_q[31:25] == 7'b0000000;
		    	instr_sub   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b000 && mem_rdata_q[31:25] == 7'b0100000;
		    	instr_sll   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b001 && mem_rdata_q[31:25] == 7'b0000000;
		    	instr_slt   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b010 && mem_rdata_q[31:25] == 7'b0000000;
		    	instr_sltu  <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b011 && mem_rdata_q[31:25] == 7'b0000000;
		    	instr_xor   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b100 && mem_rdata_q[31:25] == 7'b0000000;
		    	instr_srl   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0000000;
		    	instr_sra   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0100000;
		    	instr_or    <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b110 && mem_rdata_q[31:25] == 7'b0000000;
		    	instr_and   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b111 && mem_rdata_q[31:25] == 7'b0000000;
    
		    	instr_rdcycle  <= ((mem_rdata_q[6:0] == 7'b1110011 && mem_rdata_q[31:12] == 'b11000000000000000010) ||
		    	                   (mem_rdata_q[6:0] == 7'b1110011 && mem_rdata_q[31:12] == 'b11000000000100000010));
		    	instr_rdinstr  <=  (mem_rdata_q[6:0] == 7'b1110011 && mem_rdata_q[31:12] == 'b11000000001000000010);
    
		    	is_slli_srli_srai <= is_alu_reg_imm && |{
		    		mem_rdata_q[14:12] == 3'b001 && mem_rdata_q[31:25] == 7'b0000000,
		    		mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0000000,
		    		mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0100000
		    	};
    
		    	is_jalr_addi_slti_sltiu_xori_ori_andi <= instr_jalr || is_alu_reg_imm && |{
		    		mem_rdata_q[14:12] == 3'b000,
		    		mem_rdata_q[14:12] == 3'b010,
		    		mem_rdata_q[14:12] == 3'b011,
		    		mem_rdata_q[14:12] == 3'b100,
		    		mem_rdata_q[14:12] == 3'b110,
		    		mem_rdata_q[14:12] == 3'b111
		    	};
    
		    	is_sll_srl_sra <= is_alu_reg_reg && |{
		    		mem_rdata_q[14:12] == 3'b001 && mem_rdata_q[31:25] == 7'b0000000,
		    		mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0000000,
		    		mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0100000
		    	};
		    end
        end
    end
endmodule 
