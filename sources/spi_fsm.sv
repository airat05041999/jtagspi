//////////////////////////////////////////////////
//~:(
//@module: spi_fsm.sv
//@author: Yafizov Airat
//@date: 13.1.22
//@version: 1.0.0
//@description: spi_fsm
//~:)
//////////////////////////////////////////////////

module spi_fsm
    #(
    parameter DATA = 8
    )

    (
    //SYSTEM
    input logic clk,
    input logic rst,
    //INPUT_CONTROL
    output logic [15:0] len,
    output logic op,
    output logic work,
    //OUTPUT_CONTROL
    input logic busy,
    //OUTPUT_FIFO
    output logic [(DATA-1):0] wdata,
    output logic wr,
    input logic full,
    //INPUT_FIFO
    input logic  [(DATA-1):0] rdata,
    output logic rd,
    input logic empty
    );

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum logic [2:0] {ST_IDLE, ST_RUNNING_R, ST_RUNNING_WR} state_type;

//////////////////////////////////////////////////
//local registers
//////////////////////////////////////////////////

state_type state;
logic interrupt;
logic [1:0] index;

//////////////////////////////////////////////////
//Architecture
////////////////////////////////////////////////// 

//state machine
always_ff @(posedge clk) begin
    if (rst) begin
        index <= 0;
        wr <= 0;
        rd <= 0;
        state <= ST_IDLE;
        op <=0;
        work <=0;
        len <= 0;
        interrupt <= 1;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_IDLE : begin
                work <= 0;
                op <= 0;
                wr <= 0;
                rd <= 0;
                if (busy == 0) begin
                    if (interrupt == 1) begin
                        state <= ST_RUNNING_R;
                        index <= 3;
                        interrupt <= 0;
                    end
                end 
            end
            //////////////////////////////////////////////////
            ST_RUNNING_WR : begin  
                
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R : begin  
                if (index == 0) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_IDLE;
                    len <= 40;
                end 
                if (index == 1) begin
                    wr <= 1;
                    wdata <= 8'h00;
                    index <= index - 1;
                end 
                if (index == 2) begin
                    wr <= 1;
                    wdata <= 8'h19;
                    index <= index - 1;
                end
                if (index == 3) begin
                    wr <= 1;
                    wdata <= 8'h00;;
                    index <= index - 1;
                end 
            end
            //////////////////////////////////////////////////
            default : begin 
                state <= ST_IDLE;
            end
         endcase
    end
end


//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////
