//////////////////////////////////////////////////
//~:(
//@module: Spi_interface.sv
//@author: Yafizov Airat
//@date: 10.12.21
//@version: 1.6.1
//@description: Spi_interface
//~:)
//////////////////////////////////////////////////

module spi_interface
    #(
    parameter DATA = 8
    )

    (
    //SYSTEM
    input logic clk,
    input logic rst,
    //INPUT_CONTROL
    input logic [15:0] len,
    input logic op,
    input logic work,
    //OUTPUT_CONTROL
    output logic busy,
    //OUTPUT_FIFO
    output logic [(DATA-1):0] wdata,
    output logic wr,
    input logic full,
    //INPUT_FIFO
    input logic  [(DATA-1):0] rdata,
    output logic rd,
    input logic empty,
    //INPUT_SPI
    input logic miso,
    //OUTPUT_SPI
    output logic scsn,
    output logic mosi,
    output logic sclk
    );

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum logic [2:0] {ST_IDLE, ST_RUNNING_R, ST_RUNNING_WR, ST_DISPATCH, ST_SAMPLING} state_type;

//////////////////////////////////////////////////
//Local params
//////////////////////////////////////////////////

localparam FREQUENCY_DIVIDER = 1;
localparam DELAY_SCSN = FREQUENCY_DIVIDER * 4;

//////////////////////////////////////////////////
//local signal
//////////////////////////////////////////////////

logic [15:0] count; 
logic [15:0] counttransaction; 
logic [(DATA - 1):0] shiftregister;
logic [(DATA - 1):0] nextshiftregister;
state_type state;
logic countenable;

//////////////////////////////////////////////////
//Architecture
////////////////////////////////////////////////// 

//////////////////////////////////////////////////
//counter scsn
//////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (rst) begin
            count <= 0;
        end
    else if ((FREQUENCY_DIVIDER * len + 2 * DELAY_SCSN) == count) begin
            count <= 0;
        end
    else if (countenable == 1) begin
            count <= count + 1;
        end
    else begin
        count <= 0;
    end
end

//////////////////////////////////////////////////
//counter of transaction
//////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (rst) begin
            counttransaction <= 0;
        end
    else if (len == counttransaction) begin
            counttransaction <= 0;
        end
    else if ((countenable == 1) && (((DELAY_SCSN + FREQUENCY_DIVIDER * counttransaction) - count) == 1))  begin
            counttransaction <= counttransaction + 1;
        end
end



//////////////////////////////////////////////////
//Shift register
//////////////////////////////////////////////////
always_ff @ (negedge clk) begin
    if (rst) begin
        nextshiftregister <= 0;
    end
    else begin
        nextshiftregister <= shiftregister;
    end
end

//////////////////////////////////////////////////
//Mosi retiming
//////////////////////////////////////////////////

assign mosi = nextshiftregister[7];

