`include "lib/defines.vh"

// mycpu_core模块，包含了整个CPU的主要功能模块（IF, ID, EX, MEM, WB等）
module mycpu_core(
    input wire clk,               // 时钟信号，驱动整个CPU的时序操作
    input wire rst,               // 复位信号，高电平有效，用于将CPU状态重置
    input wire [5:0] int,         // 外部中断信号，用于触发外部中断处理

    output wire inst_sram_en,     // 指令存储器使能信号，控制是否进行指令存储器的访问
    output wire [3:0] inst_sram_wen,  // 指令存储器写使能信号，指示是否向指令存储器写入数据
    output wire [31:0] inst_sram_addr, // 指令存储器的访问地址，由PC决定
    output wire [31:0] inst_sram_wdata, // 向指令存储器写入的数据（IF阶段不进行写操作，所以为0）
    input wire [31:0] inst_sram_rdata, // 从指令存储器读取的数据

    output wire data_sram_en,     // 数据存储器使能信号，控制是否进行数据存储器的访问
    output wire [3:0] data_sram_wen,  // 数据存储器写使能信号，指示是否向数据存储器写入数据
    output wire [31:0] data_sram_addr, // 数据存储器的访问地址
    output wire [31:0] data_sram_wdata, // 向数据存储器写入的数据
    input wire [31:0] data_sram_rdata, // 从数据存储器读取的数据

    output wire [31:0] debug_wb_pc, // 用于调试的WB阶段PC
    output wire [3:0] debug_wb_rf_wen, // 用于调试的WB阶段寄存器写使能信号
    output wire [4:0] debug_wb_rf_wnum, // 用于调试的WB阶段寄存器写地址
    output wire [31:0] debug_wb_rf_wdata // 用于调试的WB阶段寄存器写数据
);

    // 各个阶段的数据总线连接
    wire [`IF_TO_ID_WD-1:0] if_to_id_bus;   // IF到ID阶段的数据总线
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus;   // ID到EX阶段的数据总线
    wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus; // EX到MEM阶段的数据总线
    wire [37:0] ex_to_id;                   // EX到ID阶段的控制信号
    wire [37:0] mem_to_id;                  // MEM到ID阶段的控制信号
    wire [37:0] wb_to_id;                   // WB到ID阶段的控制信号
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus; // MEM到WB阶段的数据总线
    wire [`BR_WD-1:0] br_bus;               // 分支信号
    wire [`DATA_SRAM_WD-1:0] ex_dt_sram_bus; // EX阶段的存储器数据
    wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus;   // WB到寄存器堆的数据总线
    wire [`StallBus-1:0] stall;             // 控制暂停的信号
    wire stallreq_from_id;                  // ID阶段暂停请求
    wire stallreq_from_ex;                  // EX阶段暂停请求
    wire ex_is_load;                        // EX阶段是否为加载指令
    wire [65:0] hilo_ex_to_id;              // HI/LO寄存器的写使能信号

    // IF阶段（指令获取阶段）
    IF u_IF(
        .clk(clk),                           // 传递时钟信号
        .rst(rst),                           // 传递复位信号
        .stall(stall),                       // 传递流水线暂停信号
        .br_bus(br_bus),                     // 传递分支信号
        .if_to_id_bus(if_to_id_bus),         // 输出给ID阶段的数据总线
        .inst_sram_en(inst_sram_en),         // 输出指令存储器使能信号
        .inst_sram_wen(inst_sram_wen),       // 输出指令存储器写使能信号
        .inst_sram_addr(inst_sram_addr),     // 输出指令存储器地址
        .inst_sram_wdata(inst_sram_wdata)   // 输出指令存储器写数据（IF阶段不进行写操作）
    );

    // ID阶段（指令解码阶段）
    ID u_ID(
        .clk(clk),                           // 传递时钟信号
        .rst(rst),                           // 传递复位信号
        .stall(stall),                       // 传递流水线暂停信号
        .ex_is_load(ex_is_load),             // 判断是否为加载指令
        .stallreq(stallreq_from_id),         // 输出给EX阶段的暂停请求
        .if_to_id_bus(if_to_id_bus),         // 来自IF阶段的数据总线
        .inst_sram_rdata(inst_sram_rdata),   // 来自指令存储器的指令数据
        .wb_to_rf_bus(wb_to_rf_bus),         // 来自WB阶段的寄存器堆写数据
        .ex_to_id(ex_to_id),                 // 输出给ID阶段的控制信号
        .mem_to_id(mem_to_id),               // 输出给ID阶段的控制信号
        .wb_to_id(wb_to_id),                 // 输出给ID阶段的控制信号
        .hilo_ex_to_id(hilo_ex_to_id),       // 输出给ID阶段的HI/LO寄存器的写使能信号
        .id_to_ex_bus(id_to_ex_bus),         // 输出到EX阶段的数据总线
        .br_bus(br_bus),                     // 输出分支信号
        .stallreq_from_id(stallreq_from_id)  // 输出给EX阶段的暂停请求信号
    );

    // EX阶段（执行阶段）
    EX u_EX(
        .clk(clk),                           // 传递时钟信号
        .rst(rst),                           // 传递复位信号
        .stall(stall),                       // 传递流水线暂停信号
        .id_to_ex_bus(id_to_ex_bus),         // 来自ID阶段的数据总线
        .ex_to_mem_bus(ex_to_mem_bus),       // 输出给MEM阶段的数据总线
        .data_sram_en(data_sram_en),         // 输出数据存储器使能信号
        .data_sram_wen(data_sram_wen),       // 输出数据存储器写使能信号
        .data_sram_addr(data_sram_addr),     // 输出数据存储器地址
        .ex_to_id(ex_to_id),                 // 输出给ID阶段的控制信号
        .data_sram_wdata(data_sram_wdata),  // 输出数据存储器写数据
        .stallreq_from_ex(stallreq_from_ex), // 输出给MEM阶段的暂停请求信号
        .ex_is_load(ex_is_load),             // 输出EX阶段是否为加载指令
        .hilo_ex_to_id(hilo_ex_to_id)       // 输出EX阶段的HI/LO寄存器写使能信号
    );

    // MEM阶段（数据存取阶段）
    MEM u_MEM(
        .clk(clk),                           // 传递时钟信号
        .rst(rst),                           // 传递复位信号
        .stall(stall),                       // 传递流水线暂停信号
        .ex_to_mem_bus(ex_to_mem_bus),       // 来自EX阶段的数据总线
        .data_sram_rdata(data_sram_rdata),   // 来自数据存储器的读取数据
        .mem_to_id(mem_to_id),               // 输出给ID阶段的控制信号
        .mem_to_wb_bus(mem_to_wb_bus)        // 输出给WB阶段的数据总线
    );

// WB阶段（写回阶段）模块，用于将计算结果或内存读取结果写回到寄存器堆
WB u_WB(
    .clk               (clk),               // 时钟信号，驱动模块的时序操作
    .rst               (rst),               // 复位信号，高电平有效，用于重置模块状态
    .stall             (stall),             // 暂停信号，用于控制是否暂停此模块的操作
    .mem_to_wb_bus     (mem_to_wb_bus),     // 来自MEM阶段的数据总线，包含了存储器读取的结果、写使能等信息
    .wb_to_rf_bus      (wb_to_rf_bus),      // 输出给寄存器堆的数据总线，包括写使能信号、写地址、写数据
    .wb_to_id          (wb_to_id),          // 输出给ID阶段的数据总线，包含写回寄存器的数据
    .debug_wb_pc       (debug_wb_pc),       // 用于调试的WB阶段的PC值
    .debug_wb_rf_wen   (debug_wb_rf_wen),   // 用于调试的WB阶段寄存器堆写使能信号
    .debug_wb_rf_wnum  (debug_wb_rf_wnum),  // 用于调试的WB阶段寄存器堆写地址
    .debug_wb_rf_wdata (debug_wb_rf_wdata)  // 用于调试的WB阶段寄存器堆写数据
);

// 控制单元模块，根据来自EX阶段和ID阶段的暂停请求，控制流水线暂停信号
CTRL u_CTRL(
    .rst   (rst),                       // 复位信号
    .stallreq_from_ex  (stallreq_from_ex),  // 来自EX阶段的暂停请求信号
    .stallreq_from_id  (stallreq_from_id),  // 来自ID阶段的暂停请求信号
    .stall (stall)                     // 控制流水线暂停的信号
);

    
endmodule