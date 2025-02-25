/*
 *  SVO - Simple Video Out FPGA Core
 *
 *  Copyright (C) 2014  Clifford Wolf <clifford@clifford.at>
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

`timescale 1ns / 1ps
`include "svo_defines.vh"

module svo_tcard #( `SVO_DEFAULT_PARAMS ) (
	input clk, resetn,

    input       fb_in_valid,
    input [7:0] fb_in_tdata,

	output reg out_axis_tvalid,
	input out_axis_tready,
	output reg [SVO_BITS_PER_PIXEL-1:0] out_axis_tdata,
	output reg [0:0] out_axis_tuser
);
	`SVO_DECLS

	localparam HOFFSET = ((32 - (SVO_HOR_PIXELS % 32)) % 32) / 2;
	localparam VOFFSET = ((32 - (SVO_VER_PIXELS % 32)) % 32) / 2;

	reg [`SVO_XYBITS-1:0] hcursor;
	reg [`SVO_XYBITS-1:0] vcursor;

	reg [`SVO_XYBITS-6:0] x;
	reg [`SVO_XYBITS-6:0] y;

	reg [9:0] xoff;
    reg [8:0] yoff;

    wire [15:0] ad;
    wire [3:0] dout;

    assign ad = fb_in_valid ? 1 : {yoff[8:1],  xoff[8:1]};

    Gowin_SP your_instance_name(
        .clk    (clk), //input clk
        .oce    (1'b1), //input oce
        .ce     (1'b1), //input ce
        .reset  (!resetn), //input reset

        .wre    (fb_in_valid), //input wre
        .ad     (ad), //input [15:0] ad
        .dout   (dout), //output [3:0] dout
        .din    (fb_in_tdata[3:0]) //input [3:0] din
    );

	always @(posedge clk) begin
		if (!resetn) begin
			hcursor <= 0;
			vcursor <= 0;
			x <= 0;
			y <= 0;
			xoff <= HOFFSET;
			yoff <= VOFFSET;
			out_axis_tvalid <= 0;
			out_axis_tdata <= 0;
			out_axis_tuser <= 0;
		end else
		if (!out_axis_tvalid || out_axis_tready) begin

			out_axis_tuser[0] <= !hcursor && !vcursor;

            out_axis_tvalid <= 1;
            if((x == 0 && x <= 1 ) && (y == 0 && y <= 1))
                  out_axis_tdata <= (xoff >= 511) ? 0 : {dout,4'b0,8'b00000000,8'b00000000};

			if (hcursor == SVO_HOR_PIXELS-1) begin
				hcursor <= 0;
				x <= 0;
				xoff <= HOFFSET;
				if (vcursor == SVO_VER_PIXELS-1) begin
					vcursor <= 0;
					y <= 0;
					yoff <= VOFFSET;
				end else begin
					vcursor <= vcursor + 1;
					if (&yoff)
						y <= y + 1;
					yoff <= yoff + 1;
				end
			end else begin
				hcursor <= hcursor + 1;
				if (&xoff)
					x <= x + 1;
				xoff <= xoff + 1;
			end
		end
	end
endmodule
