
`timescale 1ps/1ps

module axi_lite_ctrl (
    input                  axi_lite_resetn  ,
    output logic [17 : 0]  m_axi_araddr              , 
    input                  m_axi_arready             , 
    output logic           m_axi_arvalid             , 
    output logic [17 : 0]  m_axi_awaddr              , 
    input                  m_axi_awready             , 
    output logic           m_axi_awvalid             , 
    output logic           m_axi_bready              , 
    input        [1 : 0]   m_axi_bresp               , 
    input                  m_axi_bvalid              , 
    input        [31 : 0]  m_axi_rdata               , 
    output logic           m_axi_rready              , 
    input        [1 : 0]   m_axi_rresp               , 
    input                  m_axi_rvalid              , 
    output logic [31 : 0]  m_axi_wdata               , 
    input                  m_axi_wready              , 
    output logic [3 : 0]   m_axi_wstrb               , 
    output logic           m_axi_wvalid              , 

    input                  axi_lite_clk              ,
    input                  enable
);

localparam int unsigned AXI_ADDR_IIC_BASE     = 'h0;
localparam int unsigned AXI_ADDR_IIC_CONTROL   = AXI_ADDR_IIC_BASE + 'h100;
localparam int unsigned AXI_ADDR_IIC_SR        = AXI_ADDR_IIC_BASE + 'h104;
localparam int unsigned AXI_ADDR_IIC_TXFIFO    = AXI_ADDR_IIC_BASE + 'h108;
localparam int unsigned AXI_ADDR_IIC_RXFIFO    = AXI_ADDR_IIC_BASE + 'h10C;


typedef enum logic {IICCMD_WR=0,IICCMD_RD=1} iicCmdType_t;
typedef enum logic [1:0] {IIC_SIG_START=0,IIC_SIG_STOP,IIC_SIG_NONE} IIC_SIG_t;


wire clk = axi_lite_clk;
wire rstn = axi_lite_resetn;                  



typedef struct packed 
{
    logic [24:0] reserved;
    logic        iic_en;
    logic [5:0]  clk_div;
} IIC_SETUP_WORD_t ;


typedef enum logic [1:0] {IIC_OP_WR = 2'b01,IIC_OP_RD = 2'b10} iic_op_t;


typedef struct packed 
{
    logic [31:7] reserved; 
    logic        gc_en;
    logic        rsta;
    logic        tx_ack;
    logic        tx ;
    logic        msms  ;
    logic        tx_fifo_reset ;
    logic        en;

} IIC_CR_WORD_t ;

typedef struct packed 
{
    logic [31:8] reserved;
    logic        tx_fifo_empty;
    logic        rx_fifo_empty;
    logic        rx_fifo_full;
    logic        tx_fifo_full;
    logic        srw ;
    logic        bb  ;
    logic        aas ;
    logic        abgc;

} IIC_SR_WORD_t ;

typedef struct packed 
{
    logic [31:10] reserved;
    logic         stop;
    logic         start;
    logic [7:0]   data;

} IIC_TX_FIFO_WORD_t ;

typedef struct packed 
{
    logic [31:8] reserved;
    logic [7:0]  data;

} IIC_RX_FIFO_WORD_t ;


typedef union packed
{
    logic [31:0]     regDat;
    IIC_CR_WORD_t    cr;
    IIC_SR_WORD_t    sr;
    IIC_RX_FIFO_WORD_t tx_fifo;
    IIC_RX_FIFO_WORD_t rx_fifo;
} axi_reg_t;



enum logic [31:0] {

    ST_AXI_AR_IDLE = 0,
    ST_AXI_AR_WAIT,
    ST_AXI_AR_DONE,
    ST_AXI_AR_ERROR

} axi_ar_fsm;

enum logic [31:0] {

    ST_AXI_AW_IDLE = 0,
    ST_AXI_AW_WAIT,
    ST_AXI_AW_DONE,
    ST_AXI_AW_ERROR


} axi_aw_fsm;

enum logic [31:0] {

    ST_AXI_RSP_IDLE = 0,
    ST_AXI_RSP_WAIT,
    ST_AXI_RSP_DONE,
    ST_AXI_RSP_ERROR

} axi_rsp_fsm;



enum logic [31:0] {

    ST_AXI_WDAT_IDLE = 0,
    ST_AXI_WDAT_WAIT,
    ST_AXI_WDAT_DONE,
    ST_AXI_WDAT_ERROR


} axi_wdat_fsm;



enum logic [31:0] {

    ST_AXI_RDAT_IDLE = 0,
    ST_AXI_RDAT_WAIT,
    ST_AXI_RDAT_DONE,
    ST_AXI_RDAT_ERROR

} axi_rdat_fsm;

enum logic [31:0] {

    ST_AXICMD_IDLE,
    ST_AXICMD_AXI_RD,
    ST_AXICMD_AXI_WR,    
    ST_AXICMD_DONE,
    ST_AXICMD_ERROR
} axi_cmd_fsm;

(* mark_debug = "true" *)enum logic [31:0] {

    ST_IIC_IDLE,
    ST_IIC_DEV_ADDR0,
    ST_IIC_REG_ADDR,
    ST_IIC_RD_DEV_ADDR1,
    ST_IIC_RD_STOP_BYTECNT,
    ST_IIC_RD_WAIT_DONE,    
    ST_IIC_RD_REG_DATA,
    ST_IIC_RD_WAIT_BUS_IDLE,
    ST_IIC_WR_REG_DATA,
    ST_IIC_WR_WAIT_DONE,
    ST_IIC_DONE,
    ST_IIC_ERROR
} iic_cmd_fsm;

typedef enum logic {AXICMD_RD=0,AXICMD_WR} axiCmdType_t;
wire start_config = enable;

typedef struct packed {

    iicCmdType_t  iicCmdType;
    logic         skip_reg_addr;
    logic [6:0]   iic_dev_addr;        
    logic [7:0]   iic_reg_addr;       
    logic [7:0]   iic_dat;
          
} iic_cmd_t;

(* mark_debug = "true" *)
struct packed {

    logic setup_iic;
    logic ar_en;
    logic aw_en;
    logic rsp_en;
    logic rdat_en;
    logic wdat_en;        
    int unsigned  axi_addr;    
    axi_reg_t     axi_dat;    
    logic [1:0]   axi_rsp;
    axiCmdType_t  axiCmdType;    
    iic_cmd_t     iic_cmd;    
    int           cmdIdx;     
} main_reg;


localparam TOTAL_IIC_CMDS = 48;

iic_cmd_t [0:TOTAL_IIC_CMDS-1] cmds_list = '{                                                    
                                              {IICCMD_WR,1'b1,7'h74,8'h00 ,8'h02},
                                              {IICCMD_RD,1'b0,7'h68,8'd134,8'h00},
                                              {IICCMD_RD,1'b0,7'h68,8'd135,8'h00},
                                            {IICCMD_WR,1'b0,7'h68,  8'd0,  8'h14 },
                                            {IICCMD_WR,1'b0,7'h68,  8'd1,  8'hE4 },
                                            {IICCMD_WR,1'b0,7'h68,  8'd2,  8'hA2 },
                                            {IICCMD_WR,1'b0,7'h68,  8'd3,  8'h55 },
                                            {IICCMD_WR,1'b0,7'h68,  8'd4,  8'h12 },
                                            {IICCMD_WR,1'b0,7'h68,  8'd5,  8'h6D },                                            
                                            {IICCMD_WR,1'b0,7'h68,  8'd6,  8'h3F },
                                            {IICCMD_WR,1'b0,7'h68,  8'd7,  8'h2A },
                                            {IICCMD_WR,1'b0,7'h68,  8'd8,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68,  8'd9,  8'hC0 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd10,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd11,  8'h40 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd19,  8'h29 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd20,  8'h3E },
                                            {IICCMD_WR,1'b0,7'h68, 8'd21,  8'hFE },
                                            {IICCMD_WR,1'b0,7'h68, 8'd22,  8'hDF },
                                            {IICCMD_WR,1'b0,7'h68, 8'd23,  8'h1F },
                                            {IICCMD_WR,1'b0,7'h68, 8'd24,  8'h3F },
                                            {IICCMD_WR,1'b0,7'h68, 8'd25,  8'hA0 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd31,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd32,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd33,  8'h03 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd34,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd35,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd36,  8'h03 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd40,  8'hA0 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd41,  8'h01 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd42,  8'h37 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd43,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd44,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd45,  8'h9B },
                                            {IICCMD_WR,1'b0,7'h68, 8'd46,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd47,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68, 8'd48,  8'h9B },
                                            {IICCMD_WR,1'b0,7'h68, 8'd55,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68,8'd131,  8'h1F },
                                            {IICCMD_WR,1'b0,7'h68,8'd132,  8'h02 },
                                            {IICCMD_WR,1'b0,7'h68,8'd137,  8'h01 },
                                            {IICCMD_WR,1'b0,7'h68,8'd138,  8'h0F },
                                            {IICCMD_WR,1'b0,7'h68,8'd139,  8'hFF },
                                            {IICCMD_WR,1'b0,7'h68,8'd142,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68,8'd143,  8'h00 },
                                            {IICCMD_WR,1'b0,7'h68,8'd136,  8'h40 }, 
                                            {IICCMD_RD,1'b0,7'h68,8'd2  ,  8'h00 }, //check write if OK
                                            {IICCMD_WR,1'b1,7'h74,8'h00 ,  8'h00 } //turn off ii2 switch
      
                                            };



(* mark_debug = "true" *) enum logic [31:0] {
    
                                              ST_IDLE = 'd0,
                                              ST_RESET_TXFIFO,
                                              ST_INIT_DONE,
                                              ST_EN_IIC,
                                              ST_RUN_IIC_CMD,
                                              ST_IIC_CMD_DONE,
                                              ST_ERROR,
                                              ST_DONE
                                            } main_fsm;


`define FSM_TYPE1(task_name,STATE_NAME_REFIX,FSM_NAME,WIRE1,FSM_EN_REG,DAT_OUT,REG_OUT,WIRE2) \
task automatic task_name();\
    case(FSM_NAME)\
    STATE_NAME_REFIX``_IDLE:\
    begin\
        if (main_reg.``FSM_EN_REG)\
        begin\
            FSM_NAME <= FSM_NAME``.next();\
        end\
    end\
    STATE_NAME_REFIX``_WAIT:\
    begin\
        if ( WIRE1 )\
        begin\
            FSM_NAME <= FSM_NAME``.next();\
        end\
    end\
    STATE_NAME_REFIX``_DONE:\
    begin\
        main_reg.``FSM_EN_REG <= 'b0;\
        FSM_NAME <= FSM_NAME``.first();\
    end\
    STATE_NAME_REFIX``_ERROR:\
    begin\
        FSM_NAME <= STATE_NAME_REFIX``_ERROR;\
    end\
    default:\
    begin\
        FSM_NAME <= STATE_NAME_REFIX``_ERROR;\
    end\
    endcase\
endtask\
always_comb\
begin\
    DAT_OUT =  main_reg.``REG_OUT;\
    WIRE2    = FSM_NAME == STATE_NAME_REFIX``_WAIT;\
end


