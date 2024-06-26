/* 
	> need clock
	> starfound, xIn, YiN is wire COMING from find_star.v 
	> mostTop, mostBottom and TopandBottomFound are wires GOING to mapLeftandRight.v
	mapTopandBottomFound map_TB( clk, starFound, xIn, yIn, mostBottom, mostTop, TopandBottomFound); 
*/
module mapTopandBottom( clk, starFound, xIn, yIn, mostBottom, mostTop, TopandBottomFound);
				
	parameter xSz = 6;
	parameter ySz = 6;
	
	input clk, starFound;
	input [xSz-1:0] xIn;
	input [ySz-1:0] yIn;
	output [ySz-1:0] mostBottom;
	output [ySz-1:0] mostTop;
	output TopandBottomFound;
		
	wire resetn, countXEn, countYEn, pLoad, rightEdgeReached, bottomEdgeReached; 
	wire [xSz-1:0]midPix;
		
	findTopandBottom u1(	 	//inputs
									.clk(clk), 
									.resetn(resetn),
									.countXEn(countXEn), 
									.countYEn(countYEn),  
									.pLoad(pLoad), 
									.xIn(xIn), 
									.yIn(yIn), 
									
									//outputs
									.mostBottom(mostBottom), 
									.mostTop(mostTop), 
									.midPix(midPix),
									.rightEdgeReached(rightEdgeReached),
									.bottomEdgeReached(bottomEdgeReached)
									); 	
								
	controlTopandBottom u5( 	
										//inputs
										.rightEdgeReached(rightEdgeReached),
										.bottomEdgeReached(bottomEdgeReached), 
										.clk(clk),
										.starFound(starFound),
										
										//outputs
										.pLoad(pLoad), 
										.countXEn(countXEn),
										.countYEn(countYEn),
										.resetn(resetn), // used to reset counters in data path
										.TopandBottomFound(TopandBottomFound)); 
									

endmodule

