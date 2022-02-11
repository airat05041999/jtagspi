//////////////////////////////////////////////////
//~:(
//@module: spi_fsm.sv
//@author: Yafizov Airat
//@date: 11.02.22
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
//Local params
//////////////////////////////////////////////////

//initial constants
localparam MR = 8'h00;
localparam IMR = 8'h00;
localparam GAR = 32'hc0a80101;
localparam SUBR = 32'hffffff00;
localparam SHAR = 48'h05689c010503;
localparam SIPR = 32'hc0a80102;
localparam SIMR = 8'h01;
localparam SN_MR = 8'h01;
localparam SN_PORT = 16'h1388;
localparam NUMBER_REG = 9;

//addr_registers
localparam ADDR_MR = 16'h0000;
localparam ADDR_IMR = 16'h0016;
localparam ADDR_GAR = 16'h0001;
localparam ADDR_SUBR = 16'h0005;
localparam ADDR_SHAR = 16'h0009;
localparam ADDR_SIPR = 16'h000f;
localparam ADDR_SIMR = 16'h0018;
localparam ADDR_SN_MR = 16'h0000;
localparam ADDR_SN_CR = 16'h0001;
localparam ADDR_SN_SR = 16'h0003;
localparam ADDR_SN_IMR = 16'h002c;
localparam ADDR_SN_PORT = 16'h0004;
localparam ADDR_SN_RX_RSR = 16'h0026;
localparam ADDR_SN_RX_RD = 16'h0028;

//state_SN_CR
localparam OPEN = 8'h01;
localparam LISTEN = 8'h02;
localparam DISCON = 8'h08;
localparam CLOSE = 8'h10;
localparam RECV = 8'h40;

//state_SN_SR
localparam SOCK_CLOSED  = 8'h00;
localparam SOCK_INIT = 8'h13;
localparam SOCK_LISTEN = 8'h14;
localparam SOCK_ESTABLISHED = 8'h17;
localparam SOCK_CLOSE_WAIT = 8'h1c;

//BSB constants
localparam BSB_REGULAR_REG = 5'b00000;
localparam BSB_SOCKET_0_REG = 5'b00001;
localparam BSB_RX_SOCKET_0_REG = 5'b00011;

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum logic [2:0] {ST_IDLE, ST_RUNNING_R, ST_RUNNING_WR, ST_RUNNING_R_CONTROL, ST_RUNNING_WR_INITIAL} state_type;

//////////////////////////////////////////////////
//local registers
//////////////////////////////////////////////////

state_type state;
logic [2:0] interrupt;
logic [2:0] index;
logic permission;
logic flag;
logic initial_index;
logic 

//////////////////////////////////////////////////
//Architecture
////////////////////////////////////////////////// 

//permission block
always_ff @(posedge clk) begin
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
end


