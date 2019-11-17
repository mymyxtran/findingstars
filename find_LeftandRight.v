/* This v file has the mdoules find_Right, control_R, find_Left, control_L, and a 
 * top-level module << test >> which enables finding the left and right edge of a shape to 
 * happen at the same time. */

/* Note: The TopandBottomFound signal needs to go high then low, to start the fsm initally... So that it knows what state to be in first.
 *       Or is this unnecessary? */
module test(
	input clk, TopandBottomFound, input [2:0]mostTop, input [2:0]mostBottom, input [2:0] midPix, 
	output [2:0] mostRight, output [2:0] mostLeft, output rightFound, output leftFound);				
				
	wire resetn, ld_x, ld_y; // wires used by all modules
	
	wire  R_countXEn, R_countYEn, rightEdgeReached, doneR;  // wires used by the find_Right
	
	find_Right r1(		//inputs
				.ld_x(ld_x), 
				.ld_y(ld_y), 
				.midPix(midPix), 
				.mostBottom(mostBottom),
				.mostTop(mostTop),
				.countXEn(R_countXEn), 
				.countYEn(R_countYEn), 
				.clk(clk), 
				.resetn(resetn), 
		
				// outputs
				.doneR(doneR),
				.rightEdgeReached(rightEdgeReached), 
				.mostRight(mostRight)
			); 
	
	control_Right cR(	// inputs
				.rightEdgeReached(rightEdgeReached),
				.doneR(doneR), 
				.clk(clk), 
				.TopandBottomFound(TopandBottomFound),
		
				// outputs
				.ld_x(ld_x), 
				.ld_y(ld_y),
				.countXEn(R_countXEn),
				.countYEn(R_countYEn),
				.resetn(resetn),
				.rightFound(rightFound)
			);
	
	wire L_countXEn, L_countYEn, leftEdgeReached, doneL;	// wires used by the find_Left
	
	find_Left l1(		//inputs
				.ld_x(ld_x), 
				.ld_y(ld_y), 
				.midPix(midPix), 
				.mostBottom(mostBottom),
				.mostTop(mostTop),
				.countXEn(L_countXEn), 
				.countYEn(L_countYEn), 
				.clk(clk), 
				.resetn(resetn), 
		
				// outputs
				.doneL(doneL),
				.leftEdgeReached(leftEdgeReached), 
				.mostRight(mostRight)
			); 
	
	control_Left cL(	// inputs
				.leftEdgeReached(leftEdgeReached),
				.doneR(doneR), 
				.clk(clk), 
				.TopandBottomFound(TopandBottomFound),
		
				// outputs
				.ld_x(ld_x), 
				.ld_y(ld_y),
				.countXEn(L_countXEn),
				.countYEn(L_countYEn),
				.resetn(resetn),
				.leftFound(leftFound)
			);

endmodule

