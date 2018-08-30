module dut(clk, input_a, input_b, output_, mode, rst);

input wire clk, mode, rst; //mode 1 is and, mode 2 is or
input wire [7:0] input_a;
input wire [7:0] input_b;

output reg [7:0] output_;

always @(posedge clk)
begin
	if(~rst) 
		output_ <= 8'b0;
	else
		case(mode)
			1'b0: output_ <= input_a & input_b;
			1'b1: output_ <= input_a | input_b;
			default: output_ <= 8'bxxxxxxxx;
		endcase
end

endmodule
