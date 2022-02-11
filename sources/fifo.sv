//////////////////////////////////////////////////
//~:(
//@module: fifo.sv
//@author: Vasiliy Belyaev
//@date: 9.09.17
//@version: 1.6.1
//@description: simple one-clock fifo
//~:)
//////////////////////////////////////////////////

module fifo

#(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16
)

(
    //SYSTEM
    input  logic clk,
    input  logic rst,
    //INPUT_STREAM
    input  logic [(DATA_WIDTH - 1):0] wdata,
    input  logic wr,
    output logic full,
    //OUTPUT_STREAM
    output logic [(DATA_WIDTH - 1):0] rdata,
    input  logic rd,
    output logic empty,
    output logic [($clog2(FIFO_DEPTH) - 1):0] usedw
);

//////////////////////////////////////////////////
//Local params
//////////////////////////////////////////////////

localparam DEPTH_BITS = $clog2(FIFO_DEPTH);

//////////////////////////////////////////////////
//Local signals
//////////////////////////////////////////////////

logic [(DATA_WIDTH - 1):0] mem [(FIFO_DEPTH - 1):0] = '{FIFO_DEPTH{0}};
logic [DEPTH_BITS:0] wp, rp;

//////////////////////////////////////////////////
//Architecture
//////////////////////////////////////////////////

//Pointers logic
always_ff @(posedge clk) begin
    if(rst) begin
        wp <= 0;
        rp <= 0;
    end
    else begin
        wp <= wp + (wr & ~full);
        rp <= rp + (rd & ~empty);
    end
end

assign full = ((wp[(DEPTH_BITS - 1):0] == rp[(DEPTH_BITS - 1):0]) && (wp[DEPTH_BITS] != rp[DEPTH_BITS]));
assign empty = (wp == rp);
assign usedw = wp[(DEPTH_BITS - 1):0] - rp[(DEPTH_BITS - 1):0];

//Memory operations
assign rdata = mem[rp[(DEPTH_BITS - 1):0]];

always_ff @(posedge clk) begin
    if(wr && !full) begin
        mem[wp[(DEPTH_BITS - 1):0]] <= wdata;
    end
end

//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////