module find_Right(
		ld_x, ld_y, 
		midPix, 
		mostBottom,
		mostTop,
		countXEn, 
		countYEn, 
		clk, 
		resetn, 
		doneR,
		rightEdgeReached, 
		mostRight
		);  

	parameter xSz = 3;
	parameter ySz = 3;
	parameter addrSz = 6;
	parameter colSz = 3;

	//set the threshold for pixel value
	localparam THRESHOLD = 0;

	input clk, resetn;

	// Enable signals
	input countXEn; // used to enable the right x counter 
	input countYEn; //enable for counter y
	input ld_x; 
	input ld_y;

	// get input values from the findTopandBottom module
	input [ySz-1:0] mostBottom; 
	input [ySz-1:0] mostTop; 
	input [xSz-1:0] midPix; 

	// output signals for control
	output rightEdgeReached;
	output doneR;
	output reg [ySz-1:0] mostRight;
	
	reg[xSz-1:0] xCount;//output wires for counters
	reg[ySz-1:0] yCount;
	
	wire[addrSz-1:0] addressOut;//address wire from translator

	wire[colSz-1:0] pixVal; 
	
	//instantiate the x counter
	always@(posedge clk) begin
	
		if(!resetn) begin
			xCount <= 0;
		end
		else if(ld_x) begin // After TopandBottom is found or when you move down one row, load in the midpix value.
			xCount <= midPix;	
		end
		else if(countXEn) begin
			xCount <= xCount + 1'd1; // traverse right until the mostRightEdge		
		end
	end
		
	//instantiate the y counter
	always@(posedge clk) begin
		if(!resetn)
			yCount <= 0;
		else if(ld_y) begin // Initially, when find_LeftandRight begin load in the mosttop value.
			yCount <= mostTop; // start at the most top of the shape
		end
		else if(countYEn) begin
			yCount <= yCount + 1'd1;
		end
	end
	
	// use trans0 and ram0 for access to xCount pixval
	//instantiate address translator // input your x,y coordinates // output is the address you want to access
	address_translator trans0(.x(xCount), .y(yCount), .mem_address(addressOut));

	//instantiate mem block
	ram36x3_1 ram0(.address(addressOut),.q(pixVal), .clock(clk), .wren(1'b0)); // got rid of wrEN signal bc this memory is read only.. but can/should i do this? 

	// Check for a black pixel (edge is reached) after incrementing the xCount by 1	.
	assign rightEdgeReached = (pixVal == THRESHOLD); // 
	
	always@(posedge clk) begin
		if(rightEdgeReached) begin // if an edge is reached, check its value is larger than the current mostRight
			if(mostRight < xCount) begin // if most right  is less than the current xvalue, change it!
				mostRight <= xCount;
			end
		end
	end
	
	// This signal stop datapath, since all calculations are complete.
	assign doneR = (yCount == mostBottom); 

endmodule 

module control_Right(
		input rightEdgeReached,
		doneR, clk, TopandBottomFound,
		output reg ld_x, ld_y, 
		countXEn,
		countYEn,
		resetn,
		rightFound
		);
		
reg [3:0] current_state, next_state;

localparam		TOPANDBOTTOMFOUND = 4'd0,
			LoadIn = 4'd1,
			INCREMENT_X = 4'd2,
			INCREMENT_Y = 4'd3,
			RIGHTFOUND = 4'd4;

always@(*)
begin: state_table
			
	case(current_state)
		TOPANDBOTTOMFOUND: next_state = LoadIn;
		LoadIn: next_state = INCREMENT_X;
		INCREMENT_X: next_state = rightEdgeReached ? INCREMENT_Y : INCREMENT_X; // begin search for most bottom
		INCREMENT_Y: next_state = doneR ? RIGHTFOUND : INCREMENT_Y;
		RIGHTFOUND: next_state = RIGHTFOUND;
		default: next_state = TOPANDBOTTOMFOUND;
	
	endcase

end


//output logic/datapath control
always@(*)
begin: enable_signals
	ld_x = 1'b0;
	ld_y = 1'b0;
	countXEn = 1'b0;
	countYEn = 1'b0;
	resetn = 1'b1;
	rightFound =1'b0;
	
	case(current_state)
		TOPANDBOTTOMFOUND: begin
			resetn = 1'b0; // can i use this as a reset?
		end
		LoadIn: begin
			ld_x = 1'b1;
			ld_y = 1'b1;
		end
		INCREMENT_X: begin
			countXEn = 1'b1;
		end
		INCREMENT_Y: begin
			countYEn = 1'b1;
			ld_x = 1; // essentially reset x
		end
		RIGHTFOUND: begin
			rightFound = 1'b1;
		end
	
	endcase

end

//current state registers
always@(posedge clk) begin
	if(TopandBottomFound)
		current_state <= TOPANDBOTTOMFOUND;
	else
		current_state <= next_state;
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

module find_Left(
		ld_x, ld_y, 
		midPix, 
		mostBottom,
		mostTop,
		countXEn, 
		countYEn, 
		clk, 
		resetn, 
		doneL,
		leftEdgeReached, 
		mostLeft
		);  

	parameter xSz = 3;
	parameter ySz = 3;
	parameter addrSz = 6;
	parameter colSz = 3;

	//set the threshold for pixel value
	localparam THRESHOLD = 0;

	input clk, resetn;

	// Enable signals
	input countXEn; // used to enable the right x counter 
	input countYEn; //enable for counter y
	input ld_x; 
	input ld_y;

	// get input values from the findTopandBottom module
	input [ySz-1:0] mostBottom; 
	input [ySz-1:0] mostTop; 
	input [xSz-1:0] midPix; 

	// output signals for control
	output leftEdgeReached;
	output doneL;
	output reg [ySz-1:0] mostLeft;
	
	reg[xSz-1:0] xCount;//output wires for counters
	reg[ySz-1:0] yCount;
	
	wire[addrSz-1:0] addressOut;//address wire from translator

	wire[colSz-1:0] pixVal; 
	
	//instantiate the x counter
	always@(posedge clk) begin
	
		if(!resetn) begin
			xCount <= 0;
		end
		else if(ld_x) begin // After TopandBottom is found or when you move down one row, load in the midpix value.
			xCount <= midPix;	
		end
		else if(countXEn) begin
			xCount <= xCount - 1'd1; // traverse right until the mostRightEdge		
		end
	end
		
	//instantiate the y counter
	always@(posedge clk) begin
		if(!resetn)
			yCount <= 0;
		else if(ld_y) begin // Initially, when find_LeftandRight begin load in the mosttop value.
			yCount <= mostTop; // start at the most top of the shape
		end
		else if(countYEn) begin
			yCount <= yCount + 1'd1;
		end
	end
	
	// use trans0 and ram0 for access to xCount pixval
	//instantiate address translator // input your x,y coordinates // output is the address you want to access
	address_translator trans0(.x(xCount), .y(yCount), .mem_address(addressOut));

	//instantiate mem block
	ram36x3_1 ram0(.address(addressOut),.q(pixVal), .clock(clk), .wren(1'b0)); // got rid of wrEN signal bc this memory is read only.. but can/should i do this? 

	// Check for a black pixel (edge is reached) after incrementing the xCount by 1	.
	assign leftEdgeReached = (pixVal == THRESHOLD); // 
	
	always@(posedge clk) begin
		if(leftEdgeReached) begin // if an edge is reached, check its value is larger than the current mostRight
			if(mostLeft > xCount) begin // if most right  is less than the current xvalue, change it!
				mostLeft <= xCount;
			end
		end
	end
	
	// This signal stop datapath, since all calculations are complete.
	assign doneL = (yCount == mostBottom); 

endmodule 

module control_Left(
		input leftEdgeReached,
		doneL, clk, TopandBottomFound,
		output reg ld_x, ld_y, 
		countXEn,
		countYEn,
		resetn,
		leftFound
		);
		
reg [3:0] current_state, next_state;

localparam		TOPANDBOTTOMFOUND = 4'd0,
			LoadIn = 4'd1,
			INCREMENT_X = 4'd2,
			INCREMENT_Y = 4'd3,
			LEFTFOUND = 4'd4;

always@(*)
begin: state_table
			
	case(current_state)
		TOPANDBOTTOMFOUND: next_state = LoadIn;
		LoadIn: next_state = INCREMENT_X;
		INCREMENT_X: next_state = leftEdgeReached ? INCREMENT_Y : INCREMENT_X; // begin search for most bottom
		INCREMENT_Y: next_state = doneL ? LEFTFOUND : INCREMENT_Y;
		LEFTFOUND: next_state = LEFTFOUND;
		default: next_state = TOPANDBOTTOMFOUND;
	
	endcase

end


//output logic/datapath control
always@(*)
begin: enable_signals
	ld_x = 1'b0;
	ld_y = 1'b0;
	countXEn = 1'b0;
	countYEn = 1'b0;
	resetn = 1'b1;
	leftFound =1'b0;
	
	case(current_state)
		TOPANDBOTTOMFOUND: begin
			resetn = 1'b0; // can i use this as a reset?
		end
		LoadIn: begin
			ld_x = 1'b1;
			ld_y = 1'b1;
		end
		INCREMENT_X: begin
			countXEn = 1'b1;
		end
		INCREMENT_Y: begin
			countYEn = 1'b1;
			ld_x = 1; // essentially reset x
		end
		LEFTFOUND: begin
			leftFound = 1'b1;
		end
	
	endcase

end

//current state registers
always@(posedge clk) begin
	if(TopandBottomFound)
		current_state <= TOPANDBOTTOMFOUND;
	else
		current_state <= next_state;
end

endmodule



