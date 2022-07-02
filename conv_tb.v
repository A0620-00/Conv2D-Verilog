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

module conv_tb;

    parameter AW = 14;  //address width
    parameter BW = 8;  //bit width
    parameter CH = 3;  //channel nums
    parameter DW = 72; //data width
    parameter DH = 128; //data height
    parameter WW = 3;  //weight width
    parameter WH = 3;  //weight height
    parameter SW = 1;  //stride width
    parameter SH = 1;  //stride height
    parameter PD = 1;  //padding enable
    parameter PN = 1;  //parallel number
    
    parameter T = 10;
    
    reg clk;
    reg rst;
    
    initial
    begin
        clk = 0;
        rst = 0;
    end
    
    always #(T / 2) clk = ~clk;
    
    reg  signed [(BW - 1) : 0]      r_weight[(WW * WH - 1) : 0];
    reg                             i_data_valid  ;
    reg                             i_data_last   ;
    reg         [(CH * BW - 1) : 0] i_data        ;
    reg                             i_weight_valid;
    reg                             i_weight_last ;
    reg         [(BW - 1) : 0]      i_weight      ;
    reg                             i_bias_valid  ;
    reg  signed [(BW - 1) : 0]      i_bias        ;
    wire                            o_data_valid  ;
    wire                            o_data_last   ;
    wire        [(BW - 1) : 0]      o_data        ;
    
    reg         [15 : 0]            i_data_cnt    ;
    reg         [15 : 0]            i_weight_cnt  ;
    
    integer                         fi, fo        ;
    
    initial fi = $fopen("pic.txt", "r");
    initial fo = $fopen("conv.txt", "w");
    
    initial
    begin
        i_data_valid    = 0;
        i_data_last     = 0;
        i_data          = 0;
        i_weight_valid  = 0;
        i_weight_last   = 0;
        i_weight        = 0;
        i_bias_valid    = 0;
        i_bias          = 0;
        i_data_cnt      = 0;
        i_weight_cnt    = 0;
        r_weight[0]     = -1;
        r_weight[1]     = -1;
        r_weight[2]     = -1;
        r_weight[3]     = -1;
        r_weight[4]     = 8;
        r_weight[5]     = -1;
        r_weight[6]     = -1;
        r_weight[7]     = -1;
        r_weight[8]     = -1;
    end
    
    initial
    begin
        wait(i_data_last);
        wait(!i_data_last);
        $fclose(fi);
        wait(o_data_last);
        wait(!o_data_last);
        $fclose(fo);
    end
    
    always @(posedge clk)
    begin
        if(o_data_valid)
            $fwrite(fo, "%d\n", o_data);
    end
    
    always @(posedge clk)
    begin
        if(i_data_cnt < (DW * DH - 1))
        begin
            i_data_valid <= 1;
            i_data_last <= 0;
            $fscanf(fi, "%d", i_data); //i_data <= ($random % (1 << (BW - 1)));
            i_data_cnt <= i_data_cnt + 1;
        end
        else if(i_data_cnt == (DW * DH - 1))
        begin
            i_data_valid <= 1;
            i_data_last <= 1;
            $fscanf(fi, "%d", i_data); //i_data <= ($random % (1 << (BW - 1)));
            i_data_cnt <= i_data_cnt + 1;
        end
        else
        begin
            i_data_valid <= 0;
            i_data_last <= 0;
            i_data <= 0;
            i_data_cnt <= i_data_cnt;
        end
    end
    
    always @(posedge clk)
    begin
        if(i_weight_cnt < (WW * WH - 1))
        begin
            i_weight_valid <= 1;
            i_weight_last <= 0;
            i_weight <= r_weight[i_weight_cnt];
            i_weight_cnt <= i_weight_cnt + 1;
        end
        else if(i_weight_cnt == (WW * WH - 1))
        begin
            i_weight_valid <= 1;
            i_weight_last <= 1;
            i_weight <= r_weight[i_weight_cnt];
            i_weight_cnt <= i_weight_cnt + 1;
        end
        else
        begin
            i_weight_valid <= 0;
            i_weight_last <= 0;
            i_weight <= 0;
            i_weight_cnt <= i_weight_cnt;
        end
    end
    
    conv_img
    #(
        .AW(AW),
        .BW(BW),
        .CH(CH),
        .DW(DW),
        .DH(DH),
        .WW(WW),
        .WH(WH),
        .SW(SW),
        .SH(SH),
        .PD(PD),
        .PN(PN)
    ) conv_img_i
    (
        .i_clk         (clk           ),
        .i_rst         (rst           ),
        .i_data_valid  (i_data_valid  ),
        .i_data_last   (i_data_last   ),
        .i_data        (i_data        ),
        .i_weight_valid(i_weight_valid),
        .i_weight_last (i_weight_last ),
        .i_weight      (i_weight      ),
        .i_bias_valid  (i_bias_valid  ),
        .i_bias        (i_bias        ),
        .o_data_valid  (o_data_valid  ),
        .o_data_last   (o_data_last   ),
        .o_data        (o_data        )
    );
    
endmodule