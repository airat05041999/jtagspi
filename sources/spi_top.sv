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
    parameter FIFO_DEPTH = 16
    )

    (
    //SYSTEM
    //input logic rst,
    input logic clknotpll,
    //INPUT_CONTROL
    //input logic interrupt, 
     input logic interrupt,
    //INPUT_SPI
    input logic miso,
    //OUTPUT_SPI
    output logic scsn,
    output logic mosi,
    //system w5500
    output logic sclk,
    output logic wrst,
    output logic check
    );




//////////////////////////////////////////////////
//local signal
//////////////////////////////////////////////////
logic [31:0] countrst = 0;
logic [31:0] countwrst = 0;
logic rst;
logic clk;

//fifo 1 signals
logic [(DATA-1):0] wdata1;
logic [(DATA-1):0] rdata1;
logic wr1;
logic rd1;
logic full1;
logic empty1;
logic [($clog2(FIFO_DEPTH) - 1):0] usedw1;


//fifo 2 signals
logic [(DATA-1):0] wdata2;
logic [(DATA-1):0] rdata2;
logic wr2;
logic rd2;
logic full2;
logic empty2;
logic [($clog2(FIFO_DEPTH) - 1):0] usedw2;

//fifo 3 signals
logic [(DATA-1):0] wdata3;
logic [(DATA-1):0] rdata3;
logic wr3;
logic rd3;
logic full3;
logic empty3;
logic [($clog2(FIFO_DEPTH) - 1):0] usedw3;

//control signals
logic [15:0] len;
logic op;
logic work;
logic busy;

//////////////////////////////////////////////////
//reset counter for debugging
//////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (countrst == 0) begin
        rst <= 0;
        countrst <= countrst + 1;
    end
    else if (countrst < 500000000) begin
        countrst <= countrst + 1;
    end
    else if (countrst < 500000001) begin
        countrst <= countrst + 1;
        rst <= 1;
    end
    else if (countrst == 500000001) begin
        countrst <= 500000002;
        rst <= 0;
    end
end

always_ff @(posedge clk) begin
    if (countwrst == 0) begin
        wrst <= 1;
        countwrst <= countwrst + 1;
    end
    else if (countwrst < 250000000) begin
        countwrst <= countwrst + 1;
    end
    else if (countwrst < 250500001) begin
        countwrst <= countwrst + 1;
        wrst <= 0;
    end
    else if (countwrst == 250500001) begin
        countwrst <= 250500002;
        wrst <= 1;
    end
end

//////////////////////////////////////////////////
//reset counter for modeling
//////////////////////////////////////////////////
/*always_ff @(posedge clk) begin
    if (countrst == 0) begin
        rst <= 0;
        countrst <= countrst + 1;
    end
    else if (countrst < 50) begin
        countrst <= countrst + 1;
    end
    else if (countrst < 51) begin
        countrst <= countrst + 1;
        rst <= 1;
    end
    else if (countrst == 51) begin
        countrst <= 52;
        rst <= 0;
    end
end

always_ff @(posedge clk) begin
    if (countwrst == 0) begin
        wrst <= 1;
        countwrst <= countwrst + 1;
    end
    else if (countwrst < 25) begin
        countwrst <= countwrst + 1;
    end
    else if (countwrst < 30) begin
        countwrst <= countwrst + 1;
        wrst <= 0;
    end
    else if (countwrst == 30) begin
        countwrst <= 31;
        wrst <= 1;
    end
end*/

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

fifo #(.FIFO_DEPTH(FIFO_DEPTH), .DATA_WIDTH(DATA))
    fifo_inst3 (
        .clk(clk), .rst(rst),
        .wdata(wdata3), .wr(wr3), .full(full3),
        .rdata(rdata3), .rd(rd3), .empty(),
        .usedw(usedw3)
    );

/*spi_check_module #(.FIFO_DEPTH(FIFO_DEPTH), .DATA(DATA))
    spi_check_module_inst (
        .clk(clk), .rst(rst), .check(check),
        .rdata(rdata3), .rd(rd3), .usedw(usedw3)
        );*/

spi_interface #(.DATA(DATA))
    spi_insterface_inst (
        .clk(clk), .rst(rst),
        .wdata(wdata2), .wr(wr2), .full(full2),
        .rdata(rdata2), .rd(rd2), .empty(empty2),
        .len(len), .work(work), .op(op), .busy(busy),
        .mosi(mosi), .miso(miso), .scsn(scsn), .sclk(sclk)
    );

/*spi_fsm #(.FIFO_DEPTH(FIFO_DEPTH), .DATA(DATA))
    spi_fsm_inst (
        .clk(clk), .rst(rst),
        .wdata(wdata1), .wr(wr1), .full(full1),
        .rdata(rdata1), .rd(rd1), .empty(empty1), .usedw(usedw1),
        .len(len), .work(work), .op(op), .busy(busy), 
        .wdata3(wdata3), .wr3(wr3), .full3(full3), .interrupt(interrupt)
    );*/

spi_fsm_for_tests #(.DATA(DATA))
    spi_fsm_inst (
        .clk(clk), .rst(rst),
        .wdata(wdata1), .wr(wr1), .full(full1), .check(check),
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