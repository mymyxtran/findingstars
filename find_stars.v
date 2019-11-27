`timescale 1ns/1ns

module find_stars
	( SW, CLOCK_50,
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
	input[1:0] SW;
	input CLOCK_50;
	
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	parameter xSz = 8;
	parameter ySz = 7;
	parameter colSz = 3;
	
	wire starFound;
	wire[3:0] pixVal;
	wire wrEn;
	wire[14:0] finalAddress;
	wire[14:0] addressRead;
	wire[14:0] addressWrite;
	wire[3:0] colIn;
	
	wire doneClean, goClean;
	wire doneDraw, goDraw;
	wire goMapRows, topBottomFound;
	wire goMapColumnsR, goMapColumnsL, leftFound, rightFound;
	
	wire[xSz-1:0] xCount;
	wire[ySz-1:0] yCount; 
	
	wire[xSz-1:0] xIn, midPix;
	wire[ySz-1:0] yIn; 
	wire[xSz-1:0] xLeft, xRight;
	wire[ySz-1:0] yTop, yBottom;
	
	//connections for going from draw_box to vga_adapter
	wire[xSz-1:0] x_for_vga;
	wire[ySz-1:0] y_for_vga;
	wire[colSz-1:0] col_for_vga;
	wire plotEn;
	

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter vga0(.resetn(SW[0]), .clock(CLOCK_50), .x(x_for_vga), .y(y_for_vga), .plot(plotEn), .colour(col_for_vga),
							.VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_BLANK(VGA_BLANK_N), .VGA_SYNC(VGA_SYNC_N), .VGA_CLK(VGA_CLK));
	 
		defparam vga0.RESOLUTION = "160x120";
		defparam vga0.MONOCHROME = "FALSE";
		defparam vga0.BITS_PER_COLOUR_CHANNEL = 1;
		defparam vga0.BACKGROUND_IMAGE = "oneStar160x120.mif";
	
	
	
	master yes_master(.xLeft(xLeft), .xRight(xRight), .yTop(yTop), .yBottom(yBottom),
			 .GO(SW[1]), .clk(CLOCK_50), .resetn(SW[0]), .doneDraw(doneDraw), .topBottomFound(topBottomFound),
			 .leftFound(leftFound), .rightFound(rightFound), .goDraw(goDraw),  
			  .goMapColumnsR(goMapColumnsR), .goMapColumnsL(goMapColumnsL), .goMapRows(goMapRows), .xCount(xCount), .yCount(yCount));

	
	/* > goMapRows COMING FROM state_machine1
	 * xIn, YiN is wire COMING from topDataPath.v 
	 * > yTop, yBottom and topBottomFound are wires GOING to mapLeftandRight.v */
	mapTopandBottom map_TB( .clk(CLOCK_50), .starFound(goMapRows), .xIn(xIn), .yIn(yIn), .mostBottom(yBottom), .mostTop(yTop), .midPix(midPix), .TopandBottomFound(topBottomFound) ); 
	
	/* > yTop, yBottom and midPix are wires COMING from mapTopandBottom.v
	*  > goMapColumns is a start signal from state_machine1
	 * > mostLeft, mostRight, rightFound, leftFound are wire GOING to clean/draw.v */ 
	mapLeftRight map_R( .clk(CLOCK_50), .TopandBottomFound(goMapColumnsR), .mostTop(yTop) , .mostBottom(yBottom) , .midPix(midPix) , .mostRight(xRight)  ,  .rightFound(rightFound) );
	mapLeftRight map_L( .clk(CLOCK_50), .TopandBottomFound(goMapColumnsL), .mostTop(yTop) , .mostBottom(yBottom) , .midPix(midPix) ,  .mostLeft(xLeft) , .leftFound(leftFound) );

	
	draw_box drawTime(.goDraw(goDraw), .xLeft(xLeft), .xRight(xRight), .yTop(yTop), .yBottom(yBottom), 
						.clk(CLOCK_50), .xOut(x_for_vga), .yOut(y_for_vga), .colOut(col_for_vga), .doneDraw(doneDraw), .plotEn(plotEn));



endmodule

module find_stars_no_vga(clk, resetn, start, x_for_vga, y_for_vga, col_for_vga, plotEn);

	parameter xSz = 8;
	parameter ySz = 7;
	parameter colSz = 3;
	
	input clk, resetn, start;

	//connections for going from draw_box to vga_adapter
	output[xSz-1:0] x_for_vga;
	output[ySz-1:0] y_for_vga;
	output[colSz-1:0] col_for_vga;
	output plotEn;

	wire doneDraw, goDraw;
	wire goMapRows, topBottomFound;
	wire goMapColumns, leftFound, rightFound;
	
	wire[xSz-1:0] xCount;
	wire[ySz-1:0] yCount; 
	
	wire[xSz-1:0] midPix;
	wire[xSz-1:0] xLeft, xRight;
	wire[ySz-1:0] yTop, yBottom;
	


	master yes_master(.xLeft(xLeft), .xRight(xRight), .yTop(yTop), .yBottom(yBottom),
			 .GO(start), .clk(clk), .resetn(resetn), .doneDraw(doneDraw), .topBottomFound(topBottomFound),
			 .leftFound(leftFound), .rightFound(rightFound), .goDraw(goDraw),  
			 .goMapColumns(goMapColumns), .goMapRows(goMapRows), .xCount(xCount), .yCount(yCount));

	
	/* > goMapRows COMING FROM state_machine1
	 * xIn, YiN is wire COMING from topDataPath.v 
	 * > yTop, yBottom and topBottomFound are wires GOING to mapLeftandRight.v */
	mapTopandBottom map_TB( .clk(clk), .starFound(goMapRows), .xIn(xCount), .yIn(yCount), .mostBottom(yBottom), .mostTop(yTop), .midPix(midPix), .TopandBottomFound(topBottomFound) ); 
	
	/* > yTop, yBottom and midPix are wires COMING from mapTopandBottom.v
	*  > goMapColumns is a start signal from state_machine1
	 * > mostLeft, mostRight, rightFound, leftFound are wire GOING to clean/draw.v */ 
	mapLeftandRight map_LR( .clk(clk), .TopandBottomFound(goMapColumns), .mostTop(yTop) , .mostBottom(yBottom) , .midPix(midPix) , .mostRight(xRight) ,  .mostLeft(xLeft) ,  .rightFound(rightFound) , .leftFound(leftFound) );

	draw_box drawTime(.goDraw(goDraw), .xLeft(xLeft), .xRight(xRight), .yTop(yTop), .yBottom(yBottom), 
						.clk(clk), .xOut(x_for_vga), .yOut(y_for_vga), .colOut(col_for_vga), .doneDraw(doneDraw), .plotEn(plotEn));

	
endmodule
