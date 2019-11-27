/* This v file has the mdoules find_Right, control_R, find_Left, control_L, and a 
 * top-level module << test >> which enables finding the left and right edge of a shape to 
 * happen at the same time. */

/* 
	> need clock
	> external reset 
	> mostTop, mostBottom and TopandBottomFound are wires COMING from mapTopandBottom.v
	> mostLeft, mostRight, rightFound, leftFound are wire GOING to clean/draw.v 
	mapTopandBottomFound map_TB( clk, starFound, xIn, yIn, mostBottom, mostTop, TopandBottomFound); 
*/

module mapRight(clk, goMapColumnsR, mostTop, mostBottom, midPix, mostRight,  rightFound);
	
	parameter xSz = 8;
	parameter ySz = 7;

	input clk, goMapColumnsR;
	input [ySz-1:0]mostTop;
	input [ySz-1:0]mostBottom;
	input [xSz-1:0] midPix; // must be 1 larger 
	output [xSz-1:0] mostRight;
	output rightFound;
					
	wire  R_ld_x, R_ld_y, resetnR, R_countXEn, R_countYEn, rightEdgeReached, doneR;  // wires used by the find_Right
	
	find_Right r1(		//inputs
				.ld_x(R_ld_x), 
				.ld_y(R_ld_y), 
				.midPix(midPix), 
				.mostBottom(mostBottom),
				.mostTop(mostTop),
				.countXEn(R_countXEn), 
				.countYEn(R_countYEn), 
				.clk(clk), 
				.resetn(resetnR), 
		
				// outputs
				.doneR(doneR),
				.rightEdgeReached(rightEdgeReached), 
				.mostRight(mostRight)
			); 
	
	control_Right cR(	// inputs
				.rightEdgeReached(rightEdgeReached),
				.doneR(doneR), 
				.clk(clk), 
				.goMapColumnsR(goMapColumnsR),
		
				// outputs
				.ld_x(R_ld_x), 
				.ld_y(R_ld_y),
				.countXEn(R_countXEn),
				.countYEn(R_countYEn),
				.resetn(resetnR),
				.rightFound(rightFound)
			);
	
endmodule

module mapLeft(clk, TopandBottomFound,mostTop, mostBottom, midPix,  mostLeft, leftFound);
	parameter xSz = 8;
	parameter ySz = 7;

	input clk, TopandBottomFound;
	input [ySz-1:0]mostTop;
	input [ySz-1:0]mostBottom;
	input [xSz-1:0] midPix; // must be 1 larger 
	output [xSz-1:0] mostLeft;
	output leftFound;		
			
	