//state machine
always_ff @(posedge clk) begin
    if (rst) begin
        initial_index <= NUMBER_REG;
        index <= 0;
        wr <= 0;
        rd <= 0;
        state <= ST_IDLE;
        op <=0;
        work <=0;
        len <= 0;
        interrupt <= 3;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_IDLE : begin
                work <= 0;
                op <= 0;
                wr <= 0;
                rd <= 0;
                if (initial_index != 0) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_RUNNING_WR_INITIAL;
                        index <=0;
                    end
                end

                /*if (busy == 0) begin
                    if ((interrupt == 1) && (permission == 1)) begin
                        state <= ST_RUNNING_R;
                        index <= 3;
                        interrupt <= 0;
                    end
                    else if ((interrupt == 2) && (permission == 1)) begin
                        state <= ST_RUNNING_WR;
                        index <= 5;
                        interrupt <= 1;
                    end
                    else if ((interrupt == 3) && (permission == 1)) begin
                        state <= ST_RUNNING_R;
                        index <= 3;
                        interrupt <= 2;
                    end
                end */
            end
            //////////////////////////////////////////////////
            ST_RUNNING_WR_INITIAL : begin  
                case (initial_index)
                    1:  begin
                            if (index == 5) begin
                                wr <= 0;
                                work <= 1;
                                op <= 1;
                                state <= ST_IDLE;
                                len <= 40;
                                initial_index <= initial_index - 1;
                            end 
                            else if (index == 4) begin
                                wr <= 1;
                                wdata <= SN_PORT [7:0];
                                index <= index + 1;
                            end
                            else if (index == 3) begin
                                wr <= 1;
                                wdata <= SN_PORT [15:8];
                                index <= index + 1;
                            end
                            else if (index == 2) begin
                                wr <= 1;
                                wdata <= {BSB_REGULAR_REG, 1'b1, 2'b0};
                                index <= index + 1;
                            end    
                            else if (index == 1) begin
                                wr <= 1;
                                wdata <= ADDR_SN_PORT [7:0];
                                index <= index + 1;
                            end 
                            else if (index == 0) begin
                                wr <= 1;
                                wdata <= ADDR_SN_PORT [15:8]; 
                                index <= index + 1;
                            end
                        end
                    2:  begin
                            if (index == 4) begin
                                wr <= 0;
                                work <= 1;
                                op <= 1;
                                state <= ST_IDLE;
                                len <= 32;
                                initial_index <= initial_index - 1;
                            end 
                            else if (index == 3) begin
                                wr <= 1;
                                wdata <= SN_MR;
                                index <= index + 1;
                            end
                            else if (index == 2) begin
                                wr <= 1;
                                wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                                index <= index + 1;
                            end    
                            else if (index == 1) begin
                                wr <= 1;
                                wdata <= ADDR_SN_MR [7:0];
                                index <= index + 1;
                            end 
                            else if (index == 0) begin
                                wr <= 1;
                                wdata <= ADDR_SN_MR [15:8]; 
                                index <= index + 1;
                            end
                    3:  begin
                            if (index == 4) begin
                                wr <= 0;
                                work <= 1;
                                op <= 1;
                                state <= ST_IDLE;
                                len <= 32;
                                initial_index <= initial_index - 1;
                            end 
                            else if (index == 3) begin
                                wr <= 1;
                                wdata <= SIMR;
                                index <= index + 1;
                            end
                            else if (index == 2) begin
                                wr <= 1;
                                wdata <= {BSB_REGULAR_REG, 1'b1, 2'b0};
                                index <= index + 1;
                            end    
                            else if (index == 1) begin
                                wr <= 1;
                                wdata <= ADDR_SIMR [7:0];
                                index <= index + 1;
                            end 
                            else if (index == 0) begin
                                wr <= 1;
                                wdata <= ADDR_SIMR [15:8]; 
                                index <= index + 1;
                            end
                    4:  begin
                            if (index == 7) begin
                                wr <= 0;
                                work <= 1;
                                op <= 1;
                                state <= ST_IDLE;
                                len <= 56;
                                initial_index <= initial_index - 1;
                            end 
                            else if (index == 6) begin
                                wr <= 1;
                                wdata <= SIPR [7:0];
                                index <= index + 1;
                            end
                            else if (index == 5) begin
                                wr <= 1;
                                wdata <= SIPR [15:8];
                                index <= index + 1;
                            end
                            else if (index == 4) begin
                                wr <= 1;
                                wdata <= SIPR [23:16];
                                index <= index + 1;
                            end
                            else if (index == 3) begin
                                wr <= 1;
                                wdata <= SIPR [31:24];
                                index <= index + 1;
                            end
                            else if (index == 2) begin
                                wr <= 1;
                                wdata <= {BSB_REGULAR_REG, 1'b1, 2'b0};
                                index <= index + 1;
                            end    
                            else if (index == 1) begin
                                wr <= 1;
                                wdata <= ADDR_SIPR [7:0];
                                index <= index + 1;
                            end 
                            else if (index == 0) begin
                                wr <= 1;
                                wdata <= ADDR_SIPR [15:8]; 
                                index <= index + 1;
                            end
                        end
                    5:  begin
                            if (index == 9) begin
                                wr <= 0;
                                work <= 1;
                                op <= 1;
                                state <= ST_IDLE;
                                len <= 72;
                                initial_index <= initial_index - 1;
                            end 
                            else if (index == 8) begin
                                wr <= 1;
                                wdata <= SHAR [7:0];
                                index <= index + 1;
                            end
                            else if (index == 7) begin
                                wr <= 1;
                                wdata <= SHAR [15:8];
                                index <= index + 1;
                            end
                            else if (index == 6) begin
                                wr <= 1;
                                wdata <= SHAR [23:16];
                                index <= index + 1;
                            end
                            else if (index == 5) begin
                                wr <= 1;
                                wdata <= SHAR [31:24];
                                index <= index + 1;
                            end
                            else if (index == 4) begin
                                wr <= 1;
                                wdata <= SHAR [39:32];
                                index <= index + 1;
                            end
                            else if (index == 3) begin
                                wr <= 1;
                                wdata <= SHAR [47:40];
                                index <= index + 1;
                            end
                            else if (index == 2) begin
                                wr <= 1;
                                wdata <= {BSB_REGULAR_REG, 1'b1, 2'b0};
                                index <= index + 1;
                            end    
                            else if (index == 1) begin
                                wr <= 1;
                                wdata <= ADDR_SHAR [7:0];
                                index <= index + 1;
                            end 
                            else if (index == 0) begin
                                wr <= 1;
                                wdata <= ADDR_SHAR [15:8]; 
                                index <= index + 1;
                            end
                        end
                    6:  begin
                            if (index == 7) begin
                                wr <= 0;
                                work <= 1;
                                op <= 1;
                                state <= ST_IDLE;
                                len <= 56;
                                initial_index <= initial_index - 1;
                            end 
                            else if (index == 6) begin
                                wr <= 1;
                                wdata <= SUBR [7:0];
                                index <= index + 1;
                            end
                            else if (index == 5) begin
                                wr <= 1;
                                wdata <= SUBR [15:8];
                                index <= index + 1;
                            end
                            else if (index == 4) begin
                                wr <= 1;
                                wdata <= SUBR [23:16];
                                index <= index + 1;
                            end
                            else if (index == 3) begin
                                wr <= 1;
                                wdata <= SUBR [31:24];
                                index <= index + 1;
                            end
                            else if (index == 2) begin
                                wr <= 1;
                                wdata <= {BSB_REGULAR_REG, 1'b1, 2'b0};
                                index <= index + 1;
                            end    
                            else if (index == 1) begin
                                wr <= 1;
                                wdata <= ADDR_SUBR [7:0];
                                index <= index + 1;
                            end 
                            else if (index == 0) begin
                                wr <= 1;
                                wdata <= ADDR_SUBR [15:8]; 
                                index <= index + 1;
                            end
                        end
                    7:  begin
                            if (index == 7) begin
                                wr <= 0;
                                work <= 1;
                                op <= 1;
                                state <= ST_IDLE;
                                len <= 56;
                                initial_index <= initial_index - 1;
                            end 
                            else if (index == 6) begin
                                wr <= 1;
                                wdata <= GAR [7:0];
                                index <= index + 1;
                            end
                            else if (index == 5) begin
                                wr <= 1;
                                wdata <= GAR [15:8];
                                index <= index + 1;
                            end
                            else if (index == 4) begin
                                wr <= 1;
                                wdata <= GAR [23:16];
                                index <= index + 1;
                            end
                            else if (index == 3) begin
                                wr <= 1;
                                wdata <= GAR [31:24];
                                index <= index + 1;
                            end
                            else if (index == 2) begin
                                wr <= 1;
                                wdata <= {BSB_REGULAR_REG, 1'b1, 2'b0};
                                index <= index + 1;
                            end    
                            else if (index == 1) begin
                                wr <= 1;
                                wdata <= ADDR_GAR [7:0];
                                index <= index + 1;
                            end 
                            else if (index == 0) begin
                                wr <= 1;
                                wdata <= ADDR_GAR [15:8]; 
                                index <= index + 1;
                            end
                        end
                    8:  begin
                            if (index == 4) begin
                                wr <= 0;
                                work <= 1;
                                op <= 1;
                                state <= ST_IDLE;
                                len <= 32;
                                initial_index <= initial_index - 1;
                            end 
                            else if (index == 3) begin
                                wr <= 1;
                                wdata <= IMR;
                                index <= index + 1;
                            end
                            else if (index == 2) begin
                                wr <= 1;
                                wdata <= {BSB_REGULAR_REG, 1'b1, 2'b0};
                                index <= index + 1;
                            end    
                            else if (index == 1) begin
                                wr <= 1;
                                wdata <= ADDR_IMR [7:0];
                                index <= index + 1;
                            end 
                            else if (index == 0) begin
                                wr <= 1;
                                wdata <= ADDR_IMR [15:8]; 
                                index <= index + 1;
                            end
                        end
                    9:  begin
                            if (index == 4) begin
                                wr <= 0;
                                work <= 1;
                                op <= 1;
                                state <= ST_IDLE;
                                len <= 32;
                                initial_index <= initial_index - 1;
                            end 
                            else if (index == 3) begin
                                wr <= 1;
                                wdata <= MR;
                                index <= index + 1;
                            end
                            else if (index == 2) begin
                                wr <= 1;
                                wdata <= {BSB_REGULAR_REG, 1'b1, 2'b0};
                                index <= index + 1;
                            end    
                            else if (index == 1) begin
                                wr <= 1;
                                wdata <= ADDR_MR [7:0];
                                index <= index + 1;
                            end 
                            else if (index == 0) begin
                                wr <= 1;
                                wdata <= ADDR_MR [15:8]; 
                                index <= index + 1;
                            end
                        end
                    default : begin
                        state <= ST_IDLE;
                    end
                endcase
            end
            //////////////////////////////////////////////////
            ST_RUNNING_WR : begin  
                /*if (index == 0) begin
                    wr <= 0;
                    work <= 1;
                    op <= 1;
                    state <= ST_IDLE;
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
            end*/
            //////////////////////////////////////////////////
            ST_RUNNING_R : begin  
                /*if (index == 0) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_IDLE;
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
            end*/
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
