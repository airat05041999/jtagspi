//////////////////////////////////////////////////
//~:(
//@module: spi_fsm.sv
//@author: Yafizov Airat
//@date: 13.1.22
//@version: 1.0.0
//@description: spi_check_module
//~:)
//////////////////////////////////////////////////

module spi_check_module
    #(
    parameter DATA = 8,
    parameter FIFO_DEPTH = 16
    )

    (
    //SYSTEM
    input logic clk,
    input logic rst,
    //INPUT_FIFO
    input logic  [(DATA-1):0] rdata,
    output logic rd,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw,
    output logic check
    );


//////////////////////////////////////////////////
//local registers
//////////////////////////////////////////////////

logic [3:0] index;

//////////////////////////////////////////////////
//Architecture
////////////////////////////////////////////////// 

always_ff @(posedge clk) begin 
    if(rst) begin
        index <= 0;
        check <= 0;
    end else begin
            if ((index == 0) && (usedw > 0)) begin
                index <= index + 1;
                rd <= 1;
            end 
            else if ((index == 1) && (usedw > 0)) begin
                index <= index + 1;
                rd <= 1;
                if (!(rdata == 8'h31)) begin
                    check <= 1;
                end
            end 
            else if ((index == 2) && (usedw > 0)) begin
                index <= index + 1;
                rd <= 1;
                if (!(rdata == 8'h32)) begin
                    check <= 1;
                end
            end 
            else if ((index == 3) && (usedw > 0)) begin
                index <= index + 1;
                rd <= 1;
                if (!(rdata == 8'h33)) begin
                    check <= 1;
                end
            end 
            else if ((index == 4) && (usedw > 0)) begin
                index <= index + 1;
                rd <= 1;
                if (!(rdata == 8'h34)) begin
                    check <= 1;
                end
            end 
            else if ((index == 5) && (usedw > 0)) begin
                index <= index + 1;
                rd <= 1;
                if (!(rdata == 8'h35)) begin
                    check <= 1;
                end
            end 
            else if ((index == 6) && (usedw > 0)) begin
                index <= index + 1;
                rd <= 1;
                if (!(rdata == 8'h36)) begin
                    check <= 1;
                end
            end 
            else if ((index == 7) && (usedw > 0)) begin
                index <= index + 1;
                rd <= 1;
                if (!(rdata == 8'h37)) begin
                    check <= 1;
                end
            end 
            else if ((index == 8) && (usedw > 0)) begin
                index <= index + 1;
                rd <= 1;
                if (!(rdata == 8'h38)) begin
                    check <= 1;
                end
            end 
            else if ((index == 9) && (usedw > 0)) begin
                index <= 0;
                rd <= 0;
                if (!(rdata == 8'h39)) begin
                    check <= 1;
                end
            end 
    end
end

//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////