`define FSM_TYPE2(task_name,STATE_NAME_REFIX,FSM_NAME,WIRE1,FSM_EN_REG,WIRE2,SAVE_REG,READ_DATA,WIRE3)\
task automatic task_name();\
    case(FSM_NAME)\
    STATE_NAME_REFIX``_IDLE:\
    begin\
        if (main_reg.``FSM_EN_REG)\
        begin\
            FSM_NAME <= FSM_NAME``.next();\
        end\
    end\
    STATE_NAME_REFIX``_WAIT:\
    begin\
        if ( WIRE1 )\
        begin\
            main_reg.``SAVE_REG <= READ_DATA;\
            FSM_NAME <= FSM_NAME``.next();\
        end\
    end\
    STATE_NAME_REFIX``_DONE:\
    begin\
        main_reg.``FSM_EN_REG <= 'b0;\
        FSM_NAME <= FSM_NAME``.first();\
    end\
    STATE_NAME_REFIX``_ERROR:\
    begin\
        FSM_NAME <= STATE_NAME_REFIX``_ERROR;\
    end\
    default:\
    begin\
        FSM_NAME <= STATE_NAME_REFIX``_ERROR;\
    end\
    endcase\
endtask\
always_comb\
begin\
    WIRE3    = FSM_NAME == STATE_NAME_REFIX``_WAIT;\
end

`FSM_TYPE1(axi_ar_op,ST_AXI_AR,axi_ar_fsm,m_axi_arready,ar_en,m_axi_araddr,axi_addr,m_axi_arvalid)