//state machine
always_ff @(posedge clk) begin
    if (rst) begin
        rd <=0;
        wr <=0;
        busy <=0;
        state <= ST_IDLE;
        shiftregister <= 0;
        countenable <= 0;
        wdata <= 0;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_IDLE : begin
                shiftregister <= 0;
                wr <= 0;
                rd <= 0;
                if ((work == 1) && (op == 1)) begin
                    state <= ST_SAMPLING;
                    busy <= 1;
                end 
                else if ((work == 1) && (op == 0)) begin
                    state <= ST_DISPATCH;
                    busy <= 1;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_WR : begin 
                if ((FREQUENCY_DIVIDER * len + 2 * DELAY_SCSN) == count) begin
                    wr <= 0;
                    rd <= 0; 
                    state <= ST_IDLE;
                    busy <= 0;
                    countenable <= 0;
                end
                else if (count == (DELAY_SCSN - FREQUENCY_DIVIDER)) begin
                    shiftregister [(DATA - 1):0] <= rdata [(DATA-1):0];
                    rd <= 1;
                end
                else if ((count > (DELAY_SCSN - 1)) && (count < (FREQUENCY_DIVIDER * len + DELAY_SCSN)) && (count == ((counttransaction - 1) * FREQUENCY_DIVIDER + DELAY_SCSN))) begin 
                        if (counttransaction == len) begin
                            shiftregister <= {nextshiftregister [(DATA-2):0],1'b0};
                            rd <= 0;
                        end
                        else if ((!counttransaction[0]) && (!counttransaction[1]) && (!counttransaction[2]))  begin
                            shiftregister <= {rdata [(DATA-1):0]};
                            rd <= 1;
                        end
                        else begin
                            shiftregister <= {nextshiftregister [(DATA-2):0],1'b0};
                            rd <= 0;
                        end
                    end 
                    else begin
                        wr <= 0;
                        rd <= 0;
                    end 
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R : begin  
                if ((FREQUENCY_DIVIDER * len + 2 * DELAY_SCSN) == count) begin 
                    wr <= 0;
                    rd <= 0;
                    state <= ST_IDLE;
                    busy <= 0;
                    countenable <= 0;
                end
                else if (count == (DELAY_SCSN - FREQUENCY_DIVIDER)) begin
                    shiftregister [(DATA - 1):0] <= rdata [(DATA-1):0];
                    rd <= 1;
                end
                else if ((count > (DELAY_SCSN - 1)) && (count < (FREQUENCY_DIVIDER * len + DELAY_SCSN)) && (count == ((counttransaction - 1) * FREQUENCY_DIVIDER + DELAY_SCSN))) begin 
                    if (counttransaction < 25) begin
                            if (counttransaction == 24) begin
                                shiftregister <= {nextshiftregister [(DATA-2):0],1'b0};
                                rd <= 0;
                            end
                            else if ((!counttransaction[0]) && (!counttransaction[1]) && (!counttransaction[2])) begin
                                shiftregister <= {rdata [(DATA-1):0]};
                                rd <= 1;
                            end
                            else begin
                                shiftregister <= {nextshiftregister [(DATA-2):0],1'b0};
                                rd <= 0;
                            end
                        end
                        else if ((!counttransaction[0]) && (!counttransaction[1]) && (!counttransaction[2])) begin
                                wdata <= {nextshiftregister [(DATA - 2):0], miso};  
                                shiftregister <= {nextshiftregister [(DATA - 2):0], miso};  
                                wr <= 1;
                        end
                        else begin
                                shiftregister <= {nextshiftregister [(DATA - 2):0], miso};
                                wr <= 0;
                        end
                    end 
                    else begin
                        wr <= 0;
                        rd <= 0;
                    end 
            end
            //////////////////////////////////////////////////
            ST_DISPATCH : begin  
                state <= ST_RUNNING_R;
                countenable <= 1;
            end
            //////////////////////////////////////////////////
            ST_SAMPLING : begin  
                //shiftregister [(DATA - 1):0] <= rdata [(DATA-1):0];
                state <= ST_RUNNING_WR;
                countenable <= 1;
                //rd <= 1;
            end
            //////////////////////////////////////////////////
            default : begin 
                state <= ST_IDLE;
            end
         endcase
    end
end

//////////////////////////////////////////////////
//scsn line
//////////////////////////////////////////////////

always_ff @(negedge clk) begin
    if(rst) begin
        scsn <= 1;
    end
        else if (state == ST_RUNNING_R) begin
                scsn <= 0;
        end 
        else if (state == ST_RUNNING_WR) begin 
                scsn <= 0;
        end
        else begin 
            scsn <= 1;
        end
end

//////////////////////////////////////////////////
//sclk impulse generation logic
//////////////////////////////////////////////////

always_ff @(negedge clk) begin
    if(rst) begin
        sclk <= 0;
    end 
	 else if (count == DELAY_SCSN) begin
                sclk <= 1;
        end
        else if ((count > (DELAY_SCSN)) && (count < (FREQUENCY_DIVIDER * len + DELAY_SCSN) && (!(count[1])))) begin
                sclk <= 1;
        end 
        else begin 
            sclk <= 0;
        end
end

//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////
