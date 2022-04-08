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
    parameter DATA = 8,
    parameter FIFO_DEPTH = 16
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
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw,
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
localparam NUMBER_REG = 9;
localparam PHYCFGR_0 = 8'hbf;
localparam PHYCFGR_WR = 8'hff;
localparam PHYCFGR_RST = 8'h7f;
localparam PHYCFGR_AF_RST1 = 8'h78;
localparam PHYCFGR_AF_RST2 = 8'h7A;
localparam PHYCFGR_AF_RST3 = 8'hFB;
localparam PHYCFGR_AF_RST4 = 8'hFE;
localparam PHYCFGR_AF_RST5 = 8'hF8;
localparam PHYCFGR_AF_RST6 = 8'hFA;

//addr_registers
localparam ADDR_MR = 16'h0000;
localparam ADDR_IMR = 16'h0016;
localparam ADDR_IR = 16'h0015;
localparam ADDR_SIR = 16'h0017;
localparam ADDR_SIMR = 16'h0018;
localparam ADDR_GAR = 16'h0001;
localparam ADDR_SUBR = 16'h0005;
localparam ADDR_SHAR = 16'h0009;
localparam ADDR_SIPR = 16'h000f;
localparam ADDR_SN_MR = 16'h0000;
localparam ADDR_SN_CR = 16'h0001;
localparam ADDR_SN_SR = 16'h0003;
localparam ADDR_SN_IMR = 16'h002c;
localparam ADDR_SN_IR = 16'h0002;
localparam ADDR_SN_PORT = 16'h0004;
localparam ADDR_SN_RX_RSR = 16'h0026;
localparam ADDR_SN_RX_RD = 16'h0028;
localparam ADDR_PHYCFGR = 16'h002e;

//Sn_IR
localparam SN_IR_TIMEOUT = 8'h08;
localparam SN_IR_RECV = 8'h04;
localparam SN_IR_DISCON = 8'h02;
localparam SN_IR_CON = 8'h01;

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

typedef enum logic [5:0] {ST_IDLE, ST_PREPARATION, ST_RUNNING_WR_INITIAL, 
ST_RUNNING_R_RSR, ST_RUNNING_WR_RD, ST_CAPTURE_RSR, ST_RUNNING_R_RD, ST_CAPTURE_RD,
ST_RUNNING_R_CONTROL, ST_RUNNING_WR_CONTROL, ST_CAPTURE_CONTROL,
ST_RUNNING_R_INT, ST_RUNNING_WR_INT, ST_CAPTURE_INT,
ST_SEND_RECV, ST_RUNNING_R, ST_CAPTURE_MEM,
ST_RUNNING_R_IR,  ST_CAPTURE_IR,
ST_RUNNING_R_SIR,  ST_CAPTURE_SIR
} state_type;

//////////////////////////////////////////////////
//local registers
//////////////////////////////////////////////////

state_type state;
//сигналы разрешения
logic permission = 0;
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
//для для работы с памятью
logic flag_mem;
//флаги для прерываний
logic flag_read_int_ir_cap;
logic flag_read_int_ir;
logic flag_read_int_sir_cap;
logic flag_read_int_sir;

logic [15:0] index;
logic [3:0] initial_index;
logic [7:0] read_sock;
logic [7:0] read_int;
logic [7:0] read_int_ir;
logic [7:0] read_int_imr;
logic [7:0] read_int_sir;
logic [7:0] read_int_simr;
logic [7:0] read_phy;
logic [15:0] read_sn_rx_rsr;
logic [15:0] read_sn_rx_rd;

//////////////////////////////////////////////////
//Architecture
////////////////////////////////////////////////// 

