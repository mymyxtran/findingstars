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
		defparam vga0.BACKGROUND_IMAGE = "stars24Col.mif";
			
		

endmodule

//this module combines topDataPath and state_machine1
module findWhite(input[2:0] xIn, yIn, input clk, resetn, doneDraw, doneClean, topBottomFound, leftFound, rightFound, output goDraw, goClean,
				goMapColumns, goMapRows, plotEn);

	wire pLoad, countXEn, countYEn, wrEn, starFound, endOfImg, xMax, newRow;
	
	assign wrEn = 1'b0;
	
	topDataPath topDP(.pLoad(pLoad), .xIn(xIn), .yIn(yIn), .countXEn(countXEn), .countYEn(countYEn), .newRow(newRow), 
							.clk(clk), .resetn(resetn), .wrEn(wrEn), .starFound(starFound), .endOfImg(endOfImg), .xMax(xMax));
							
	
	state_machine1 fsm1(.resetn(resetn), .clk(clk), .starFound(starFound), .endOfImg(endOfImg), .newRow(newRow),
							 .xMax(xMax), .doneDraw(doneDraw), .doneClean(doneClean), .topBottomFound(topBottomFound),
								.leftFound(leftFound), .rightFound(rightFound), .ld_count(pLoad), .countXEn(countXEn), .countYEn(countYEn), .plotEn(plotEn), 
								.goDraw(goDraw), .goMapRows(goMapRows), .goMapColumns(goMapColumns), .goClean(goClean));

endmodule


module topDataPath(pLoad, xIn, yIn, countXEn, countYEn, newRow, clk, resetn, wrEn, starFound, endOfImg, xMax);

		parameter xSz = 3;
		parameter ySz = 3;
		parameter addrSz = 6;
		parameter colSz = 3;
		
		localparam MAX_X = 3'd6;//max X size is 6 pixels
		localparam MAX_Y = 3'd6;
		
		//set the threshold for pixel value
		localparam THRESHOLD = 0;
		
		input clk, resetn;
		
		//write to memory if required (to blot out white pixels we've already checked)
		input wrEn;
		
		input pLoad;//parallel load counters
		input countXEn, countYEn; //enable for counters
		
		input newRow; //switching to a new row, so reset x Count to 0
		
		//input x and y coor to load counters if required
		input[xSz-1:0] xIn;
		input[ySz-1:0] yIn;
		
		output starFound;//1 if star is found, 0 if not
		output endOfImg;//have all pixels been visited?
		
		output reg xMax; //has end of row been reached?
		
		reg[xSz-1:0] xCount;//output wires for counters
		reg[ySz-1:0] yCount;
		
		wire[addrSz-1:0] addressOut;//address wire from translator
		
		wire[colSz-1:0] writeCol;//colour to write
		
		assign writeCol = 0;
		
		wire[colSz-1:0] pixVal;
		
		//instantiate the x counter
		always@(posedge clk) begin
			if(!resetn)
				xCount <= 0;
			else if(pLoad)
				xCount <= xIn;
			else if(xCount == MAX_X-1)//reset count to avoid accessing undefined mem
				xCount <= 0;
				yCount <= yCount + 1;
			else if(countXEn)
				xCount <= xCount + 1;			
		end
		
		always@(posedge clk) begin
			if(!resetn)
				xMax <= 0;
			else if(xCount == MAX_X-2)
				xMax <= 1;
			else
				xMax <= 0;			
		end
		
		//instantiate the y counter
		always@(posedge clk) begin
			if(!resetn)
				yCount <= 0;
			else if(pLoad)
				yCount <= yIn;
			else if(yCount == MAX_Y-1)
				yCount <= 0;
			else if(countYEn)
				yCount <= yCount + 1;			
		end
		
		//if counts are maxxed, set endOfImage to 1
		assign endOfImg = (yCount == MAX_Y);
		
				
		//instantiate address translator
		address_translator trans0(.x(xCount), .y(yCount), .mem_address(addressOut));
		
		//instantiate mem block
		ram36x3_1 ram0(.address(addressOut),.q(pixVal), .clock(clk), .wren(wrEn), .data(writeCol));
		
		assign starFound = (pixVal > THRESHOLD);

endmodule

