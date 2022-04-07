//////////////////////////////////////////////////
//~:(
//@module: spi_fsm.sv
//@author: Yafizov Airat
//@date: 13.1.22
//@version: 1.0.0
//@description: spi_fsm_for_tests
//~:)
//////////////////////////////////////////////////

module spi_fsm_for_tests
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
    input logic empty,
    output logic check
    );

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum logic [2:0] {ST_IDLE, ST_RUNNING_R, ST_RUNNING_WR, ST_CAPTURE_RD, ST_PREPARATION} state_type;

//////////////////////////////////////////////////
//local registers
//////////////////////////////////////////////////

state_type state;
logic [2:0] interrupt;
logic [2:0] index;
logic permission = 0;
logic flag;

//////////////////////////////////////////////////
//Architecture
////////////////////////////////////////////////// 

//permission block
/*always_ff @(posedge clk) begin
    if(rst) begin
        permission <= 0;
        flag <= 0;
    end 
    else if ((busy == 1) && (flag == 1)) begin
        permission <= 0;
        flag <= 0;
    end 
    else if ((busy == 0) && (flag == 0)) begin
        permission <= 1;
        flag <= 1;
    end
    else if (state != ST_IDLE) begin
        flag <= 1;
        permission <= 0;
    end
end*/


//state machine
always_ff @(posedge clk) begin
    if (rst) begin
        index <= 0;
        wr <= 0;
        rd <= 0;
        state <= ST_PREPARATION;
        op <=0;
        work <=0;
        len <= 0;
        interrupt <= 3;
        check <=0;
        permission <= 1;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_PREPARATION : begin
                work <= 0;
                op <= 0;
                wr <= 0;
                rd <= 0;
                if (permission == 1) begin
                    state <= ST_IDLE;
                end
            end
            //////////////////////////////////////////////////
            ST_IDLE : begin
                if ((interrupt == 1) && (busy == 0)) begin
                    state <= ST_CAPTURE_RD;
                    index <= 3;
                    interrupt <= 3;
                end
                else if ((interrupt == 2) && (busy == 0)) begin
                    state <= ST_RUNNING_R;
                    index <= 3;
                    interrupt <= 1;
                end
                else if ((interrupt == 3) && (busy == 0)) begin
                    state <= ST_RUNNING_WR;
                    index <= 5;
                    interrupt <= 2;
                end
            end
            //////////////////////////////////////////////////
            ST_CAPTURE_RD : begin  
                if (index == 0) begin
                    state <= ST_PREPARATION;
                end
                else if (index == 1) begin
                    rd <= 0;
                    if (!(rdata == 8'ha0)) begin
                        check <= 1;
                    end
                    index <= index - 1;
                end
                else if (index == 2) begin
                    rd <= 1;
                    if (!(rdata == 8'h0f)) begin
                        check <= 1;
                    end
                    index <= index - 1;
                end
                else if (index == 3) begin
                    rd <= 1;
                    index <= index - 1;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_WR : begin  
                if (index == 0) begin
                    wr <= 0;
                    work <= 1;
                    op <= 1;
                    state <= ST_PREPARATION;
                    len <= 40;
                end 
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= 8'ha0;
                    index <= index - 1;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= 8'h0f;
                    index <= index - 1;
                end
                else if (index == 3) begin
                    wr <= 1;
                    wdata <= 8'h04;;
                    index <= index - 1;
                end    
                else if (index == 4) begin
                    wr <= 1;
                    wdata <= 8'h19;
                    index <= index - 1;
                end 
                else if (index == 5) begin
                    wr <= 1;
                    wdata <= 8'h00;
                    index <= index - 1;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R : begin  
                if (index == 0) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_PREPARATION;
                    len <= 40;
                end 
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= 8'h00;
                    index <= index - 1;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= 8'h19;
                    index <= index - 1;
                end
                else if (index == 3) begin
                    wr <= 1;
                    wdata <= 8'h00;
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