//state machine
always_ff @(posedge clk) begin
    if (rst) begin
        initial_index <= NUMBER_REG;
        index <= 0;
        wr <= 0;
        rd <= 0;
        state <= ST_PREPARATION;
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
        flag_read_int_ir <= 0;
        flag_read_int_ir_cap <= 0;
        flag_read_int_sir <= 0;
        flag_read_int_sir_cap <= 0;
        read_sock <= 0;
        read_int <= 8'hff;
        read_int_imr <= 8'hff;
        read_int_ir <= 8'hff;
        read_int_imr <= 8'hff;
        read_int_simr <= 8'hff;
        read_sn_rx_rsr <= 0;
        read_sn_rx_rd <= 0;
        permission <= 1;
        flag_mem <= 0;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_PREPARATION : begin
                wr3 <= 0;
                work <= 0;
                op <= 0;
                wr <= 0;
                rd <= 0;
                index <=0;
                if (permission == 1) begin
                    state <= ST_IDLE;
                end
            end
            //////////////////////////////////////////////////
            ST_IDLE : begin
                if ((initial_index != 0) && (busy == 0)) begin
                    state <= ST_RUNNING_WR_INITIAL;
                end
                else if ((flag_go_int_cap == 1) && (busy == 0)) begin
                    state <= ST_CAPTURE_INT;
                end
                else if ((flag_read_int_ir == 1) && (busy == 0)) begin
                    state <= ST_RUNNING_R_IR;
                end
                else if ((flag_read_int_ir_cap == 1) && (busy == 0)) begin
                    state <= ST_CAPTURE_IR;
                end
                else if ((flag_read_int_sir == 1) && (busy == 0)) begin
                    state <= ST_RUNNING_R_SIR;
                end
                else if ((flag_read_int_sir_cap == 1) && (busy == 0)) begin
                    state <= ST_CAPTURE_SIR;
                end
                else if ((interrupt == 0) && (busy == 0) && (read_int == 0)) begin
                    state <= ST_RUNNING_R_IR;
                end 
                else if ((interrupt == 0) && (busy == 0)) begin
                    if (flag_control_int == 1) begin
                        state <= ST_RUNNING_WR_INT;
                    end
                    else begin
                        state <= ST_RUNNING_R_INT;
                    end
                end
                else if ((flag_go_control_cap == 1) && (busy == 0)) begin
                    state <= ST_CAPTURE_CONTROL;
                end
                else if ((read_sock != SOCK_ESTABLISHED) && (read_sock != SOCK_LISTEN) && (busy == 0)) begin
                    if (flag_control == 1) begin
                        state <= ST_RUNNING_WR_CONTROL;
                    end
                    else begin
                        state <= ST_RUNNING_R_CONTROL;
                    end
                end
                else if ((flag_go_recv == 1) && (busy == 0)) begin
                    state <= ST_SEND_RECV;
                end
                else if ((flag_go_rsr_cap == 1) && (busy == 0)) begin
                    state <= ST_CAPTURE_RSR;
                end
                else if ((flag_go_rd_cap == 1) && (busy == 0)) begin
                    state <= ST_CAPTURE_RD;
                end
                else if ((flag_go_rsr_rd == 1) && (busy == 0)) begin
                    state <= ST_RUNNING_R_RSR;
                end
                else if ((flag_go_rd_rd == 1) && (busy == 0)) begin
                    state <= ST_RUNNING_R_RD;
                end
                else if ((flag_go_rd_wr == 1) && (busy == 0)) begin
                    state <= ST_RUNNING_WR_RD;
                end
                else if ((flag_go_read == 1) && (busy == 0)) begin
                    state <= ST_RUNNING_R;
                end
                else if ((flag_go_mem_cap == 1)) begin
                    state <= ST_CAPTURE_MEM;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R_IR : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_PREPARATION;
                    flag_read_int_ir_cap <= 1;
                    len <= 32;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_REGULAR_REG, 1'b0, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= ADDR_IR [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= ADDR_IR [15:8]; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_CAPTURE_IR : begin  
                        state <= ST_PREPARATION;
                        flag_read_int_sir <= 1;
                        flag_read_int_ir_cap <= 0;
                        rd <= 1;
                        read_int_ir <= rdata;
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R_SIR : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_PREPARATION;
                    flag_read_int_sir <= 1;
                    len <= 32;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_REGULAR_REG, 1'b0, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= ADDR_SIR [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= ADDR_SIR [15:8]; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_CAPTURE_SIR : begin  
                        state <= ST_PREPARATION;
                        flag_read_int_sir_cap <= 0;
                        rd <= 1;
                        read_int_sir <= rdata;
            end
            //////////////////////////////////////////////////
            ST_RUNNING_WR_CONTROL : begin  
                case (read_sock)
                    SOCK_CLOSED: begin
                        if (index == 4) begin
                            wr <= 0;
                            work <= 1;
                            op <= 1;
                            state <= ST_PREPARATION;
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
                            state <= ST_PREPARATION;
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
                            state <= ST_PREPARATION;
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
                        state <= ST_PREPARATION;
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
                    state <= ST_PREPARATION;
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
                state <= ST_PREPARATION;
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
                            state <= ST_PREPARATION;
                            len <= 32;
                            flag_control_int <= 0;
                            read_sock <= 8'hff;
                            flag_control <= 0;
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
                            state <= ST_PREPARATION;
                            len <= 32;
                            flag_control_int <= 0;
                            read_sock <= 8'hff;
                            flag_control <= 0;
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
                            state <= ST_PREPARATION;
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
                            state <= ST_PREPARATION;
                            len <= 32;
                            flag_control_int <= 0;
                            read_sock <= 8'hff;
                            flag_control <= 0;
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
                        state <= ST_PREPARATION;
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
                    state <= ST_PREPARATION;
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
                        state <= ST_PREPARATION;
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
                    state <= ST_PREPARATION;
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
                    state <= ST_PREPARATION;
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
                if (index == (read_sn_rx_rsr * 2)) begin
                    state <= ST_PREPARATION;
                    flag_go_mem_cap <= 0;
                    flag_go_rd_wr <= 1;
                    rd <= 0;
                    wr3 <= 0;
                    read_sn_rx_rd <= read_sn_rx_rsr + read_sn_rx_rd;
                end
                else if ((index[0] == 0) && (usedw > 0) && (flag_mem == 0)) begin
                    rd <= 1;
                    index <= index + 1;
                    flag_mem <= 1;
                end
                else if ((index[0] == 1) && (usedw > 0) && (flag_mem == 1)) begin
                    rd <= 0;
                    wr3 <= 1;
                    wdata3 <= rdata;
                    index <= index + 1;
                    flag_mem <= 0;
                end 
                else begin
                    rd <= 0;
                    wr3 <= 0;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_PREPARATION;
                    flag_go_mem_cap <= 1;
                    flag_go_read <= 0;
                    len <= 24 + (read_sn_rx_rsr * 8);
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
                if (index == 3) begin
                    state <= ST_PREPARATION;
                    flag_go_rd_cap <= 0;
                    flag_go_read <= 1;
                end
                else if (index == 2) begin
                    rd <= 0;
                    read_sn_rx_rd [7:0] <= rdata;
                    index <= index + 1;
                end
                else if (index == 1) begin
                    rd <= 1;
                    read_sn_rx_rd [15:8] <= rdata;
                    index <= index + 1;
                end
                else if (index == 0) begin
                    rd <= 1;
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R_RD : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_PREPARATION;
                    flag_go_rd_cap <= 1;
                    flag_go_rd_rd <= 0;
                    len <= 40;
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
                if (index == 3) begin
                    state <= ST_PREPARATION;
                    flag_go_rsr_cap <= 0;
                    flag_go_rd_rd <= 1;
                end
                else if (index == 2) begin
                    rd <= 0;
                    read_sn_rx_rsr [7:0] <= rdata;
                    index <= index + 1;
                end
                else if (index == 1) begin
                    rd <= 1;
                    read_sn_rx_rsr [15:8] <= rdata;
                    index <= index + 1;
                end
                else if (index == 0) begin
                    rd <= 1;
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_RUNNING_R_RSR : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_PREPARATION;
                    flag_go_rsr_cap <= 1;
                    flag_go_rsr_rd <= 0;
                    len <= 40;
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
                                state <= ST_PREPARATION;
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
                                wdata <= {BSB_SOCKET_0_REG, 1'b1, 2'b0};
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
                                state <= ST_PREPARATION;
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
                                state <= ST_PREPARATION;
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
                                state <= ST_PREPARATION;
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
                                state <= ST_PREPARATION;
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
                                state <= ST_PREPARATION;
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
                                state <= ST_PREPARATION;
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
                                state <= ST_PREPARATION;
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
                                state <= ST_PREPARATION;
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
                        state <= ST_PREPARATION;
                    end
                endcase
            end
            //////////////////////////////////////////////////
            default : begin 
                read_int_simr <= read_int_ir + read_int_sir;
                state <= ST_PREPARATION;
            end
         endcase
    end
end


//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////