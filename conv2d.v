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

module conv2d
#(
    parameter AW = 14,  //address width
    parameter BW = 8,  //bit width
    parameter DW = 64, //data width
    parameter DH = 64, //data height
    parameter WW = 3,  //weight width
    parameter WH = 3,  //weight height
    parameter SW = 1,  //stride width
    parameter SH = 1,  //stride height
    parameter PD = 1,  //padding enable
    parameter PN = 1,  //parallel number
    parameter CW = BW * 2 + WW * WH
)
(
    input  wire                                    i_clk         ,
    input  wire                                    i_rst         ,
    input  wire                                    i_data_valid  ,
    input  wire                                    i_data_last   ,
    input  wire [(BW - 1) : 0]                     i_data        ,
    input  wire                                    i_weight_valid,
    input  wire                                    i_weight_last ,
    input  wire [(BW - 1) : 0]                     i_weight      ,
    output wire                                    o_data_valid  ,
    output wire                                    o_data_last   ,
    output wire [(CW - 1) : 0]                     o_data
);
    
    //localparam CW    = BW * 2 + WW * WH                          ;
    localparam PD_DW = PD ? (DW + WW - 1) : DW                   ;
    localparam PD_DH = PD ? (DH + WH - 1) : DH                   ;
    localparam SD_DW = (PD_DW - WW) / SW + 1                     ;
    localparam SD_DH = (PD_DH - WH) / SH + 1                     ;
    
    localparam IDLE  = 0                                         ;
    localparam MULT  = 1                                         ;
    localparam ADD   = 2                                         ;
    localparam OUT   = 3                                         ;
    localparam DELAY = 4                                         ;
    
    reg  signed [(BW - 1) : 0]      r_kernel [(WW - 1) : 0][(WH - 1) : 0]             ;
    reg  signed [BW : 0]            r_stride[(PN - 1) : 0][(WW - 1) : 0][(WH - 1) : 0];
    reg  signed [(BW * 2) : 0]      r_mult[(PN - 1) : 0][(WW - 1) : 0][(WH - 1) : 0]  ;
    reg  signed [(CW - 1) : 0]      r_add[1 : 0][(PN - 1) : 0]                        ;
    wire        [(CW * PN - 1) : 0] w_add                                             ;
    reg         [(CW * PN - 1) : 0] r_add_shift                                       ;
    
    reg                             r_data_valid                                      ;
    reg                             r_data_last                                       ;
    reg         [(BW - 1) : 0]      r_data                                            ;
    wire        [(AW - 1) : 0]      w_data_addr                                       ;
    wire        [(BW - 1) : 0]      w_padding[(PN - 1) : 0]                           ;
    reg         [(AW - 1) : 0]      r_padding_addr[(PN - 1) : 0]                      ;
    wire        [(AW - 1) : 0]      w_padding_addr[(PN - 1) : 0]                      ;
    reg                             r_weight_valid                                    ;
    reg                             r_weight_last                                     ;
    reg         [(BW - 1) : 0]      r_weight                                          ;
    reg                             r_conv_start                                      ;
    
    reg         [7 : 0]             r_row_cnt                                         ;
    reg         [7 : 0]             r_col_cnt                                         ;
    reg         [7 : 0]             r_stride_row[1 : 0]                               ;
    reg         [7 : 0]             r_stride_col[1 : 0]                               ;
    reg         [15 : 0]            r_data_cnt                                        ;
    reg         [3 : 0]             r_weight_cnt                                      ;
    reg         [15 : 0]            r_add_cnt                                         ;
    reg         [15 : 0]            r_out_cnt                                         ;
    reg         [7 : 0]             r_data_row                                        ;
    reg         [7 : 0]             r_data_col                                        ;
    reg         [2 : 0]             r_kernel_row                                      ;
    reg         [2 : 0]             r_kernel_col                                      ;
    reg         [7 : 0]             r_mult_row[(PN - 1) : 0][(WW - 1) : 0]            ;
    reg         [7 : 0]             r_mult_col[(PN - 1) : 0][(WH - 1) : 0]            ;
    
    wire        [7 : 0]             w_add_row                                         ;
    wire        [7 : 0]             w_add_col                                         ;
    
    reg                             r_add_valid                                       ;
    reg                             r_add_last                                        ;
    reg         [(PN - 1) : 0]      r_add_shift_valid                                 ;
    reg         [(PN - 1) : 0]      r_add_shift_last                                  ;
    
    reg         [2 : 0]             r_current                                         ;
    reg         [2 : 0]             r_next                                            ;
    
    integer i, j, k;
    genvar x;
    
    initial
    begin
        r_data_valid    = 0;
        r_data_last     = 0;
        r_data          = 0;
        r_weight_valid  = 0;
        r_weight_last   = 0;
        r_weight        = 0;
        r_conv_start    = 0;
        r_row_cnt       = 0;
        r_col_cnt       = 0;
        r_stride_row[0] = 0;
        r_stride_row[1] = 0;
        r_stride_col[0] = 0;
        r_stride_col[1] = 0;
        r_data_cnt      = 0;
        r_weight_cnt    = 0;
        r_add_cnt       = 0;
        r_out_cnt       = 0;
        r_data_row      = 0;
        r_data_col      = 0;
        r_kernel_row    = 0;
        r_kernel_col    = 0;
        r_add_valid     = 0; 
        r_add_last      = 0; 
        r_current       = 0;
        r_next          = 0;
    end
    
    initial
    begin
        for(i = 0; i < WW; i = i + 1)
            for(j = 0; j < WH; j = j + 1)
                r_kernel[i][j] = 0;
        for(i = 0; i < PN; i = i + 1)
        begin
            for(j = 0; j < WW; j = j + 1)
                for(k = 0; k < WH; k = k + 1)
                begin
                    r_stride[i][j][k] = 0;
                    r_mult[i][j][k] = 0;
                end
            r_add[0][i] = 0;
            r_add[1][i] = 0;
            r_padding_addr[i] = 0;
            for(j = 0; j < WW; j = j + 1)
                r_mult_row[i][j] = 0;
            for(j = 0; j < WH; j = j + 1)
                r_mult_col[i][j] = 0;
        end
    end
    
    always @(posedge i_clk)
    begin
        r_data_valid    <= i_data_valid   ;
        r_data_last     <= i_data_last    ;
        r_data          <= i_data         ;
        r_weight_valid  <= i_weight_valid ;
        r_weight_last   <= i_weight_last  ;
        r_weight        <= i_weight       ;
        r_conv_start    <= r_data_last    ;
        r_stride_row[0] <= r_row_cnt      ;
        r_stride_row[1] <= r_stride_row[0];
        r_stride_col[0] <= r_col_cnt      ;
        r_stride_col[1] <= r_stride_col[0];
    end
    
    always @(posedge i_clk)
    begin
        if(PN == 1)
        begin
            r_add_shift_valid <= r_add_valid;
            r_add_shift_last <= r_add_last;
        end
        else
        begin
            r_add_shift_valid <= {r_add_shift_valid[(PN - 2) : 0], r_add_valid};
            r_add_shift_last <= {r_add_shift_last[(PN - 2) : 0], r_add_last};
        end
    end
    
    always @(posedge i_clk)
    begin
        if(r_add_valid)
            r_add_shift <= w_add;
        else
            r_add_shift <= (r_add_shift >>> CW);
    end
    
    assign o_data_valid = |r_add_shift_valid;
    assign o_data_last = r_add_shift_last[PN - 1];
    assign o_data = r_add_shift[(CW - 1) : 0];
    
    always @(posedge i_clk)
    begin
        if(i_rst)
        begin
            r_data_row <= 0;
            r_data_col <= 0;
            r_kernel_row <= 0;
            r_kernel_col <= 0;
            for(i = 0; i < PN; i = i + 1)
            begin
                for(j = 0; j < WW; j = j + 1)
                    r_mult_row[i][j] <= 0;
                for(j = 0; j < WH; j = j + 1)
                    r_mult_col[i][j] <= 0;
            end
        end
        else
        begin
            r_data_row <= (r_data_cnt / DH);
            r_data_col <= (r_data_cnt % DH);
            r_kernel_row <= (r_weight_cnt / WH);
            r_kernel_col <= (r_weight_cnt % WH);
            for(i = 0; i < PN; i = i + 1)
            begin
                for(j = 0; j < WW; j = j + 1)
                    r_mult_row[i][j] <= (j + ((r_out_cnt * PN) / SD_DH) * SW);
                for(j = 0; j < WH; j = j + 1)
                    r_mult_col[i][j] <= (j + (i * SH) + ((r_out_cnt * PN) % SD_DH) * SH);
            end
        end
    end
    
    assign w_data_addr = PD ? ((r_data_row + (WW / 2)) * PD_DH + r_data_col + (WH / 2)) : (r_data_row * PD_DH + r_data_col);
    generate
    begin
        for(x = 0; x < PN; x = x + 1)
        begin
            assign w_padding_addr[x] = (r_padding_addr[x] < (PD_DW * PD_DH)) ? r_padding_addr[x] : 0;
            assign w_add[((x + 1) * CW - 1) : (x * CW)] = r_add[1][x];
        end
    end
    endgenerate
    
    assign w_add_row = (r_add_cnt / WH);
    assign w_add_col = (r_add_cnt % WH);
    
    
    always @(posedge i_clk)
    begin
        if(i_rst)
            r_data_cnt <= 0;
        else if(i_data_last)
            r_data_cnt <= 0;
        else if(i_data_valid)
            r_data_cnt <= r_data_cnt + 1;
    end
    
    always @(posedge i_clk)
    begin
        if(i_rst)
            r_weight_cnt <= 0;
        else if(i_weight_last)
            r_weight_cnt <= 0;
        else if(i_weight_valid)
            r_weight_cnt <= r_weight_cnt + 1;
    end
    
    always @(posedge i_clk)
    begin
        if(i_rst)
        begin
            for(i = 0; i < WW; i = i + 1)
                for(j = 0; j < WH; j = j + 1)
                    r_kernel[i][j] <= 0;
        end
        else if(r_weight_valid)
        begin
            r_kernel[r_kernel_row][r_kernel_col] <= r_weight;
        end
    end
    
    always @(posedge i_clk)
    begin
        if(i_rst)
        begin
            for(i = 0; i < PN; i = i + 1)
                for(j = 0; j < WW; j = j + 1)
                    for(k = 0; k < WH; k = k + 1)
                        r_stride[i][j][k] <= 0;
        end
        else
        begin
            for(i = 0; i < PN; i = i + 1)
                r_stride[i][r_stride_row[1]][r_stride_col[1]] <= {1'b0, w_padding[i]};
        end
    end
    
    always @(posedge i_clk)
    begin
        if(i_rst)
            r_current <= IDLE;
        else
            r_current <= r_next;
    end
    
    always @(*)
    begin
        case(r_current)
        IDLE:
        begin
            if(r_conv_start)
                r_next = MULT;
            else
                r_next = IDLE;
        end
        MULT:
        begin
            if(r_out_cnt <= (SD_DW * SD_DH / PN))
                r_next = ADD;
            else
                r_next = IDLE;
        end
        ADD:
        begin
            if(r_add_cnt < (WW * WH))
                r_next = ADD;
            else
                r_next = OUT;
        end
        OUT:
        begin
            r_next = DELAY;
        end
        DELAY:
        begin
            r_next = MULT;
        end
        default:
        begin
            r_next = IDLE;
        end
        endcase
    end
    
    always @(posedge i_clk)
    begin
        if(i_rst)
        begin
            for(i = 0; i < PN; i = i + 1)
                for(j = 0; j < WW; j = j + 1)
                    for(k = 0; k < WH; k = k + 1)
                        r_mult[i][j][k] <= 0;
            for(i = 0; i < PN; i = i + 1)
            begin
                r_add[0][i] <= 0;
                r_add[1][i] <= 0;
                r_padding_addr[i] <= 0;
            end
            r_row_cnt <= 0;
            r_col_cnt <= 0;
            r_add_cnt <= 0;
            r_out_cnt <= 0;
            r_add_valid <= 0;
            r_add_last <= 0;
        end
        else
        begin
            case(r_next)
            IDLE:
            begin
                for(i = 0; i < PN; i = i + 1)
                    for(j = 0; j < WW; j = j + 1)
                        for(k = 0; k < WH; k = k + 1)
                            r_mult[i][j][k] <= 0;
                for(i = 0; i < PN; i = i + 1)
                begin
                    r_add[0][i] <= 0;
                    r_add[1][i] <= 0;
                    r_padding_addr[i] <= 0;
                end
                r_row_cnt <= 0;
                r_col_cnt <= 0;
                r_add_cnt <= 0;
                r_out_cnt <= 0;
                r_add_valid <= 0;
                r_add_last <= 0;
            end
            MULT:
            begin
                for(i = 0; i < PN; i = i + 1)
                    for(j = 0; j < WW; j = j + 1)
                        for(k = 0; k < WH; k = k + 1)
                            r_mult[i][j][k] <= r_stride[i][j][k] * r_kernel[j][k];
                for(i = 0; i < PN; i = i + 1)
                begin
                    r_add[0][i] <= 0;
                    r_add[1][i] <= 0;
                    r_padding_addr[i] <= 0;
                end
                r_row_cnt <= 0;
                r_col_cnt <= 0;
                r_add_cnt <= 0;
                r_out_cnt <= r_out_cnt;
                r_add_valid <= 0;
                r_add_last <= 0;
            end
            ADD:
            begin
                for(i = 0; i < PN; i = i + 1)
                    for(j = 0; j < WW; j = j + 1)
                        for(k = 0; k < WH; k = k + 1)
                            r_mult[i][j][k] <= r_mult[i][j][k];
                for(i = 0; i < PN; i = i + 1)
                begin
                    r_add[0][i] <= r_add[0][i] + r_mult[i][w_add_row][w_add_col];
                    r_add[1][i] <= 0;
                    r_padding_addr[i] <= r_mult_row[i][r_row_cnt] * PD_DH + r_mult_col[i][r_col_cnt];
                end
                if(r_row_cnt < WW - 1)
                begin
                    if(r_col_cnt < WH - 1)
                    begin
                        r_row_cnt <= r_row_cnt;
                        r_col_cnt <= r_col_cnt + 1;
                    end
                    else
                    begin
                        r_row_cnt <= r_row_cnt + 1;
                        r_col_cnt <= 0;
                    end
                end
                else
                begin
                    r_row_cnt <= r_row_cnt;
                    r_col_cnt <= r_col_cnt + 1;
                end
                r_add_cnt <= r_add_cnt + 1;
                r_out_cnt <= r_out_cnt;
                r_add_valid <= 0;
                r_add_last <= 0;
            end
            OUT:
            begin
                for(i = 0; i < PN; i = i + 1)
                    for(j = 0; j < WW; j = j + 1)
                        for(k = 0; k < WH; k = k + 1)
                            r_mult[i][j][k] <= 0;
                for(i = 0; i < PN; i = i + 1)
                begin
                    r_add[0][i] <= 0;
                    r_add[1][i] <= r_add[0][i];
                    r_padding_addr[i] <= 0;
                end
                r_row_cnt <= 0;
                r_col_cnt <= 0;
                r_add_cnt <= r_add_cnt;
                r_out_cnt <= r_out_cnt + 1;
                if(r_out_cnt == 0)
                    r_add_valid <= 0;
                else
                    r_add_valid <= 1;
                if(r_out_cnt == (SD_DW * SD_DH / PN))
                    r_add_last <= 1;
                else
                    r_add_last <= 0;
            end
            DELAY:
            begin
                for(i = 0; i < PN; i = i + 1)
                    for(j = 0; j < WW; j = j + 1)
                        for(k = 0; k < WH; k = k + 1)
                            r_mult[i][j][k] <= 0;
                for(i = 0; i < PN; i = i + 1)
                begin
                    r_add[0][i] <= 0;
                    r_add[1][i] <= 0;
                    r_padding_addr[i] <= 0;
                end
                r_row_cnt <= 0;
                r_col_cnt <= 0;
                r_add_cnt <= r_add_cnt;
                r_out_cnt <= r_out_cnt;
                r_add_valid <= 0;
                r_add_last <= 0;
            end
            default:
            begin
                for(i = 0; i < PN; i = i + 1)
                    for(j = 0; j < WW; j = j + 1)
                        for(k = 0; k < WH; k = k + 1)
                            r_mult[i][j][k] <= 0;
                for(i = 0; i < PN; i = i + 1)
                begin
                    r_add[0][i] <= 0;
                    r_add[1][i] <= 0;
                    r_padding_addr[i] <= 0;
                end
                r_row_cnt <= 0;
                r_col_cnt <= 0;
                r_add_cnt <= 0;
                r_out_cnt <= 0;
                r_add_valid <= 0;
                r_add_last <= 0;
            end
            endcase
        end
    end
    
    generate
    begin
        for(x = 0; x < PN; x = x + 1)
        begin : PADDING
            bram
            #(
                .AW  (AW               ),
                .BW  (BW               ),
                .DP  (PD_DW * PD_DH    )
            ) padding_i
            (
                .clk (i_clk            ),
                .din (r_data           ),
                .we  (r_data_valid     ),
                .wadr(w_data_addr      ),
                .radr(w_padding_addr[x]),
                .dout(w_padding[x]     )
            );
        end
    end
    endgenerate
    
endmodule