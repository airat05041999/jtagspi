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
    //OUTPUT_CONTROL
    output logic [15:0] len,
    output logic op,
    output logic work,
    //INPUT_CONTROL
    input logic interrupt,
    input logic busy,
    //OUTPUT_FIFO
    output logic [(DATA-1):0] wdata,
    output logic wr,
    input logic full,
    //INPUT_FIFO
    input logic  [(DATA-1):0] rdata,
    output logic rd,
    input logic empty,
    //OUTPUT_FIFO3
    output logic [(DATA-1):0] wdata3,
    output logic wr3,
    input logic full3
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
localparam SN_IR_TIMEOUT = 8'h08;
localparam SN_IR_RECV = 8'h04;
localparam SN_IR_DISCON = 8'h02;
localparam SN_IR_CON = 8'h01;
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
localparam ADDR_SN_IR = 16'h0002;
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

typedef enum logic [4:0] {ST_IDLE, ST_RUNNING_WR_INITIAL, 
ST_RUNNING_R_RSR, ST_RUNNING_WR_RD, ST_CAPTURE_RSR, ST_RUNNING_R_RD, ST_CAPTURE_RD,
ST_RUNNING_R_CONTROL, ST_RUNNING_WR_CONTROL, ST_CAPTURE_CONTROL,
ST_RUNNING_R_INT, ST_RUNNING_WR_INT, ST_CAPTURE_INT,
ST_SEND_RECV, ST_RUNNING_R, ST_CAPTURE_MEM
} state_type;

//////////////////////////////////////////////////
//local registers
//////////////////////////////////////////////////

state_type state;
//сигналы разрешения
logic permission;
logic flag;
//флаги выбора чтения или записи 
logic flag_control_int;
logic flag_control;
//флаги перехода в состояние захвата
logic flag_go_control_cap;
logic flag_go_int_cap;
logic flag_go_mem_cap;
logic flag_go_rsr_cap;
logic flag_go_rd_cap;
//флаги перехода при передачи
logic flag_go_recv;
logic flag_go_rsr_rd;
logic flag_go_rd_rd;
logic flag_go_rd_wr;
logic flag_go_read;