wire L_ld_x, L_ld_y, L_countXEn, L_countYEn, leftEdgeReached, doneL, resetnL;	// wires used by the find_Left
	
	find_Left l1(		//inputs
				.ld_x(L_ld_x), 
				.ld_y(L_ld_y), 
				.midPix(midPix), 
				.mostBottom(mostBottom),
				.mostTop(mostTop),
				.countXEn(L_countXEn), 
				.countYEn(L_countYEn), 
				.clk(clk), 
				.resetn(resetnL), 
		
				// outputs
				.doneL(doneL),
				.leftEdgeReached(leftEdgeReached), 
				.mostLeft(mostLeft)
			); 
	
	control_Left cL(	// inputs
				.leftEdgeReached(leftEdgeReached),
				.doneL(doneL), 
				.clk(clk), 
				.TopandBottomFound(TopandBottomFound),
		
				// outputs
				.ld_x(L_ld_x), 
				.ld_y(L_ld_y),
				.countXEn(L_countXEn),
				.countYEn(L_countYEn),
				.resetn(resetnL),
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
	
	// Depends on image size 
	parameter xSz = 8;
	parameter ySz = 7;
	parameter addrSz = 15;
	parameter colSz = 3;

	// Size of Image 
	parameter x_resolution = 8'd160;

	// set the threshold for pixel value
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
	output reg [xSz-1:0] mostRight;
	
	//output wires for counters
	reg[xSz-1:0] xCount; 
	reg[ySz-1:0] yCount;
	
	//address wire from translator
	wire[addrSz-1:0] addressOut;
	wire[colSz-1:0] pixVal; 
	
	// Signal to control value of mostRight
	wire update_mostRight;
	
	// instantiate the x counter
	always@(posedge clk) begin
	
		if(!resetn) begin
			xCount <= midPix;
		end
		else if(ld_x) begin // After TopandBottom is found or when you move down one row, load in the midpix value.
			xCount <= midPix;	
		end
		else if(countXEn == 1'b1 && rightEdgeReached == 1'b1 ) begin // This is necessary so that you stop the overcounting. 
			xCount <= xCount;
		end
		else if(countXEn) begin
			xCount <= xCount + 1'b1; // Traverse right until the mostRightEdge		
		end
		
	end
		
	// instantiate the y counter
	always@(posedge clk) begin
		if(!resetn)
			yCount <= mostTop;
		else if(ld_y) begin // Initially, when find_LeftandRight begin load in the mosttop value.
			yCount <= mostTop; // start at the most top of the shape
		end
		else if(countYEn) begin
			yCount <= yCount + 1'b1;
		end
	end
	
	// use trans0 and ram0 for access to xCount pixval
	//instantiate address translator // input your x,y coordinates // output is the address you want to access
	vga_address_translator trans0(.x(xCount), .y(yCount), .mem_address(addressOut));

	//instantiate mem block
	ram19200x3_c ram0(.address(addressOut),.q(pixVal), .clock(clk), .wren(1'b0)); // got rid of wrEN signal bc this memory is read only.. but can/should i do this? 

	// Check for a black pixel (edge is reached) after incrementing the xCount by 1	.
	assign rightEdgeReached = (pixVal == THRESHOLD) || (mostRight == x_resolution); 
	
	// Chck if mostRight should be updated
	assign update_mostRight = (mostRight < xCount);
	
	always@(posedge clk) begin
	 // if an edge is reached, check its value is larger than the current mostRight
			if(!resetn)
				mostRight <= midPix;
			else if(update_mostRight) begin // if most right  is less than the current xvalue, change it!
				mostRight <= xCount;
			end
			else begin
				mostRight <=mostRight;
			end
	  
	end

	// This signal stops the datapath, since all calculations are complete.
	assign doneR = (yCount == mostBottom) || (mostRight == x_resolution); 

endmodule 

module control_Right(
		input rightEdgeReached,
		doneR, clk, goMapColumnsR,
		output reg ld_x, ld_y, 
		countXEn,
		countYEn,
		resetn,
		output rightFound
		);

reg rightFound_DL, rightFound_s;	
reg [3:0] current_state, next_state;

localparam		LEFT_FOUND = 4'd0,
			LoadIn = 4'd1,
			INCREMENT_X = 4'd2,
			CHECK_RIGHT = 4'd3,
			RELOAD_MIDPIX = 4'd4,
			INCREMENT_Y = 4'd5,
			RIGHTFOUND = 4'd6,
			WAIT = 4'd7;

always@(*)
begin: state_table
			
	case(current_state)
		WAIT: next_state = goMapColumnsR ? LEFT_FOUND : WAIT;
		LEFT_FOUND: next_state = LoadIn;
		LoadIn: next_state = INCREMENT_X;
		INCREMENT_X: next_state = CHECK_RIGHT;
		
		// nothing changes in this state.
		CHECK_RIGHT: next_state = rightEdgeReached ? RELOAD_MIDPIX : INCREMENT_X; // begin search for most bottom
		
		RELOAD_MIDPIX: next_state = INCREMENT_Y;
		INCREMENT_Y: next_state = doneR ? RIGHTFOUND : INCREMENT_X;
		RIGHTFOUND: next_state = RIGHTFOUND;
		default: next_state = WAIT;
	
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
	rightFound_s =1'b0;
	
	case(current_state)
		LEFT_FOUND: begin
			resetn = 1'b0; // can i use this as a reset?
		end
		LoadIn: begin
			ld_x = 1'b1;
			ld_y = 1'b1;
		end
		INCREMENT_X: begin
			countXEn = 1'b1;
		end
		RELOAD_MIDPIX: begin
			ld_x = 1'b1; // essentially reset x
		end
		INCREMENT_Y: begin
			countYEn = 1'b1;
		end
		RIGHTFOUND: begin
			rightFound_s = 1'b1;
		end
	
	endcase

end

//current state registers
always@(posedge clk) begin
	if(goMapColumnsR)
		current_state <= LEFT_FOUND;
	else
		current_state <= next_state;
end
	
assign rightFound = (!rightFound_DL) && (rightFound_s);

always@(posedge clk) begin
	if(rightFound_s) begin
		rightFound_DL <= 1'b1;
	end
	else begin
		rightFound_DL <= 1'b0;
	end
end
	
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

	parameter xSz = 8;
	parameter ySz = 7;
	parameter addrSz = 15;
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
	output reg [xSz-1:0] mostLeft;
	
	//output wires for counters
	reg[xSz-1:0] xCount;
	reg[ySz-1:0] yCount;
	
	//address wire from translator
	wire[addrSz-1:0] addressOut;

	wire[colSz-1:0] pixVal; 
	wire update_mostLeft;
	
	//instantiate the x counter
	always@(posedge clk) begin
	
		if(!resetn) begin
			xCount <= midPix;
		end
		else if(ld_x) begin // After TopandBottom is found or when you move down one row, load in the midpix value.
			xCount <= midPix;	
		end
		else if(countXEn == 1'b1 && leftEdgeReached ==1'b1 ) begin
			xCount <= xCount;
		end
		else if(countXEn) begin
			xCount <= xCount - 1'd1; // traverse left until the mostLeftEdge		
		end
	end
		
	//instantiate the y counter
	always@(posedge clk) begin
		if(!resetn)
			yCount <= mostTop;
		else if(ld_y) begin // Initially, when find_LeftandRight begin load in the mosttop value.
			yCount <= mostTop; // start at the most top of the shape
		end
		else if(countYEn) begin
			yCount <= yCount + 1'd1;
		end
	end
	
	// use trans0 and ram0 for access to xCount pixval
	//instantiate address translator // input your x,y coordinates // output is the address you want to access
	vga_address_translator trans0(.x(xCount), .y(yCount), .mem_address(addressOut));

	//instantiate mem block
	ram19200x3_c ram0(.address(addressOut),.q(pixVal), .clock(clk), .wren(1'b0)); 

	// Check for a black pixel (edge is reached) after incrementing the xCount by 1	.
	assign leftEdgeReached = (pixVal == THRESHOLD) || (mostLeft == 1'b0); // Edge-case left end of screen is reached
	
	assign update_mostLeft = (mostLeft > xCount); // if most right  is less than the current xvalue, change it!
	
	always@(posedge clk) begin
		if(!resetn) begin
				mostLeft <= midPix;
		end
		else if(update_mostLeft) begin 
				mostLeft <= xCount;
		end
	end
	
	// This signal stops the datapath, since all calculations are complete.
	assign doneL = (yCount == mostBottom) || (mostLeft == 1'b0); 

endmodule 

module control_Left(
		input leftEdgeReached,
		doneL, clk, goMapColumnsL,
		output reg ld_x, ld_y, 
		countXEn,
		countYEn,
		resetn,
		output leftFound
		);
reg leftFound_DL, leftFound_s;
reg [3:0] current_state, next_state;

localparam		GO_MAP_LEFT = 4'd0,
			LoadIn = 4'd1,
			INCREMENT_X = 4'd2,
			CHECK_LEFT = 4'd3,
			RELOAD_MIDPIX =4'd4,
			INCREMENT_Y = 4'd5,
			LEFTFOUND = 4'd6;
			WAIT = 4'd7;

always@(*)
begin: state_table
			
	case(current_state)
		WAIT: next_state = goMapColumnsR ? GO_MAP_LEFT : WAIT;
		
		//Load in your top and bottom values
		GO_MAP_LEFT: next_state = LoadIn;
			
		LoadIn: next_state = INCREMENT_X;
		
		// start x counter
		INCREMENT_X: next_state = CHECK_LEFT; 
		
		//nothing happens. here we look at the value of left edge
		CHECK_LEFT: next_state = leftEdgeReached ? RELOAD_MIDPIX : INCREMENT_X; 
		
		// This state reloads the midPix. Need this, because loading is done after one state.
		RELOAD_MIDPIX: next_state = INCREMENT_Y;
		
		// move down a row
		INCREMENT_Y: next_state = doneL ? LEFTFOUND : INCREMENT_X;
		LEFTFOUND: next_state = LEFTFOUND;
		default: next_state = WAIT;
	
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
	leftFound_s =1'b0;
	
	case(current_state)
		GO_MAP_LEFT: begin
			resetn = 1'b0; // can i use this as a reset?
		end
		LoadIn: begin
			ld_x = 1'b1;
			ld_y = 1'b1;
		end
		INCREMENT_X: begin
			countXEn = 1'b1;
		end
		RELOAD_MIDPIX: begin
			ld_x = 1; // essentially reset x
		end
		INCREMENT_Y: begin
			countYEn = 1'b1;
		end
		LEFTFOUND: begin
			leftFound_s = 1'b1;
		end
	
	endcase

end

//current state registers
always@(posedge clk) begin
	if(goMapColumnsL)
		current_state <= GO_MAP_LEFT;
	else
		current_state <= next_state;
end

assign leftFound = (!leftFound_DL) && (leftFound_s);

always@(posedge clk) begin
	if(leftFound_s) begin
		leftFound_DL <= 1'b1;
	end
	else begin
		leftFound_DL <= 1'b0;
	end
end
	
endmodule
