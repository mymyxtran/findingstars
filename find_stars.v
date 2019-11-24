`timescale 1ns/1ns

module find_stars
	( KEY, CLOCK_50,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);
	input[1:0] KEY;
	input CLOCK_50;
	
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter vga0(.resetn(KEY[0]), .clock(CLOCK_50),.VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_BLANK(VGA_BLANK_N), .VGA_SYNC(VGA_SYNC_N), .VGA_CLK(VGA_CLK));
	 
		defparam vga0.RESOLUTION = "160x120";
		defparam vga0.MONOCHROME = "FALSE";
		defparam vga0.BITS_PER_COLOUR_CHANNEL = 1;
		defparam vga0.BACKGROUND_IMAGE = "oneStar160x120.mif";
	
	wire starFound;
	wire[3:0] pixVal;
	wire wrEn;
	
	localparam THRESHOLD = 0;
	
	topDataPath topDP(.pLoad(pLoad), .countXEn(countXEn), .countYEn(countYEn),  
			  .clk(clk), .resetn(resetn), .wrEn(wrEn), .addressOut(addressOut), .endOfImg(endOfImg));
	
	ram19200x3_c imageMem(.q(pixVal), .address(address_out), .clock(CLOCK_50), .wren(wrEn));
						
	assign starFound = pixVal > THRESHOLD;
	
	
	state_machine1 fsm1(.resetn(resetn), .clk(clk), .starFound(starFound), .endOfImg(endOfImg),
							  .doneDraw(doneDraw), .doneClean(doneClean), .topBottomFound(topBottomFound),
								.leftFound(leftFound), .rightFound(rightFound), .ld_count(pLoad), .countXEn(countXEn), .countYEn(countYEn), .plotEn(plotEn), 
								.goDraw(goDraw), .goMapRows(goMapRows), .goMapColumns(goMapColumns), .goClean(goClean));

			
		

endmodule

/* This module converts a user specified coordinates into a memory address.
 * The output of the module depends on the resolution set by the user.
 */
module vga_address_translator(x, y, mem_address);

	parameter RESOLUTION = "160x120";
	/* Set this parameter to "160x120" or "320x240". It will cause the VGA adapter to draw each dot on
	 * the screen by using a block of 4x4 pixels ("160x120" resolution) or 2x2 pixels ("320x240" resolution).
	 * It effectively reduces the screen resolution to an integer fraction of 640x480. It was necessary
	 * to reduce the resolution for the Video Memory to fit within the on-chip memory limits.
	 */

	input [((RESOLUTION == "320x240") ? (8) : (7)):0] x; 
	input [((RESOLUTION == "320x240") ? (7) : (6)):0] y;	
	output reg [((RESOLUTION == "320x240") ? (16) : (14)):0] mem_address;
	
	/* The basic formula is address = y*WIDTH + x;
	 * For 320x240 resolution we can write 320 as (256 + 64). Memory address becomes
	 * (y*256) + (y*64) + x;
	 * This simplifies multiplication a simple shift and add operation.
	 * A leading 0 bit is added to each operand to ensure that they are treated as unsigned
	 * inputs. By default the use a '+' operator will generate a signed adder.
	 * Similarly, for 160x120 resolution we write 160 as 128+32.
	 */
	wire [16:0] res_320x240 = ({1'b0, y, 8'd0} + {1'b0, y, 6'd0} + {1'b0, x});
	wire [15:0] res_160x120 = ({1'b0, y, 7'd0} + {1'b0, y, 5'd0} + {1'b0, x});
	
	always @(*)
	begin
		if (RESOLUTION == "320x240")
			mem_address = res_320x240;
		else
			mem_address = res_160x120[14:0];
	end
endmodule

