//////////////////////////////////////////////////
//~:(
//@module: Spi_interface_test.sv
//@author: Yafizov Airat
//@date: 15.12.2021
//@version: 1.0.0
//@description: testbench 
//~:)
//////////////////////////////////////////////////
`timescale 10 ns/10 ns
//////////////////////////////////////////////////
module spi_interface_test;

//////////////////////////////////////////////////
//Local signals
//////////////////////////////////////////////////

logic clk;
logic rst;
logic [15:0] len;
logic [7:0] rdata;
logic work;
logic op;
logic miso;

//////////////////////////////////////////////////
//Tested module
//////////////////////////////////////////////////

spi_interface spi_interface_inst (
    .clk(clk), .rst(rst),
    .len(len), .rdata(rdata),
    .work(work), .op(op),
    .miso(miso)
    );

//////////////////////////////////////////////////
//Test
//////////////////////////////////////////////////

initial
    begin
        rst = 1;
        #10;
        rst = 0;
        #10;
        op = 1;
        work = 1;
        rdata = 8'b01100111;
        len = 16;
        #10;
        work = 0;
        #70;
        rdata = 8'b10101010;
        #120;
        op = 0;
        work = 1;
        rdata = 8'b01100111;
        len = 48;
        #10;
        work = 0;
        #70;
        rdata = 8'b10101010;
        #80;
        rdata = 8'b00001111;
    end

//////////////////////////////////////////////////
//clk
//////////////////////////////////////////////////

initial                                                
    begin                                                  
        clk=0;
        forever #5 clk=~clk;
    end

initial                                                
    begin                                                  
        miso=0;
        forever #10 miso=~miso;
    end

endmodule
