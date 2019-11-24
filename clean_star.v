`timescale 1ns/1ns

module clean_star(goClean, xLeft, xRight, yTop, yBottom, clk, addressOut, colOut, doneClean, wrEn);

	//contants; depend on image size and colour res
	parameter xSz = 3;
	parameter ySz = 3;
	parameter colSz = 3;
	parameter addrSz = 6;
	
	//these define the dimensions of the box
	input[xSz-1:0] xLeft, xRight;
	input[ySz-1:0] yTop, yBottom;
	
	input clk, goClean;
	
	output[addrSz-1:0] addressOut;
	
	output[colSz-1:0] colOut;
	
	output doneClean;
	
	output wrEn;
	
	wire xEdge, yEdge, countYEn, countXEn, ld_x, ld_y, resetn;
	
	cleanDataPath cleanDP0(.xLeft(xLeft), .xRight(xRight), .yTop(yTop), .yBottom(yBottom), .clk(clk), .resetn(resetn),
								.countYEn(countYEn), .countXEn(countXEn), .ld_x(ld_x),.ld_y(ld_y),
								.xEdge(xEdge), .yEdge(yEdge), .addressOut(addressOut), .colOut(colOut));
		
	cleanControl cleanfsm0(.clk(clk), .resetn(resetn), .xEdge(xEdge), .yEdge(yEdge), .goClean(goClean), 
						.countXEn(countXEn), .countYEn(countYEn), .ld_x(ld_x), .ld_y(ld_y), .doneClean(doneClean), .wrEn(wrEn));
	

endmodule

module cleanDataPath(xLeft, xRight, yTop, yBottom, countXEn, countYEn, ld_x, ld_y, clk, resetn,
							xEdge, yEdge, addressOut, colOut);

	//contants; depend on image size and colour res
	parameter xSz = 3;
	parameter ySz = 3;
	parameter colSz = 3;
	parameter addrSz = 6;
	//these define the dimensions of the box
	input[xSz-1:0] xLeft, xRight;
	input[ySz-1:0] yTop, yBottom;
	
	input clk;
	input resetn;//comes from FSM
	
	input ld_x, ld_y; //parallel load for counters
	
	input countXEn, countYEn;
	
	output xEdge, yEdge;//are high if the edge of the box dim has been reached (i.e. gotten to the most right and the most bottom)
	
	//output to VGA adapter: note that this module already contains an address translator... but may need to remake depending 
	//on img size!
	output[addrSz-1:0] addressOut;
	output[colSz-1:0] colOut;
	
	//assign to black
	assign colOut = 3'b000;
	
	reg[xSz-1:0] xCount;
	reg[ySz-1:0] yCount;
	
	//instantiate the x counter
	always@(posedge clk) begin
			if(!resetn)
				xCount <= 0;
			else if(ld_x)
				xCount <= xLeft;
			else if(countXEn)
				xCount <= xCount + 1;			
	end
	
	//has the x edge been reached?
	assign xEdge = (xCount == xRight);
	
	//instantiate the y counter
	always@(posedge clk) begin
			if(!resetn)
				yCount <= 0;
			else if(ld_y)
				yCount <= yTop;
			else if(countYEn)
				yCount <= yCount + 1;			
	end
	
	//has the y edge been reached?
	assign yEdge = (yCount == yBottom);

	address_translator trans1(.x(xCount),.y(yCount),.mem_address(addressOut));
	
	
endmodule


module cleanControl(input clk, xEdge, yEdge, goClean, output reg countXEn, countYEn, ld_x, ld_y, wrEn, resetn, output doneClean);

	reg [3:0] current_state, next_state; 
   
	reg doneClean_s, doneClean_DL;//for pulsing
	
   localparam   START_CLEAN = 4'd0,
					 STORE_Y = 4'd1,
					 STORE_X  = 4'd2,
					 INCR_X = 4'd3,
					 INCR_Y  = 4'd4,
					 CLEAN_PIX = 4'd5,
					 DONE_CLEAN = 4'd6;
	
	//next state logic
	always@(*)
	begin: state_table
		case (current_state)
		START_CLEAN: next_state = STORE_Y;
		STORE_Y: next_state = STORE_X;
		STORE_X: next_state = CLEAN_PIX;
		CLEAN_PIX: next_state = INCR_X;
		INCR_X: begin
			if(xEdge)//if xEdge has been reached, time to change rows
				next_state = INCR_Y;
			else
				next_state = CLEAN_PIX;
			end
		INCR_Y: begin
			if(yEdge)
				next_state = DONE_CLEAN;
			else
				next_state = STORE_X;//if not at the bottom, reset the x count (reload the most left)
			end
		DONE_CLEAN: begin
			if(goClean)//wait at DONE_CLEAN until told to start cleaning again
				next_state = STORE_Y;
			else
				next_state = DONE_CLEAN;
			end
		default: next_state = DONE_CLEAN;
		endcase
	end
	
	//output logic/datapath control
	always@(*)
	begin: enable_signals
		ld_x = 1'b0;
		ld_y = 1'b0;
		countXEn = 1'b0;
		countYEn = 1'b0;
		doneClean_s = 1'b0;
		wrEn = 1'b0;
		resetn = 1'b1;
		
		case(current_state)
			START_CLEAN: begin
				resetn = 1'b0;
			end
			STORE_X: begin
				ld_x = 1'b1;
			end
			STORE_Y: begin
				ld_y = 1'b1;
			end
			INCR_X: begin
				countXEn = 1'b1;
			end
			INCR_Y: begin
				countYEn = 1'b1;
			end
			CLEAN_PIX: begin
				wrEn = 1'b1;//write "black" to the pixel in memory
			end
			DONE_CLEAN: begin
				doneClean_s = 1'b1;
			end
		
		endcase
	end
	
	//current state registers
	always@(posedge clk) begin
		if(goClean)//add another resetn?
			current_state <= START_CLEAN;
		else
			current_state <= next_state;
   end       

	//for pulses!
	assign doneClean = (!doneClean_DL) && (doneClean_s);
	
	always@(posedge clk) begin
		if(doneClean_s)
			doneClean_DL <= 1'b1;
		else
			doneClean_DL <= 0;
	
	end
	
endmodule

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

   
