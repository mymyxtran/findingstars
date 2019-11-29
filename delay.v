`timescale 1ns/1ns


module delay(input goDelay, clk, resetn, output doneDelay);

	wire[26:0] delayOut;
	
	wire doneDelay_s;
	reg doneDelay_DL;
	 
	//instantiate delay counter wait=22'd4166666
	frameCounter f0(.clk(clk), .resetn(resetn), .R(27'd2), .count_en(goDelay), .Q(delayOut));
	 
	assign doneDelay_s = (delayOut == 0) ? 1'b1 : 1'b0;
	
	always@(posedge clk) begin
	if(doneDelay_s) begin
		doneDelay_DL <= 1'b1;
	end
	else begin
		doneDelay_DL <= 1'b0;
	end
	end
	
assign doneDelay = (!doneDelay_DL) && (doneDelay_s);

endmodule

	

module frameCounter(clk, resetn, R, Q, count_en);

	parameter n = 27;
	
	input clk, resetn, count_en;
	input[n-1:0] R;

	output reg[n-1:0] Q;
	
	always@(posedge clk, negedge resetn) begin
		if(resetn == 0)
			Q <= R;
		else if (Q == 0) begin
			Q <= R;
			end
		else if(count_en)
			Q <= Q - 1'b1;
	
	end


endmodule

