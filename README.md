# 本项目用verilog实现了图像的二维卷积，stride、图像大小等参数化。本打算实现其他算子的，后来发现有Vitis-AI可用，就懒得写了。
# 另外，卷积虽然支持并行，但不是矩阵运算，效率比较低，FPGA上能编译能用而已，不要抱太大希望（没什么卵用就分享了）。
# 参数说明：
    parameter AW = 14;  //地址位宽
    parameter BW = 8;  //数据位宽
    parameter CH = 3;  //通道数
    parameter DW = 72; //图像宽度
    parameter DH = 128; //图像高度
    parameter WW = 3;  //权重宽度
    parameter WH = 3;  //权重高度
    parameter SW = 1;  //stride宽度
    parameter SH = 1;  //stride高度
    parameter PD = 1;  //padding使能
    parameter PN = 1;  //并行数
# 模块的输入输出采用的是简化的axi-stream总线。

# 使用方法：
1.运行python tb_in.py将che.jpg图像转换成testbench文件（conv_tb.v）的输入数据pic.txt；
2.在modelsim等仿真环境下新建工程，添加所有.v文件和输入数据pic.txt文件，编译并进行仿真，生成输出数据conv.txt；
3.运行python tb_out.py将输出数据conv.txt转换成图像显示，并与软件卷积的结果进行比较。
