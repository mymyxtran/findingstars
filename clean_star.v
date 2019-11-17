`timescale 1ns/1ns

module clean_star();

endmodule

module cleanDataPath(xLeft, xRight, yTop, yBottom, countXEn, countYEn, ld_x, ld_y, clk, resetn,
							xEdge, yEdge, xOut, yOut, colOut);

	//contants; depend on image size and colour res
	parameter xSz = 3;
	parameter ySz = 3;
	parameter colSz = 3;
	
	//these define the dimensions of the box
	input[xSz-1:0] xLeft, xRight;
	input[ySz-1:0] yTop, yBottom;
	
	input clk, resetn;
	
	input ld_x, ld_y; //parallel load for counters
	
	input countXEn, countYEn;
	
	output xEdge, yEdge;//are high if the edge of the box dim has been reached (i.e. gotten to the most right and the most bottom)
	
	//output to VGA adapter: note that this module already contains an address translator... but may need to remake depending 
	//on img size!
	output[xSz-1:0] xOut;
	output[ySz-1:0] yOut;
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
	
	assign xOut = xCount;
	
	//has the y edge been reached?
	assign yEdge = (yCount == yBottom);
	
	assign yOut = yCount;

endmodule


module cleanControl(input clk, resetn, xEdge, yEdge, goClean, output reg countXEn, countYEn, ld_x, ld_y, doneClean, wrEn);

	reg [3:0] current_state, next_state; 
    
   localparam   RESET = 4'd0,
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
		RESET: next_state = DONE_CLEAN;
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
		doneClean = 1'b0;
		wrEn = 1'b0;
		
		case(current_state)
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
				doneClean = 1'b1;
			end
		
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

