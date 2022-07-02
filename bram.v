////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2022, liuming
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//

module bram
#(
	parameter AW = 16,
	parameter BW = 8,
	parameter DP = 256 * 64
)
(
	input clk,
    input [BW-1:0] din,
    input we,
	input [AW-1:0] wadr,
    input [AW-1:0] radr,
	output [BW-1:0] dout
);
	
	(* ram_style = "block" *)
	reg [BW-1:0] ram [DP-1:0];
	reg [AW-1:0] read_a; 
    
    integer i;
    
    initial
    begin
        for(i = 0; i < DP; i = i + 1)
            ram[i] = 0;
    end
    
	always @(posedge clk) begin
		if (we) begin
			ram [wadr] <= din;
		end
		read_a <= radr;
	end
	
	assign dout = ram [read_a];
	
	
endmodule