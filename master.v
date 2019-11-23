//this module combines topDataPath and state_machine1
module master(input[2:0] xIn, yIn, input GO, clk, resetn, doneDraw, doneClean, topBottomFound, leftFound, rightFound, output goDraw, goClean,
				goMapColumns, goMapRows, plotEn);

	wire pLoad, countXEn, countYEn, wrEn, starFound, endOfImg;
	
	assign wrEn = 1'b0;
	
	topDataPath topDP(.pLoad(pLoad), .xIn(xIn), .yIn(yIn), .countXEn(countXEn), .countYEn(countYEn),  
							.clk(clk), .resetn(resetn), .wrEn(wrEn), .starFound(starFound), .endOfImg(endOfImg));
							
	
	state_machine1 fsm1(.resetn(resetn), .clk(clk), .starFound(starFound), .endOfImg(endOfImg),
							  .doneDraw(doneDraw), .doneClean(doneClean), .topBottomFound(topBottomFound),
								.leftFound(leftFound), .rightFound(rightFound), .ld_count(pLoad), .countXEn(countXEn), .countYEn(countYEn), .plotEn(plotEn), 
								.goDraw(goDraw), .goMapRows(goMapRows), .goMapColumns(goMapColumns), .goClean(goClean));

endmodule


module topDataPath(pLoad, xIn, yIn, countXEn, countYEn, clk, resetn, wrEn, starFound, endOfImg);

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
		
		
		//input x and y coor to load counters if required
		input[xSz-1:0] xIn;
		input[ySz-1:0] yIn;
		
		output starFound;//1 if star is found, 0 if not
		output endOfImg;//have all pixels been visited?
		
		//output reg xMax; //has end of row been reached?
		
		reg[xSz-1:0] xCount;//output wires for counters
		reg[ySz-1:0] yCount;
		
		wire[addrSz-1:0] addressOut;//address wire from translator
		
		wire[colSz-1:0] writeCol;//colour to write
		
		assign writeCol = 0;
		
		wire[colSz-1:0] pixVal;
		
		//instantiate the x/y counters
		always@(posedge clk) begin
			if(!resetn) begin
				xCount <= 0;
				yCount <= 0;
			end
			else if(pLoad) begin
				xCount <= xIn;
				yCount <= yIn;
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
		
		//instantiate mem block
		ram36x3_1 ram0(.address(addressOut),.q(pixVal), .clock(clk), .wren(wrEn), .data(writeCol));
		
		assign starFound = (pixVal > THRESHOLD);

endmodule

module state_machine1(input resetn, clk, GO, starFound, endOfImg, topBottomFound, leftFound, rightFound, xMax, doneDraw, doneClean,
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
			RESET: next_state = WAIT_FOR_START;
			WAIT_FOR_START: next_state = (GO) ? CHECK_COUNT : WAIT_FOR_START;
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
			END_OF_IMG: next_state = WAIT_FOR_START;
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