module findTopandBottom(
		pLoad, 
		xIn, 
		yIn, 
		countXEn, 
		countYEn, 
		clk, 
		resetn, // need diff reset signal
		mostBottom,
		mostTop,
		midPix,
		rightEdgeReached,
		bottomEdgeReached
		);  

	parameter xSz = 6;
	parameter ySz = 6;
	parameter addrSz = 12;
	parameter colSz = 3;

	// Size of image 
	parameter y_resolution = 6'd60;
	parameter x_resolution = 6'd60;

	//set the threshold for pixel value
	localparam THRESHOLD = 0;

	input clk, resetn;

	// Enable signals
	input countXEn; 	// used to enable the right x counter 
	input countYEn; //enable for counter y
	input pLoad; 


	output rightEdgeReached;
	output bottomEdgeReached;

	//input x and y coor to load counters if required
	input[xSz-1:0] xIn;
	input[ySz-1:0] yIn;

	output [ySz-1:0] mostBottom; 
	output [ySz-1:0] mostTop; 
	output [xSz-1:0] midPix; // Will be used to calculate right and left most. 

	reg[xSz-1:0] xCount;//output wires for counters
	reg[ySz-1:0] yCount;
		  reg[xSz-1:0] xOriginal; // store inital x value to calculate midpix
	reg[xSz-1:0] yOriginal; // store inital y value to have top most

	wire[addrSz-1:0] addressOut;//address wire from translator
	wire[addrSz-1:0] addressOut_1;

	wire[colSz-1:0] pixVal; 
		wire[colSz-1:0] pixVal_1;
	wire [xSz:0] calc_midPix;
	//instantiate the x counter
	always@(posedge clk) begin
	
		if(!resetn) begin
			xCount <= xIn;
		end
		else if(pLoad) begin // Initally, after the star is found, load in the x coordinate value.
			xCount <= xIn;	
			xOriginal <= xIn;
		end
		else if(countXEn)
			xCount <= xCount + 1'd1;

		
	end
	
	// This value will not change once we start looking for the most bottom, since xCount and xOriginal do not change.
	assign calc_midPix = (xCount + xOriginal) >> 1; // using the right most value and the orignal calculate the midpix
	assign midPix = calc_midPix[xSz-1:0];
	//instantiate the y counter
	always@(posedge clk) begin
		if(!resetn)
			yCount <= yIn;
		else if(pLoad) begin //initally, after the star is found, load in the y coordinate value.
			yCount <= yIn;
			yOriginal <= yIn;
		end
		else if(countYEn)
			yCount <= yCount + 1'd1;	
	end
	
	// use trans0 and ram0 for access to xCount pixval
	//instantiate address translator // input your x,y coordinates // output is the address you want to access
	address_translator trans0(.x(xCount), .y(yCount), .mem_address(addressOut));
	//instantiate mem block
	ram3600x3_sq ram0(.address(addressOut),.q(pixVal), .clock(clk), .wren(1'b0)); // got rid of wrEN signal bc this memory is read only.. but can/should i do this? 
	// Check for a black pixel (edge is reached) after incrementing the xCount by 1	. // Edge-case, the end (right-end) of the screen is reached
	assign rightEdgeReached = (pixVal == THRESHOLD) || (xCount == x_resolution); // This signal indicates when to start mostBottom traversal. 
	
	
	// use trans1 and ram1 for to find bottom and top most
	address_translator trans1(.x(midPix), .y(yCount), .mem_address(addressOut_1));
	ram3600x3_sq ram1(.address(addressOut_1),.q(pixVal_1), .clock(clk), .wren(1'b0)); // got rid of wrEN signal bc this memory is read only.. but can/should i do this? 
	
	// This signal stop datapath, since all calculations are complete.
	assign bottomEdgeReached = ((pixVal_1 == THRESHOLD) || (mostBottom == y_resolution)); // Edge-case, the end (bottom) of the screen is reached. 

	// Once bottomEdge is found, mostBottom will have the highest yvalue coordinate stored, yCount.
	assign mostBottom = yCount;
	
	// Output this for easier input into next fsm.
	assign mostTop = yOriginal;
	
endmodule 

module controlTopandBottom(
		input rightEdgeReached,
		bottomEdgeReached, clk, starFound,
		output reg pLoad, 
		countXEn,
		countYEn,
		resetn, output
		TopandBottomFound);
		
reg TopandBottomFound_s;		
reg TopandBottomFound_DL;
	
reg [3:0] current_state, next_state;

localparam	STARFOUND = 4'd0,
			LoadIn = 4'd1,
			INCREMENT_X = 4'd2,
			INCREMENT_Y = 4'd3,
			CHECK_IF_BOTTOMREACHED = 4'd4,
			DONESEARCH = 4'd5;

always@(*)
begin: state_table
			
	case(current_state)
		STARFOUND: next_state = LoadIn;
		LoadIn: next_state = INCREMENT_X;
		
		INCREMENT_X: next_state = rightEdgeReached ? INCREMENT_Y : INCREMENT_X; // begin search for most bottom
		
		INCREMENT_Y: next_state = CHECK_IF_BOTTOMREACHED;
		CHECK_IF_BOTTOMREACHED: next_state = bottomEdgeReached ? DONESEARCH : INCREMENT_Y;
		DONESEARCH: next_state = DONESEARCH;
		default: next_state = STARFOUND;
	
	endcase

end


//output logic/datapath control
always@(*)
begin: enable_signals
	pLoad = 1'b0;
	countXEn = 1'b0;
	countYEn = 1'b0;
	resetn = 1'b1;
	TopandBottomFound_s =1'b0;
	
	case(current_state)
		STARFOUND: begin
			resetn = 1'b0; // can i use this as a reset?
		end
		LoadIn: begin
			pLoad = 1'b1;
		end
		INCREMENT_X: begin
			countXEn = 1'b1;
		end
		INCREMENT_Y: begin
			countYEn = 1'b1;
		end
		DONESEARCH: begin
			TopandBottomFound_s = 1'b1;
		end
	
	endcase

end

//current state registers
always@(posedge clk) begin
	if(starFound)
		current_state <= STARFOUND;
	else
		current_state <= next_state;
end
	
assign TopandBottomFound = (!TopandBottomFound_DL) && (TopandBottomFound_s);

always@(posedge clk) begin
	if(TopandBottomFound_s) begin
		TopandBottomFound_DL <= 1'b1;
	end
	else begin
		TopandBottomFound_DL <= 1'b0;
	end
end

endmodule

module address_translator(x, y, mem_address);
	
	// 60 x 60
	input [5:0] x; 
	input [5:0] y;	
	output [11:0] mem_address;
	
	/* The basic formula is address = y*WIDTH + x;
	 * For 320x240 resolution we can write 320 as (256 + 64). Memory address becomes
	 * (y*256) + (y*64) + x;
	 * This simplifies multiplication a simple shift and add operation.
	 * A leading 0 bit is added to each operand to ensure that they are treated as unsigned
	 * inputs. By default the use a '+' operator will generate a signed adder.
	 * Similarly, for 160x120 resolution we write 160 as 128+32.
	 */
	 //width = 60 = 32 + 16 + 8 + 4
	 //so address = (y*32) + (y*16)  + (y*8)+ (y*4)+ x
	 assign mem_address = ({1'b0, y, 5'd0} + {1'b0, y, 4'd0} +{1'b0, y, 3'd0} + {1'b0, y, 2'd0} + {1'b0,x});
	

endmodule
