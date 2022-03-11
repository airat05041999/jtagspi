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
    parameter DATA = 8
    )

    (
    //SYSTEM
    input logic clk,
    input logic rst,
    //INPUT_FIFO
    input logic  [(DATA-1):0] rdata,
    output logic rd,
    input logic usedw
    );


//////////////////////////////////////////////////
//local registers
//////////////////////////////////////////////////

logic [2:0] index;
logic check;

//////////////////////////////////////////////////
//Architecture
////////////////////////////////////////////////// 

always_ff @(posedge clk) begin 
    if(rst) begin
        index <= 0;
        check <= 0;
    end else begin
        if (usedw > 0) begin
            if (index == 0) begin
                rd <= 1;
            end 
            else if (index == 1) begin
                rd <= 1;
                if (!(rdata == 8'h31)) begin
                    check <= 1;
                end
            end 
            else if (index == 1) begin
                rd <= 1;
                if (!(rdata == 8'h32)) begin
                    check <= 1;
                end
            end 
                else if (index == 1) begin
                rd <= 1;
                if (!(rdata == 8'h33)) begin
                    check <= 1;
                end
            end 
                else if (index == 1) begin
                rd <= 1;
                if (!(rdata == 8'h34)) begin
                    check <= 1;
                end
            end 
                else if (index == 1) begin
                rd <= 1;
                if (!(rdata == 8'h35)) begin
                    check <= 1;
                end
            end 
                else if (index == 1) begin
                rd <= 1;
                if (!(rdata == 8'h36)) begin
                    check <= 1;
                end
            end 
                else if (index == 1) begin
                rd <= 1;
                if (!(rdata == 8'h37)) begin
                    check <= 1;
                end
            end 
                else if (index == 1) begin
                rd <= 1;
                if (!(rdata == 8'h38)) begin
                    check <= 1;
                end
            end 
                else if (index == 1) begin
                rd <= 0;
                if (!(rdata == 8'h39)) begin
                    check <= 1;
                end
            end 
        end
    end
end

//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////
