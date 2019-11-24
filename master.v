//this module combines topDataPath and state_machine1
module master(xLeft, xRight, yTop, yBottom, GO, clk, resetn, doneDraw, doneClean, topBottomFound, leftFound, rightFound, 
	      goDraw, goClean, goMapColumns, goMapRows, plotEn, xCount, yCount);

	localparam THRESHOLD = 0;
	
	parameter xSz = 3;
	parameter ySz = 3;
	parameter addrSz = 6;
	parameter colSz = 3;

	input GO, clk, resetn, doneDraw, doneClean, topBottomFound, leftFound, rightFound;
	
	input[xSz-1:0] xRight, xLeft;
	input[ySz-1:0] yTop, yBottom;

	output[xSz-1:0] xCount;
	output[ySz-1:0] yCount;

	//goes to findTB, findLR, draw
	output goDraw, goClean, goMapColumns, goMapRows, plotEn;
	
	//wires btw master dp and control
	wire pLoad, countXEn, countYEn, endOfImg;
	
	//wires from clean to master control/dp and vice versa
	wire wrEn, starFound;

	wire[colSz-1:0] pixVal;

	
	wire[addrSz-1:0] finalAddress;
	wire[addrSz-1:0] addressRead;
	wire[addrSz-1:0] addressWrite;

	wire[colSz-1:0] colIn;
	
	
	topDataPath topDP(.countXEn(countXEn), .countYEn(countYEn),  
			  .clk(clk), .resetn(resetn), .addressOut(addressRead), .endOfImg(endOfImg), .xCount(xCount), .yCount(yCount));

	

	state_machine1 fsm1(.GO(GO),.resetn(resetn), .clk(clk), .starFound(starFound), .endOfImg(endOfImg),
							  .doneDraw(doneDraw), .doneClean(doneClean), .topBottomFound(topBottomFound),
								.leftFound(leftFound), .rightFound(rightFound), .ld_count(pLoad), .countXEn(countXEn), .countYEn(countYEn), .plotEn(plotEn), 
								.goDraw(goDraw), .goMapRows(goMapRows), .goMapColumns(goMapColumns), .goClean(goClean));
	
	clean_star cleanModule(.goClean(goClean), .xLeft(xLeft), .xRight(xRight), .yTop(yTop), .yBottom(yBottom), .clk(clk),
			       .addressOut(addressWrite), .colOut(colIn), .doneClean(doneClean), .wrEn(wrEn));

	ram36x3_1 imageMem(.q(pixVal), .address(finalAddress), .data(pixVal), .clock(clk), .wren(wrEn));
	
						
	assign starFound = pixVal > THRESHOLD;
	
	//addressRead comes from top-level fsm, addressWrite comes from clean module
	assign finalAddress = (wrEn) ? addressWrite : addressRead; 
							
	
	
endmodule


module topDataPath(countXEn, countYEn, clk, resetn, endOfImg, addressOut, xCount, yCount);

		parameter xSz = 3;
		parameter ySz = 3;
		parameter addrSz = 6;
		parameter colSz = 3;
		
		localparam MAX_X = 3'd6;//max X size is 160 pixels
		localparam MAX_Y = 3'd6;
		
		
		input clk, resetn;
		
		
		input countXEn, countYEn; //enable for counters
		
		
		output endOfImg;//have all pixels been visited?
		
		
		output reg[xSz-1:0] xCount;//output wires for counters
		output reg[ySz-1:0] yCount;
		
		output[addrSz-1:0] addressOut;//address wire from translator
		
		
		//instantiate the x/y counters
		always@(posedge clk) begin
			if(!resetn) begin
				xCount <= 0;
				yCount <= 0;
			end
			else if(xCount == MAX_X-1) begin//reset count to avoid accessing undefined mem and enable for Y count
				xCount <= 0;
				yCount <= yCount + 1;
			end
			else if(countXEn)
				xCount <= xCount + 1;			
		end
		
		
		
		//if counts are maxxed, set endOfImage to 1
		assign endOfImg = (yCount == MAX_Y);
		
				
		//instantiate address translator
		address_translator trans0(.x(xCount), .y(yCount), .mem_address(addressOut));
		

endmodule

module state_machine1(input resetn, clk, GO, starFound, endOfImg, topBottomFound, leftFound, rightFound, doneDraw, doneClean,
								output reg ld_count, countXEn, countYEn, plotEn, output goMapRows, goMapColumns, goDraw, goClean);

	reg [3:0] current_state, next_state; 
   
	//for pulses
	reg goMapRows_s, goMapColumns_s, goDraw_s, goClean_s;
	
	reg goMapRows_DL, goMapColumns_DL, goDraw_DL, goClean_DL;
	
   localparam   RESET = 4'd0,
					 WAIT_FOR_START = 4'd11,
					 CHECK_COUNT  = 4'd1,
					 CHECK_PIX  = 4'd2,
					 INCR_X = 4'd3,
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
			//WAIT_FOR_START: next_state = (GO) ? CHECK_COUNT : WAIT_FOR_START;
			CHECK_COUNT: next_state = (endOfImg) ? END_OF_IMG : CHECK_PIX;
			CHECK_PIX: next_state = (starFound) ? MAP_TOP_BOT : INCR_X;
			INCR_X: next_state = CHECK_COUNT;
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
			//END_OF_IMG: next_state = WAIT_FOR_START;
			default: next_state = CHECK_COUNT;
		
		endcase
	
	end
	
	
	//output logic/datapath control
	always@(*)
	begin: enable_signals
		ld_count = 1'b0;
		countXEn = 1'b0;
		countYEn = 1'b0;
		goMapRows_s = 1'b0;
		goMapColumns_s = 1'b0;
		plotEn = 1'b0;
		goDraw_s = 1'b0;
		goClean_s = 1'b0;
		
		case(current_state)
			INCR_X: begin
				countXEn = 1'b1;
			end
			MAP_TOP_BOT: begin
				goMapRows_s = 1'b1;
			end
			MAP_L_R: begin
				goMapColumns_s = 1'b1;
			end
			DRAW_SQ: begin
				goDraw_s = 1'b1;
			end
			LOAD_COUNT: begin
				ld_count = 1'b1;
			end
			CLEAN_STAR: begin
				goClean_s = 1'b1;
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

	//for pulses!
	assign goMapRows = (!goMapRows_DL) && (goMapRows_s);
	assign goMapColumns = (!goMapColumns_DL) && (goMapColumns_s);
	assign goDraw = (!goDraw_DL) && (goDraw_s);
	assign goClean = (!goClean_DL) && (goClean_s);
	
	always@(posedge clk) begin
		if(goMapRows_s)
			goMapRows_DL <= 1'b1;
		else if(goMapColumns_s)
			goMapColumns_DL <= 1'b1;
		else if(goDraw_s)
			goDraw_DL <= 1'b1;
		else if(goClean_s)
			goClean_DL <= 1'b1;
		else begin
			goMapColumns_DL <= 0;
			goMapRows_DL <= 0;
			goDraw_DL <= 0;
			goClean_DL <= 0;
		end
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