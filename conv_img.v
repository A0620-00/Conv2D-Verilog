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
`timescale 1ns / 1ps

module conv_img
#(
    parameter AW = 14,  //address width
    parameter BW = 8,  //bit width
    parameter CH = 3,  //channel nums
    parameter DW = 64, //data width
    parameter DH = 64, //data height
    parameter WW = 3,  //weight width
    parameter WH = 3,  //weight height
    parameter SW = 1,  //stride width
    parameter SH = 1,  //stride height
    parameter PD = 1,  //padding enable
    parameter PN = 1  //parallel number
)
(
    input  wire                     i_clk         ,
    input  wire                     i_rst         ,
    input  wire                     i_data_valid  ,
    input  wire                     i_data_last   ,
    input  wire [(CH * BW - 1) : 0] i_data        ,
    input  wire                     i_weight_valid,
    input  wire                     i_weight_last ,
    input  wire [(BW - 1) : 0]      i_weight      ,
    input  wire                     i_bias_valid  ,
    input  wire [(BW - 1) : 0]      i_bias        ,
    output wire                     o_data_valid  ,
    output wire                     o_data_last   ,
    output wire [(BW - 1) : 0]      o_data
);
    
    localparam CW = BW * 2 + WW * WH;
    
    wire        [(CH - 1) : 0]     w_data_valid        ;
    wire        [(CH - 1) : 0]     w_data_last         ;
    wire signed [(CW - 1) : 0]     w_data[(CH - 1) : 0];
    reg         [1 : 0]            r_data_valid        ;
    reg         [1 : 0]            r_data_last         ;
    reg  signed [(CW - 1) : 0]     r_data[1 : 0]       ;
    
    always @(posedge i_clk)
    begin
        r_data_valid <= {r_data_valid[0], w_data_valid[0]};
        r_data_last  <= {r_data_last[0], w_data_last[0]};
    end
    
    assign o_data_valid = r_data_valid[1];
    assign o_data_last  = r_data_last[1];
    assign o_data       = r_data[1];
    
    always @(posedge i_clk)
    begin
        r_data[0] <= w_data[0] + w_data[1] + w_data[2] + i_bias;
        if(r_data[0] < 0)
            r_data[1] <= 0;
        else if(r_data[0] > (8'hff * 3))
            r_data[1] <= 8'hff;
        else
            r_data[1] <= (r_data[0] / 3);
    end
    
    
    genvar x;
    
    generate
    begin
        for(x = 0; x < CH; x = x + 1)
        begin
            conv2d
            #(
                .AW            (AW),
                .BW            (BW),
                .DW            (DW),
                .DH            (DH),
                .WW            (WW),
                .WH            (WH),
                .SW            (SW),
                .SH            (SH),
                .PD            (PD),
                .PN            (PN)
            ) conv2d_i
            (
                .i_clk         (i_clk                                ),
                .i_rst         (i_rst                                ),
                .i_data_valid  (i_data_valid                         ),
                .i_data_last   (i_data_last                          ),
                .i_data        (i_data[((x + 1) * BW - 1) : (x * BW)]),
                .i_weight_valid(i_weight_valid                       ),
                .i_weight_last (i_weight_last                        ),
                .i_weight      (i_weight                             ),
                .o_data_valid  (w_data_valid[x]                      ),
                .o_data_last   (w_data_last[x]                       ),
                .o_data        (w_data[x]                            )
            );
        end
    end
    endgenerate

endmodule