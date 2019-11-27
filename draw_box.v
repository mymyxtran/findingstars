`timescale 1ns/1ns

module draw_box(goDraw, xLeft, xRight, yTop, yBottom, clk, xOut, yOut, colOut, doneDraw,plotEn);

	//contants; depend on image size and colour res
	parameter xSz = 8;
	parameter ySz = 7;
	parameter colSz = 3;
	
	//these define the dimensions of the box
	input[xSz-1:0] xLeft, xRight;
	input[ySz-1:0] yTop, yBottom;
	
	input clk, goDraw;
	
	output[xSz-1:0] xOut;
	output[ySz-1:0] yOut;
	
	output[colSz-1:0] colOut;
	
	output doneDraw;
	
	output plotEn;
	
	wire xEdge, yEdge, doneNE, doneNE_reg, countYEn, countXEn, ld_x, ld_y, resetn;
	
	drawDataPath drawDP0(.xLeft(xLeft), .xRight(xRight), .yTop(yTop), .yBottom(yBottom), .clk(clk), .resetn(resetn),
								.countYEn(countYEn), .countXEn(countXEn), .ld_x(ld_x),.ld_y(ld_y), .doneNE(doneNE), .doneNE_reg(doneNE_reg),
								.xEdge(xEdge), .yEdge(yEdge), .xOut(xOut), .yOut(yOut), .colOut(colOut));
		
	drawControl fsm0(.clk(clk), .resetn(resetn), .xEdge(xEdge), .yEdge(yEdge), .doneNE_reg(doneNE_reg), .goDraw(goDraw), 
						.countXEn(countXEn), .countYEn(countYEn), .doneNE(doneNE), .ld_x(ld_x), .ld_y(ld_y), .doneDraw(doneDraw), .plotEn(plotEn));
		
endmodule

module drawDataPath(xLeft, xRight, yTop, yBottom, countXEn, countYEn, ld_x, ld_y, clk, resetn, doneNE,
							xEdge, yEdge, doneNE_reg, xOut, yOut, colOut);

	//contants; depend on image size and colour res
	parameter xSz = 8;
	parameter ySz = 7;
	parameter colSz = 3;
	
	//these define the dimensions of the box
	input[xSz-1:0] xLeft, xRight;
	input[ySz-1:0] yTop, yBottom;
	
	input clk, resetn;//reset comes from FSM
	
	input ld_x, ld_y; //parallel load for counters
	
	input doneNE;//have the north and east sides of the box been drawn?
	
	input countXEn, countYEn;
	
	output xEdge, yEdge;//are high if the edge of the box dim has been reached (i.e. gotten to the most right and the most bottom)
	
	//output to VGA adapter: note that this module already contains an address translator... but may need to remake depending 
	//on img size!
	output[xSz-1:0] xOut;
	output[ySz-1:0] yOut;
	output[colSz-1:0] colOut;
	
	//assign to red arbitrarily for now
	assign colOut = 3'b100;
	
	output reg doneNE_reg;//store whether or not northeast part of box is done
	
	reg[xSz-1:0] xCount;
	reg[ySz-1:0] yCount;
	
	//instantiate the x counter
	always@(posedge clk) begin
			if(!resetn)
				xCount <= 0;
			else if(ld_x)
				xCount <= xLeft;
			else if(countXEn)
				xCount <= xCount + 1'b1;			
	end
	
	//has the x edge been reached?
	assign xEdge = (xCount == xRight);
	
	//instantiate the y counter
	always@(posedge clk) begin
			if(!resetn)
				yCount <= 0;
			else if(ld_y)
				yCount <= yTop - 1'b1;//top is a white pix
			else if(countYEn)
				yCount <= yCount + 1'b1;			
	end
	
	assign xOut = xCount;
	
	//register for northeast value
	always@(posedge clk) begin
		if(!resetn)
			doneNE_reg <= 0;
		else if(doneNE == 1)
			doneNE_reg <= 1;
	end
	
	//has the y edge been reached?
	assign yEdge = (yCount == yBottom);
	
	assign yOut = yCount;
	
	
	

endmodule

//note that box is drawn in two phases:
/*
	Phase 1: draw north and east sides. Increment x and draw each time, keeping y constant, then increment y and draw each time
	keeping x constant
	Phase 2: draw the west and south sides. Increment y and draw each time, keeping x constant, then increment x and draw each time
	keeping y constant
*/
module drawControl(input clk, xEdge, yEdge, doneNE_reg, goDraw, output reg countXEn, countYEn, doneNE, ld_x, ld_y, plotEn, resetn, output doneDraw);

	reg [3:0] current_state, next_state; 
	
	reg doneDraw_DL, doneDraw_s; //delay and signal for pulsing
    
   localparam   START_DRAW = 4'd0,
					 STORE_X = 4'd1,
					 STORE_Y  = 4'd2,
					 INCR_X = 4'd3,
					 INCR_Y  = 4'd4,
					 DRAW_HOR = 4'd5,
					 DRAW_VERT = 4'd6,
					 DONE_NE = 4'd7,
					 DONE_DRAW = 4'd8;
	
	//next state logic
	always@(*)
	begin: state_table
		case (current_state)
		START_DRAW: begin
			if(goDraw)
				next_state = STORE_X;
			else
				next_state = START_DRAW;
			end
		STORE_X: next_state = STORE_Y;
		STORE_Y: begin
			if(!doneNE_reg)//has the northeast phase been completed?
				next_state = DRAW_HOR;
			else
				next_state = DRAW_VERT;
			end
		DRAW_HOR: begin
			if(xEdge == 0)
				next_state = INCR_X;
			else if(xEdge == 1 && doneNE_reg == 0)
				next_state = DRAW_VERT;
			else//if xEdge is not zero and doneNE_reg is not 0, completed south side, last side to complete
				next_state = DONE_DRAW;
			end
		INCR_X: next_state = DRAW_HOR;
		DRAW_VERT: begin
			if(yEdge == 0)
				next_state = INCR_Y;
			else if(yEdge == 1 && doneNE_reg == 0)
				next_state = DONE_NE;
			else//if yEdge is not zero and doneNE_reg is not 0, completed west side, one more side to complete
				next_state = DRAW_HOR;
			end
		INCR_Y: next_state = DRAW_VERT;
		DONE_NE: next_state = STORE_X;
		DONE_DRAW: begin
			if(goDraw)//wait at DONE_DRAW until told to start drawing again
				next_state = START_DRAW;
			else
				next_state = DONE_DRAW;
			end
		default: next_state = START_DRAW;
		endcase
	end
	
	//output logic/datapath control
	always@(*)
	begin: enable_signals
		ld_x = 1'b0;
		ld_y = 1'b0;
		countXEn = 1'b0;
		countYEn = 1'b0;
		doneNE = 1'b0;
		doneDraw_s = 1'b0;
		plotEn = 1'b0;
		resetn = 1'b1;
		
		case(current_state)
			START_DRAW: begin
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
			DRAW_HOR: begin
				plotEn = 1'b1;
			end
			DRAW_VERT: begin 
				plotEn = 1'b1;
			end
			DONE_NE: begin
				doneNE = 1'b1;
			end
			DONE_DRAW: begin
				doneDraw_s = 1'b1;
			end
		
		endcase
	end
	
	//current state registers
	always@(posedge clk) begin
		if(goDraw)//add another resetn?
			current_state <= START_DRAW;
		else
			current_state <= next_state;
   end

	//for pulses!
	assign doneDraw = (!doneDraw_DL) && (doneDraw_s);
	
	always@(posedge clk) begin
		if(doneDraw_s)
			doneDraw_DL <= 1'b1;
		else
			doneDraw_DL <= 0;
	
	end


endmodule

