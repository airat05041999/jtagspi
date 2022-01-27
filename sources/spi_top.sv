//////////////////////////////////////////////////
//~:(
//@module: Spi_interface.sv
//@author: Yafizov Airat
//@date: 13.1.22
//@version: 1.0.0
//@description: Spi_top
//~:)
//////////////////////////////////////////////////

module spi_top
    #(
    parameter DATA = 8,
    parameter FIFO_DEPTH = 8
    )

    (
    //SYSTEM
    input logic clknotpll,
    //INPUT_CONTROL
    //input logic interrupt, 
    //INPUT_SPI
    input logic miso,
    //OUTPUT_SPI
    output logic scsn,
    output logic mosi,
    //system w5500
    output logic sclk,
    output logic wrst
    );




//////////////////////////////////////////////////
//local signal
//////////////////////////////////////////////////
logic [31:0] countrst;
logic [31:0] countwrst;

//fifo 1 signals
logic [(DATA-1):0] wdata1;
logic [(DATA-1):0] rdata1;
logic wr1;
logic rd1;
logic full1;
logic empty1;
logic usedw1;
logic clk;
logic rst;

//fifo 2 signals
logic [(DATA-1):0] wdata2;
logic [(DATA-1):0] rdata2;
logic wr2;
logic rd2;
logic full2;
logic empty2;
logic usedw2;

//control signals
logic [15:0] len;
logic op;
logic work;
logic busy;

//////////////////////////////////////////////////
//reset counter
//////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (countrst < 50000000) begin
        countrst <= countrst + 1;
    end
    else if (countrst == 50000000) begin
        countrst <= 50000001;
        rst <= 1;
    end
    else if (countrst == 50000001) begin
        countrst <= 50000002;
        rst <= 0;
    end
end

always_ff @(posedge clk) begin
    if (countwrst == 0) begin
        wrst <= 1;
        countwrst <= countwrst + 1;
    end
    else if (countwrst < 25000000) begin
        countwrst <= countwrst + 1;
    end
    else if (countwrst < 25050000) begin
        countwrst <= countwrst + 1;
        wrst <= 0;
    end
    else if (countwrst == 25050000) begin
        countwrst <= 25050001;
        wrst <= 1;
    end
end

//////////////////////////////////////////////////
//buffer fifo
//INPUT: DATA AND PERMISSIN
//OUTPUT: BUFFER AND ITS STATUS
//////////////////////////////////////////////////


fifo #(.FIFO_DEPTH(FIFO_DEPTH), .DATA_WIDTH(DATA))
    fifo_inst1 (
        .clk(clk), .rst(rst),
        .wdata(wdata2), .wr(wr2), .full(full2),
        .rdata(rdata1), .rd(rd1), .empty(empty1),
        .usedw(usedw1)
    );

fifo #(.FIFO_DEPTH(FIFO_DEPTH), .DATA_WIDTH(DATA))
    fifo_inst2 (
        .clk(clk), .rst(rst),
        .wdata(wdata1), .wr(wr1), .full(full1),
        .rdata(rdata2), .rd(rd2), .empty(empty2),
        .usedw(usedw2)
    );

spi_interface #(.DATA(DATA))
    spi_insterface_inst (
        .clk(clk), .rst(rst),
        .wdata(wdata2), .wr(wr2), .full(full2),
        .rdata(rdata2), .rd(rd2), .empty(empty2),
        .len(len), .work(work), .op(op), .busy(busy),
        .mosi(mosi), .miso(miso), .scsn(scsn), .sclk(sclk)
    );

spi_fsm #(.DATA(DATA))
    spi_fsm_inst (
        .clk(clk), .rst(rst),
        .wdata(wdata1), .wr(wr1), .full(full1),
        .rdata(rdata1), .rd(rd1), .empty(empty1),
        .len(len), .work(work), .op(op), .busy(busy)
    );

pll pll_inst (
        .refclk(clknotpll), .rst(0),
        .outclk_0(clk)
    ); 

//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////