module state_machine1(input resetn, clk, starFound, endOfImg, topBottomFound, leftFound, rightFound, xMax, doneDraw, doneClean,
								output reg ld_count, countXEn, countYEn, plotEn, goMapRows, goMapColumns, goDraw, goClean, newRow);

	reg [3:0] current_state, next_state; 
    
   localparam   RESET = 4'd0,
					 CHECK_COUNT  = 4'd1,
					 CHECK_PIX  = 4'd2,
					 INCR_X = 4'd3,
					 INCR_Y  = 4'd4,
					 MAP_TOP_BOT = 4'd5,
					 MAP_L_R = 4'd6,
					 DRAW_SQ = 4'd7,
					 LOAD_COUNT = 4'd8,
					 END_OF_IMG = 4'd9,
					 CLEAN_STAR = 4'd10;//this state would turn star bkack so we dont check it again?
	
	//next state logic
	//change to sequential?
	always@(*)
	begin: state_table
		case(current_state)
			RESET: next_state = CHECK_COUNT;
			CHECK_COUNT: next_state = (endOfImg) ? END_OF_IMG : CHECK_PIX;
			CHECK_PIX: next_state = (starFound) ? MAP_TOP_BOT : INCR_X;
			INCR_X: next_state = (xMax) ? INCR_Y : CHECK_COUNT;
			INCR_Y: next_state = CHECK_COUNT;
			MAP_TOP_BOT: next_state = (topBottomFound) ? MAP_L_R : MAP_TOP_BOT;
			MAP_L_R: next_state = (rightFound && leftFound) ? DRAW_SQ : MAP_L_R;
			DRAW_SQ: next_state = (doneDraw) ? CLEAN_STAR : DRAW_SQ;
			LOAD_COUNT: next_state = CHECK_COUNT;
			CLEAN_STAR: begin
				if(doneClean)
					next_state = CHECK_COUNT;
				else//keep cleaning until done!
					next_state = CLEAN_STAR;
			end
			//END_OF_IMG: next_state = ??;
			default: next_state = CHECK_COUNT;
		
		endcase
	
	end
	
	
	//output logic/datapath control
	always@(*)
	begin: enable_signals
		ld_count = 1'b0;
		countXEn = 1'b0;
		countYEn = 1'b0;
		goMapRows = 1'b0;
		goMapColumns = 1'b0;
		plotEn = 1'b0;
		goDraw = 1'b0;
		goClean = 1'b0;
		newRow = 1'b0;
		
		case(current_state)
			INCR_X: begin
				countXEn = 1'b1;
			end
			INCR_Y: begin
				countYEn = 1'b1;
			end
			MAP_TOP_BOT: begin
				goMapRows = 1'b1;
			end
			MAP_L_R: begin
				goMapColumns = 1'b1;
			end
			DRAW_SQ: begin
				goDraw = 1'b1;
			end
			LOAD_COUNT: begin
				ld_count = 1'b1;
			end
			CLEAN_STAR: begin
				goClean = 1'b1;
			end
		//END_OF_IMG: plotEn = 1'b1; ????
		endcase
	
	end
	
	//current state registers
	always@(posedge clk) begin
		if(!resetn)
			current_state <= RESET;
		else
			current_state <= next_state;
   end       

endmodule

/* This module converts a user specified coordinates into a memory address.
 * The output of the module depends on the resolution set by the user.
 */
module address_translator(x, y, mem_address);

	input [2:0] x; 
	input [2:0] y;	
	output [5:0] mem_address;
	
	/* The basic formula is address = y*WIDTH + x;
	 * For 320x240 resolution we can write 320 as (256 + 64). Memory address becomes
	 * (y*256) + (y*64) + x;
	 * This simplifies multiplication a simple shift and add operation.
	 * A leading 0 bit is added to each operand to ensure that they are treated as unsigned
	 * inputs. By default the use a '+' operator will generate a signed adder.
	 * Similarly, for 160x120 resolution we write 160 as 128+32.
	 */
	 //width = 6 = 4 + 2
	 //so address = (y*4) + (y*2) + x
	 assign mem_address = ({1'b0, y, 2'd0} + {1'b0, y, 1'd0} + {1'b0, x});
	

endmodule


