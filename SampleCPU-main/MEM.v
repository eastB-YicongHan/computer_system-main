`include "lib/defines.vh"

// MEM阶段（数据存取阶段）模块，用于执行数据内存的读写操作，并将结果传递给WB阶段
module MEM(
    input wire clk,                       // 时钟信号
    input wire rst,                       // 复位信号，高电平有效
    input wire [`StallBus-1:0] stall,    // 控制流水线暂停的信号

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,  // 来自EX阶段的数据总线
    input wire [31:0] data_sram_rdata,  // 来自数据存储器的读取数据
    
    output wire [37:0] mem_to_id,       // 传递给ID阶段的数据总线（用于回写寄存器）
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus  // 传递给WB阶段的数据总线
);

    // 内部寄存器，用于保存来自EX阶段的数据总线
    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;

    // 在时钟上升沿更新来自EX阶段的数据
    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;  // 复位时，数据清零
        end
        // 如果EX阶段暂停且MEM阶段继续，则保持数据为0
        else if (stall[3] == `Stop && stall[4] == `NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[3] == `NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;  // 否则更新为来自EX阶段的数据
        end
    end

    // 从EX阶段数据总线中提取出相关控制信号和操作数
    wire [31:0] mem_pc;               // 当前指令的PC值
    wire data_ram_en;                 // 数据内存使能信号
    wire [3:0] data_ram_wen, data_ram_readen;  // 数据内存的写使能和读使能信号
    wire rf_we;                       // 寄存器堆写使能信号
    wire [4:0] rf_waddr;              // 寄存器堆写地址
    wire [31:0] rf_wdata;             // 寄存器堆写数据
    wire [31:0] ex_result;            // ALU计算结果或内存数据

    // 解包EX阶段传来的数据总线
    assign {
        data_ram_readen,  // 数据内存读使能信号
        mem_pc,            // 当前指令的PC值
        data_ram_en,       // 数据内存使能信号
        data_ram_wen,      // 数据内存写使能信号
        rf_we,             // 寄存器堆写使能信号
        rf_waddr,          // 寄存器堆写地址
        ex_result          // ALU计算结果或内存数据
    } = ex_to_mem_bus_r;

    // 数据存储器读取的数据
    assign rf_wdata = (data_ram_readen == 4'b1111 && data_ram_en == 1'b1) ? data_sram_rdata // 全部4字节读
                      : (data_ram_readen == 4'b0001 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b00) ? { {24{data_sram_rdata[7]}}, data_sram_rdata[7:0]}  // 读一个字节，并符号扩展
                      : (data_ram_readen == 4'b0001 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b01) ? { {24{data_sram_rdata[15]}}, data_sram_rdata[15:8]} // 读一个字节，并符号扩展
                      : (data_ram_readen == 4'b0001 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b10) ? { {24{data_sram_rdata[23]}}, data_sram_rdata[23:16]} // 读一个字节，并符号扩展
                      : (data_ram_readen == 4'b0001 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b11) ? { {24{data_sram_rdata[31]}}, data_sram_rdata[31:24]} // 读一个字节，并符号扩展
                      : (data_ram_readen == 4'b0010 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b00) ? { 24'b0, data_sram_rdata[7:0]} // 读低字节，并零扩展
                      : (data_ram_readen == 4'b0010 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b01) ? { 24'b0, data_sram_rdata[15:8]} // 读低字节，并零扩展
                      : (data_ram_readen == 4'b0010 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b10) ? { 24'b0, data_sram_rdata[23:16]} // 读低字节，并零扩展
                      : (data_ram_readen == 4'b0010 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b11) ? { 24'b0, data_sram_rdata[31:24]} // 读低字节，并零扩展
                      : (data_ram_readen == 4'b0011 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b00) ? { {16{data_sram_rdata[15]}}, data_sram_rdata[15:0]} // 读两个字节并符号扩展
                      : (data_ram_readen == 4'b0011 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b10) ? { {16{data_sram_rdata[31]}}, data_sram_rdata[31:16]} // 读两个字节并符号扩展
                      : (data_ram_readen == 4'b0100 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b00) ? { 16'b0, data_sram_rdata[15:0]}  // 读两个字节并零扩展
                      : (data_ram_readen == 4'b0100 && data_ram_en == 1'b1 && ex_result[1:0] == 2'b10) ? { 16'b0, data_sram_rdata[31:16]}  // 读两个字节并零扩展
                      : ex_result;   // 默认情况下，返回ALU计算结果

    // 输出给WB阶段的数据总线：包含PC、寄存器堆的写使能信号、写地址和写数据
    assign mem_to_wb_bus = {
        mem_pc,      // 当前指令的PC值
        rf_we,       // 寄存器堆写使能信号
        rf_waddr,    // 寄存器堆写地址
        rf_wdata     // 写入寄存器堆的数据
    };

    // 输出给ID阶段的数据总线：包含寄存器堆写使能信号、写地址和写数据
    assign mem_to_id = { 
        rf_we,       // 寄存器堆写使能信号
        rf_waddr,    // 寄存器堆写地址
        rf_wdata     // 写入寄存器堆的数据
    };

endmodule