`FSM_TYPE1(axi_aw_op,ST_AXI_AW,axi_aw_fsm,m_axi_awready,aw_en,m_axi_awaddr,axi_addr,m_axi_awvalid)

`FSM_TYPE2(axi_rsp_op,ST_AXI_RSP,axi_rsp_fsm,m_axi_bvalid,rsp_en,m_axi_bvalid,axi_rsp,m_axi_bresp,m_axi_bready)

`FSM_TYPE2(axi_rdat_op,ST_AXI_RDAT,axi_rdat_fsm,m_axi_rvalid,rdat_en,m_axi_rvalid,axi_dat,m_axi_rdata,m_axi_rready)

`FSM_TYPE1(axi_wdat_op,ST_AXI_WDAT,axi_wdat_fsm,m_axi_wready,wdat_en,m_axi_wdata,axi_dat,m_axi_wvalid)
always_comb m_axi_wstrb = '1;


task automatic axi_cmd_op();

    case(axi_cmd_fsm)
    ST_AXICMD_IDLE:
    begin
        if (main_reg.axiCmdType == AXICMD_RD) 
        begin
           main_reg.ar_en <= 'd1;
           main_reg.rdat_en <= 'd1;
           axi_cmd_fsm <= ST_AXICMD_AXI_RD;
        end
        else
        begin
           main_reg.aw_en <= 'd1;
           main_reg.wdat_en <= 'd1;
           main_reg.rsp_en <= 'd1;
           axi_cmd_fsm <= ST_AXICMD_AXI_WR;
        end
    end
    ST_AXICMD_AXI_RD:
    begin
        axi_ar_op();
        axi_rdat_op();
        if ( (main_reg.ar_en == 'd0) && (main_reg.rdat_en == 'd0) )
        begin
            axi_cmd_fsm <= ST_AXICMD_DONE;
        end            
    end
    ST_AXICMD_AXI_WR:
    begin
        axi_aw_op();
        axi_wdat_op();
        axi_rsp_op();
        if ( (main_reg.aw_en == 'd0) && (main_reg.wdat_en == 'd0) && (main_reg.rsp_en == 'd0))
        begin
            axi_cmd_fsm <= ST_AXICMD_DONE;
        end  
    end
    ST_AXICMD_DONE:
    begin
         axi_cmd_fsm <=  axi_cmd_fsm.first();
    end
    ST_AXICMD_ERROR:
    begin
        axi_cmd_fsm <= ST_AXICMD_ERROR;
    end
    default:
    begin
        axi_cmd_fsm <= ST_AXICMD_ERROR;
    end
    endcase
endtask

function automatic IIC_CR_WORD_t genIICCtrl();

    genIICCtrl               = 'd0;
    genIICCtrl.en            = 'b1;
    genIICCtrl.tx_fifo_reset = 1'b0;
    genIICCtrl.gc_en         = 'b0;

endfunction

function automatic IIC_TX_FIFO_WORD_t genTX_FIFO_Cmd(IIC_SIG_t iic_signal,logic [7:0] data);

    genTX_FIFO_Cmd = 'd0;

    if (iic_signal == IIC_SIG_START) 
        genTX_FIFO_Cmd.start = 'b1;
    else if (iic_signal == IIC_SIG_STOP)
        genTX_FIFO_Cmd.stop = 'b1;

    genTX_FIFO_Cmd.data  = data;

endfunction

function automatic IIC_TX_FIFO_WORD_t genTX_Decvie_cmd(IIC_SIG_t iic_signal,logic [6:0] devAddr,iicCmdType_t opType);

    genTX_Decvie_cmd = 'd0;

    if (iic_signal == IIC_SIG_START) 
        genTX_Decvie_cmd.start = 'b1;
    else if (iic_signal == IIC_SIG_STOP)
        genTX_Decvie_cmd.stop = 'b1;
    
    genTX_Decvie_cmd.data  = {devAddr,opType};

endfunction



task automatic iic_op();

    case(iic_cmd_fsm)
    ST_IIC_IDLE:
    begin
        main_reg.axiCmdType      <= AXICMD_WR;
        main_reg.axi_addr        <= AXI_ADDR_IIC_TXFIFO;   
        main_reg.axi_dat.tx_fifo <= genTX_Decvie_cmd(IIC_SIG_START,main_reg.iic_cmd.iic_dev_addr ,IICCMD_WR);
        iic_cmd_fsm              <= ST_IIC_DEV_ADDR0;
                         
    end
    ST_IIC_DEV_ADDR0:
    begin
        axi_cmd_op();
        if (axi_cmd_fsm == ST_AXICMD_DONE) 
        begin
            if (main_reg.iic_cmd.skip_reg_addr) 
            begin
                main_reg.axiCmdType      <= AXICMD_WR;
                main_reg.axi_addr        <= AXI_ADDR_IIC_TXFIFO;
                main_reg.axi_dat.tx_fifo <= genTX_FIFO_Cmd(IIC_SIG_STOP, main_reg.iic_cmd.iic_dat);
                iic_cmd_fsm              <= ST_IIC_WR_REG_DATA;
            end
            else
            begin
                main_reg.axiCmdType      <= AXICMD_WR;
                main_reg.axi_addr        <= AXI_ADDR_IIC_TXFIFO;
                main_reg.axi_dat.tx_fifo <= genTX_FIFO_Cmd(IIC_SIG_NONE,main_reg.iic_cmd.iic_reg_addr);
                iic_cmd_fsm              <= ST_IIC_REG_ADDR;
            end
        end
    end
    ST_IIC_REG_ADDR:
    begin
        axi_cmd_op();
        if (axi_cmd_fsm == ST_AXICMD_DONE) 
        begin
            main_reg.iic_cmd.iic_dat <= main_reg.axi_dat.regDat;
            main_reg.axiCmdType      <= AXICMD_WR;
            main_reg.axi_addr        <= AXI_ADDR_IIC_TXFIFO;  
                         
            if (main_reg.iic_cmd.iicCmdType == IICCMD_RD) 
            begin
                main_reg.axi_dat.tx_fifo <= genTX_Decvie_cmd(IIC_SIG_START,main_reg.iic_cmd.iic_dev_addr,IICCMD_RD);                           
                iic_cmd_fsm           <= ST_IIC_RD_DEV_ADDR1;
            end
            else
            begin
                main_reg.axiCmdType      <= AXICMD_WR;
                main_reg.axi_addr        <= AXI_ADDR_IIC_TXFIFO;                
                main_reg.axi_dat.tx_fifo <= genTX_FIFO_Cmd(IIC_SIG_STOP, main_reg.iic_cmd.iic_dat);
                iic_cmd_fsm               <= ST_IIC_WR_REG_DATA;
            end
            
        end
    end
    ST_IIC_RD_DEV_ADDR1:
    begin
        axi_cmd_op();
        if (axi_cmd_fsm == ST_AXICMD_DONE) 
        begin
            main_reg.axiCmdType      <= AXICMD_WR;
            main_reg.axi_addr        <= AXI_ADDR_IIC_TXFIFO;
            main_reg.axi_dat.tx_fifo <= genTX_FIFO_Cmd(IIC_SIG_STOP,8'd1);                        
            iic_cmd_fsm              <= ST_IIC_RD_STOP_BYTECNT;
        end
    end
    ST_IIC_RD_STOP_BYTECNT:
    begin
        axi_cmd_op();
        if (axi_cmd_fsm == ST_AXICMD_DONE) 
        begin
            main_reg.axiCmdType      <= AXICMD_RD;
            main_reg.axi_addr        <= AXI_ADDR_IIC_SR;
            main_reg.axi_dat.tx_fifo <= 'b0;  
            iic_cmd_fsm              <= ST_IIC_RD_WAIT_DONE;
        end

    end
    ST_IIC_RD_WAIT_DONE:
    begin
        axi_cmd_op();
        if (axi_cmd_fsm == ST_AXICMD_DONE) 
        begin  
            if (!main_reg.axi_dat.sr.rx_fifo_empty)
            begin
                main_reg.axiCmdType  <= AXICMD_RD;
                main_reg.axi_addr    <= AXI_ADDR_IIC_RXFIFO;   
                iic_cmd_fsm          <= ST_IIC_RD_REG_DATA;      
            end
            else
            begin
                main_reg.axiCmdType   <= AXICMD_RD;
                main_reg.axi_addr     <= AXI_ADDR_IIC_SR;            
                iic_cmd_fsm           <= ST_IIC_RD_WAIT_DONE;
            end
        end
    end    
    ST_IIC_RD_REG_DATA:
    begin
        axi_cmd_op();
        if (axi_cmd_fsm == ST_AXICMD_DONE) 
        begin
            main_reg.iic_cmd.iic_dat <= main_reg.axi_dat.regDat;
            main_reg.axiCmdType      <= AXICMD_RD;
            main_reg.axi_addr        <= AXI_ADDR_IIC_SR;
            main_reg.axi_dat.tx_fifo <= 'b0;  
            iic_cmd_fsm              <= ST_IIC_RD_WAIT_BUS_IDLE;       
        end
    end
    ST_IIC_RD_WAIT_BUS_IDLE:
    begin
        axi_cmd_op();
        if (axi_cmd_fsm == ST_AXICMD_DONE) 
        begin
            if (!main_reg.axi_dat.sr.bb)
            begin
                iic_cmd_fsm          <= ST_IIC_DONE;      
            end
            else
            begin
                main_reg.axiCmdType   <= AXICMD_RD;
                main_reg.axi_addr     <= AXI_ADDR_IIC_SR;            
                iic_cmd_fsm           <= ST_IIC_RD_WAIT_BUS_IDLE;
            end        
        end
    end
    ST_IIC_WR_REG_DATA:
    begin
        axi_cmd_op();
        if (axi_cmd_fsm == ST_AXICMD_DONE) 
        begin
            main_reg.axiCmdType  <= AXICMD_RD;
            main_reg.axi_addr    <= AXI_ADDR_IIC_SR;   
            iic_cmd_fsm          <= ST_IIC_WR_WAIT_DONE;                
        end
    end
    ST_IIC_WR_WAIT_DONE:
    begin
        axi_cmd_op();
        if (axi_cmd_fsm == ST_AXICMD_DONE) 
        begin
            if (main_reg.axi_dat.sr.tx_fifo_empty && !main_reg.axi_dat.sr.bb)
            begin
                iic_cmd_fsm          <= ST_IIC_DONE;                    
            end
            else
            begin
                main_reg.axiCmdType  <= AXICMD_RD;
                main_reg.axi_addr    <= AXI_ADDR_IIC_SR;
                iic_cmd_fsm          <= ST_IIC_WR_WAIT_DONE;   
            end            
        end
    end
    ST_IIC_DONE:
    begin
        iic_cmd_fsm          <= ST_IIC_IDLE;
    end
    ST_IIC_ERROR:
    begin
        iic_cmd_fsm <= ST_IIC_ERROR;
    end
    default:
    begin
        iic_cmd_fsm <= ST_IIC_ERROR;
    end
    endcase

endtask

function automatic IIC_SETUP_WORD_t gen_iic_setup();

    gen_iic_setup = 'd0;
    gen_iic_setup.iic_en = 1;
    gen_iic_setup.clk_div = 5;

endfunction

function automatic IIC_CR_WORD_t genIIC_Ctrl();

    genIIC_Ctrl = 'd0;
    if ( main_fsm == ST_IDLE ) 
    begin
        genIIC_Ctrl.tx_fifo_reset = 'd1;
    end        
    else if ( main_fsm == ST_RESET_TXFIFO ) 
    begin
        genIIC_Ctrl.tx_fifo_reset = 'd0;
        genIIC_Ctrl.en  = 'd1;
    end


endfunction


always_ff @(posedge clk or negedge rstn)
begin
    if (!rstn) 
    begin
        main_reg     <= 'd0;
        axi_ar_fsm   <= axi_ar_fsm.first();
        axi_aw_fsm   <= axi_aw_fsm.first();
        axi_rsp_fsm  <= axi_rsp_fsm.first();
        axi_wdat_fsm <= axi_wdat_fsm.first();
        axi_rdat_fsm <= axi_rdat_fsm.first();
        axi_cmd_fsm  <= axi_cmd_fsm.first();
        iic_cmd_fsm <= iic_cmd_fsm.first();
        main_fsm <= ST_IDLE;
    end
    else
    begin
        case(main_fsm)        
        ST_IDLE:
        begin
            if (start_config) 
            begin
                if (main_reg.setup_iic == 'd0) 
                begin
                                       
                    main_reg.axiCmdType  <= AXICMD_WR;
                    main_reg.axi_addr    <= AXI_ADDR_IIC_CONTROL;
                    main_reg.axi_dat     <= genIIC_Ctrl();
                    main_fsm              <= ST_RESET_TXFIFO;
                end
                else
                begin
                    main_reg.iic_cmd <= cmds_list[main_reg.cmdIdx];
                    main_fsm         <= ST_RUN_IIC_CMD;
                end
            end
        end
        ST_RESET_TXFIFO:
        begin
            axi_cmd_op();
            if (axi_cmd_fsm == ST_AXICMD_DONE) 
            begin
                main_reg.axiCmdType  <= AXICMD_WR;
                main_reg.axi_addr    <= AXI_ADDR_IIC_CONTROL;
                main_reg.axi_dat     <= genIIC_Ctrl();
                main_fsm <= ST_RESET_TXFIFO;
                main_fsm <= ST_INIT_DONE;
            end
        end
        ST_INIT_DONE:
        begin
            axi_cmd_op();
            if (axi_cmd_fsm == ST_AXICMD_DONE) 
            begin
                main_reg.setup_iic   <= 'd1; 
                main_reg.cmdIdx      <= 'd0;
                main_fsm <= ST_IDLE;
            end

        end
        ST_RUN_IIC_CMD:
        begin
            iic_op();
            if (iic_cmd_fsm == ST_IIC_DONE) 
            begin                
                main_reg.cmdIdx <= main_reg.cmdIdx + 'd1;
                main_fsm <= ST_IIC_CMD_DONE;
            end
        end
        ST_IIC_CMD_DONE:
        begin
            if (main_reg.cmdIdx == TOTAL_IIC_CMDS) 
            begin
                main_fsm <= ST_DONE;
            end
            else
            begin
                main_reg.iic_cmd <= cmds_list[main_reg.cmdIdx];
                main_fsm <= ST_RUN_IIC_CMD;
            end
        end            
        ST_DONE:
        begin
            main_fsm <= ST_DONE;
        end
        ST_ERROR:
        begin
            main_fsm <= ST_ERROR;
        end
        default:
        begin
            main_fsm <= ST_ERROR;
        end
        endcase
    end
end

(* mark_debug = "true" *) logic [7:0] si5328_ID0,si5328_ID1;
(* mark_debug = "true" *) logic [7:0] iic_debug_reg;

always_ff @(posedge clk or negedge rstn)
begin
    if (!rstn)
    begin
        {si5328_ID0,si5328_ID1} <= 'd0;
        iic_debug_reg <= 'd0;
    end
    else
    begin
        if (main_fsm == ST_IIC_CMD_DONE) 
        begin
            if (main_reg.iic_cmd.iicCmdType == IICCMD_RD) 
                iic_debug_reg <= main_reg.iic_cmd.iic_dat;

            if (main_reg.cmdIdx == 'd2) 
                si5328_ID0 <= main_reg.iic_cmd.iic_dat;
            else if (main_reg.cmdIdx == 'd3) 
                si5328_ID1 <= main_reg.iic_cmd.iic_dat;
        end

    end
end




endmodule