logic [15:0] index;
logic [3:0] initial_index;
logic [7:0] read_sock;
logic [7:0] read_int;
logic [15:0] read_sn_rx_rsr;
logic [15:0] read_sn_rx_rd;

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
    //сделать еще иф для капчеров потому что ломается разрешение
    else if ((state != ST_IDLE) && (state != ST_CAPTURE_RD) && (state != ST_CAPTURE_INT) && (state != ST_CAPTURE_MEM) && (state != ST_CAPTURE_RSR) && (state != ST_CAPTURE_CONTROL)) begin
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
        flag_control_int <= 0;
        flag_control <= 0; 
        flag_go_control_cap <= 0;
        flag_go_int_cap <= 0;
        flag_go_mem_cap <= 0;
        flag_go_rsr_cap <= 0;
        flag_go_rd_cap <= 0;
        flag_go_recv <= 0;
        flag_go_rsr_rd <= 0;
        flag_go_rd_rd <= 0;
        flag_go_rd_wr <= 0;
        flag_go_read <= 0;
        read_sock <= 0;
        read_int <= 0;
        read_sn_rx_rsr <= 0;
        read_sn_rx_rd <= 0;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_IDLE : begin
                work <= 0;
                op <= 0;
                wr <= 0;
                rd <= 0;
                index <=0;
                if (initial_index != 0) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_RUNNING_WR_INITIAL;
                    end
                end
                else if (flag_go_int_cap == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_CAPTURE_INT;
                    end
                end
                else if (interrupt == 0) begin
                    if ((permission == 1) && (busy == 0)) begin
                        if (flag_control_int == 1) begin
                            state <= ST_RUNNING_WR_INT;
                        end
                        else begin
                            state <= ST_RUNNING_R_INT;
                        end
                    end
                end
                else if (flag_go_control_cap == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_CAPTURE_CONTROL;
                    end
                end
                else if ((read_sock != SOCK_ESTABLISHED) && (read_sock != SOCK_LISTEN)) begin
                    if ((permission == 1) && (busy == 0)) begin
                        if (flag_control == 1) begin
                            state <= ST_RUNNING_WR_CONTROL;
                        end
                        else begin
                            state <= ST_RUNNING_R_CONTROL;
                        end
                    end
                end
                else if (flag_go_recv == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_SEND_RECV;
                    end
                end
                else if (flag_go_mem_cap == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_CAPTURE_MEM;
                    end
                end
                else if (flag_go_rsr_cap == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_CAPTURE_RSR;
                    end
                end
                else if (flag_go_rd_cap == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_CAPTURE_RD;
                    end
                end
                else if (flag_go_rsr_rd == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_RUNNING_R_RSR;
                    end
                end
                else if (flag_go_rd_rd == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_RUNNING_R_RD;
                    end
                end
                else if (flag_go_rd_wr == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_RUNNING_WR_RD;
                    end
                end
                else if (flag_go_read == 1) begin
                    if ((permission == 1) && (busy == 0)) begin
                        state <= ST_RUNNING_R;
                    end
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_WR_CONTROL : begin  
                case (read_sock)
                    SOCK_CLOSED: begin
                        if (index == 4) begin
                            wr <= 0;
                            work <= 1;
                            op <= 1;
                            state <= ST_IDLE;
                            len <= 32;
                            flag_control <= 0;
                        end 
                        else if (index == 3) begin
                            wr <= 1;
                            wdata <= OPEN;
                            index <= index + 1;
                        end
                        else if (index == 2) begin
                            wr <= 1;
                            wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                            index <= index + 1;
                        end    
                        else if (index == 1) begin
                            wr <= 1;
                            wdata <= ADDR_SN_CR [7:0];
                            index <= index + 1;
                        end 
                        else if (index == 0) begin
                            wr <= 1;
                            wdata <= ADDR_SN_CR [15:8]; 
                            index <= index + 1;
                        end
                    end
                    SOCK_INIT: begin
                        if (index == 4) begin
                            wr <= 0;
                            work <= 1;
                            op <= 1;
                            state <= ST_IDLE;
                            len <= 32;
                            flag_control <= 0;
                        end 
                        else if (index == 3) begin
                            wr <= 1;
                            wdata <= LISTEN;
                            index <= index + 1;
                        end
                        else if (index == 2) begin
                            wr <= 1;
                            wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                            index <= index + 1;
                        end    
                        else if (index == 1) begin
                            wr <= 1;
                            wdata <= ADDR_SN_CR [7:0];
                            index <= index + 1;
                        end 
                        else if (index == 0) begin
                            wr <= 1;
                            wdata <= ADDR_SN_CR [15:8]; 
                            index <= index + 1;
                        end
                    end
                    SOCK_CLOSE_WAIT: begin
                        if (index == 4) begin
                            wr <= 0;
                            work <= 1;
                            op <= 1;
                            state <= ST_IDLE;
                            len <= 32;
                            flag_control <= 0;
                        end 
                        else if (index == 3) begin
                            wr <= 1;
                            wdata <= DISCON;
                            index <= index + 1;
                        end
                        else if (index == 2) begin
                            wr <= 1;
                            wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                            index <= index + 1;
                        end    
                        else if (index == 1) begin
                            wr <= 1;
                            wdata <= ADDR_SN_CR [7:0];
                            index <= index + 1;
                        end 
                        else if (index == 0) begin
                            wr <= 1;
                            wdata <= ADDR_SN_CR [15:8]; 
                            index <= index + 1;
                        end
                    end
                    default : begin
                        state <= ST_IDLE;
                        flag_control <= 0;
                    end
                endcase
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R_CONTROL : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_IDLE;
                    len <= 32;
                    flag_go_control_cap <= 1;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_SOCKET_0_REG, 1'b0, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= ADDR_SN_SR [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= ADDR_SN_SR [15:8]; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_CAPTURE_CONTROL : begin  
                state <= ST_IDLE;
                flag_control <= 1;
                flag_go_control_cap <= 0;
                rd <= 1;
                read_sock <= rdata;
            end
            //////////////////////////////////////////////////
            ST_RUNNING_WR_INT : begin  
                case (read_int)
                    SN_IR_TIMEOUT: begin
                        if (index == 4) begin
                            wr <= 0;
                            work <= 1;
                            op <= 1;
                            state <= ST_IDLE;
                            len <= 32;
                            flag_control_int <= 0;
                            read_sock <= 8'hff;
                        end 
                        else if (index == 3) begin
                            wr <= 1;
                            wdata <= SN_IR_TIMEOUT;
                            index <= index + 1;
                        end
                        else if (index == 2) begin
                            wr <= 1;
                            wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                            index <= index + 1;
                        end    
                        else if (index == 1) begin
                            wr <= 1;
                            wdata <= ADDR_SN_IR [7:0];
                            index <= index + 1;
                        end 
                        else if (index == 0) begin
                            wr <= 1;
                            wdata <= ADDR_SN_IR [15:8]; 
                            index <= index + 1;
                        end
                    end
                    SN_IR_CON: begin
                        if (index == 4) begin
                            wr <= 0;
                            work <= 1;
                            op <= 1;
                            state <= ST_IDLE;
                            len <= 32;
                            flag_control_int <= 0;
                            read_sock <= 8'hff;
                        end 
                        else if (index == 3) begin
                            wr <= 1;
                            wdata <= SN_IR_CON;
                            index <= index + 1;
                        end
                        else if (index == 2) begin
                            wr <= 1;
                            wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                            index <= index + 1;
                        end    
                        else if (index == 1) begin
                            wr <= 1;
                            wdata <= ADDR_SN_IR [7:0];
                            index <= index + 1;
                        end 
                        else if (index == 0) begin
                            wr <= 1;
                            wdata <= ADDR_SN_IR [15:8]; 
                            index <= index + 1;
                        end
                    end
                    SN_IR_RECV: begin
                        if (index == 4) begin
                            wr <= 0;
                            work <= 1;
                            op <= 1;
                            state <= ST_IDLE;
                            flag_go_rsr_rd <= 1;
                            len <= 32;
                            flag_control_int <= 0;
                        end 
                        else if (index == 3) begin
                            wr <= 1;
                            wdata <= SN_IR_RECV;
                            index <= index + 1;
                        end
                        else if (index == 2) begin
                            wr <= 1;
                            wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                            index <= index + 1;
                        end    
                        else if (index == 1) begin
                            wr <= 1;
                            wdata <= ADDR_SN_IR [7:0];
                            index <= index + 1;
                        end 
                        else if (index == 0) begin
                            wr <= 1;
                            wdata <= ADDR_SN_IR [15:8]; 
                            index <= index + 1;
                        end
                    end
                    SN_IR_DISCON: begin
                        if (index == 4) begin
                            wr <= 0;
                            work <= 1;
                            op <= 1;
                            state <= ST_IDLE;
                            len <= 32;
                            flag_control_int <= 0;
                            read_sock <= 8'hff;
                        end 
                        else if (index == 3) begin
                            wr <= 1;
                            wdata <= SN_IR_DISCON;
                            index <= index + 1;
                        end
                        else if (index == 2) begin
                            wr <= 1;
                            wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                            index <= index + 1;
                        end    
                        else if (index == 1) begin
                            wr <= 1;
                            wdata <= ADDR_SN_IR [7:0];
                            index <= index + 1;
                        end 
                        else if (index == 0) begin
                            wr <= 1;
                            wdata <= ADDR_SN_IR [15:8]; 
                            index <= index + 1;
                        end
                    end
                    default : begin
                        state <= ST_IDLE;
                        flag_control_int <= 0;
                    end
                endcase
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R_INT : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_IDLE;
                    flag_go_int_cap <= 1;
                    len <= 32;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_SOCKET_0_REG, 1'b0, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= ADDR_SN_IR [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= ADDR_SN_IR [15:8]; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_CAPTURE_INT : begin  
                        state <= ST_IDLE;
                        flag_control_int <= 1;
                        flag_go_int_cap <= 0;
                        rd <= 1;
                        read_int <= rdata;
            end
            //////////////////////////////////////////////////
            ST_SEND_RECV : begin  
                if (index == 4) begin
                    wr <= 0;
                    work <= 1;
                    op <= 1;
                    state <= ST_IDLE;
                    len <= 32;
                    flag_go_recv <= 0;
                end 
                else if (index == 3) begin
                    wr <= 1;
                    wdata <= RECV;
                    index <= index + 1;
                end
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= ADDR_SN_CR [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= ADDR_SN_CR [15:8]; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_WR_RD : begin  
                if (index == 5) begin
                    wr <= 0;
                    work <= 1;
                    op <= 1;
                    state <= ST_IDLE;
                    len <= 40;
                    flag_go_recv <= 1;
                    flag_go_rd_wr <= 0;
                end 
                else if (index == 4) begin
                    wr <= 1;
                    wdata <= read_sn_rx_rd [7:0];
                    index <= index + 1;
                end
                else if (index == 3) begin
                    wr <= 1;
                    wdata <= read_sn_rx_rd [15:8];
                    index <= index + 1;
                end
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= ADDR_SN_RX_RD [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= ADDR_SN_RX_RD [15:8]; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_CAPTURE_MEM : begin  
                if (index == read_sn_rx_rsr) begin
                    state <= ST_IDLE;
                    flag_go_mem_cap <= 0;
                    flag_go_rd_wr <= 1;
                    rd <= 0;
                    wr3 <= 0;
                    index <= 0;
                    read_sn_rx_rd <= read_sn_rx_rsr + read_sn_rx_rd;
                end
                else if (index < read_sn_rx_rsr) begin
                    rd <= 1;
                    wr3 <= 1;
                    wdata3 <= rdata;
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_IDLE;
                    flag_go_mem_cap <= 1;
                    flag_go_read <= 0;
                    len <= 24 + (read_sn_rx_rsr * 8);
                    index <= 0;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_RX_SOCKET_0_REG, 1'b0, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= read_sn_rx_rd [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= read_sn_rx_rd [15:8]; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_CAPTURE_RD : begin  
                if (index == 2) begin
                    state <= ST_IDLE;
                    flag_go_rd_cap <= 0;
                    flag_go_read <= 1;
                    rd <= 0;
                    index <= 0;
                end
                else if (index == 1) begin
                    rd <= 1;
                    read_sn_rx_rd [15:8] <= rdata;
                    index <= index + 1;
                end
                else if (index == 0) begin
                    rd <= 1;
                    read_sn_rx_rd [7:0] <= rdata;
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R_RD : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_IDLE;
                    flag_go_rd_cap <= 1;
                    flag_go_rd_rd <= 0;
                    len <= 40;
                    index <= 0;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_SOCKET_0_REG, 1'b0, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= ADDR_SN_RX_RD [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= ADDR_SN_RX_RD [15:8]; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_CAPTURE_RSR : begin  
                if (index == 2) begin
                    state <= ST_IDLE;
                    flag_go_rsr_cap <= 0;
                    flag_go_rd_rd <= 1;
                    rd <= 0;
                    index <= 0;
                end
                else if (index == 1) begin
                    rd <= 1;
                    read_sn_rx_rsr [15:8] <= rdata;
                    index <= index + 1;
                end
                else if (index == 0) begin
                    rd <= 1;
                    read_sn_rx_rsr [7:0] <= rdata;
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R_RSR : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_IDLE;
                    flag_go_rsr_cap <= 1;
                    flag_go_rsr_rd <= 0;
                    len <= 40;
                    index <= 0;
                    flag_go_rsr_rd <= 0;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_SOCKET_0_REG, 1'b0, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= ADDR_SN_RX_RSR [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= ADDR_SN_RX_RSR [15:8]; 
                    index <= index + 1;
                end
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
            default : begin 
                state <= ST_IDLE;
            end
         endcase
    end
end


//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////
