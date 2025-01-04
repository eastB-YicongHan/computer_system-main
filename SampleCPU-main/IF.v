`include "lib/defines.vh"

// IF阶段（指令获取阶段）模块，用于从指令存储器中读取指令并传递给ID阶段
module IF(
    input wire clk,                       // 时钟信号
    input wire rst,                       // 复位信号，低电平有效
    input wire [`StallBus-1:0] stall,    // 控制流水线暂停的信号

    input wire [`BR_WD-1:0] br_bus,      // 分支指令的信号，总线传递分支是否发生以及跳转地址

    output wire [`IF_TO_ID_WD-1:0] if_to_id_bus, // 传递给ID阶段的数据总线

    output wire inst_sram_en,             // 指令SRAM使能信号，控制是否进行指令存储器的访问
    output wire [3:0] inst_sram_wen,      // 指令SRAM写使能信号，控制是否写入指令存储器
    output wire [31:0] inst_sram_addr,    // 指令SRAM地址
    output wire [31:0] inst_sram_wdata    // 指令SRAM写数据
);

    // 定义PC寄存器和使能信号
    reg [31:0] pc_reg;                  // 程序计数器（PC寄存器）
    reg ce_reg;                         // PC使能信号，用来控制PC是否更新

    wire [31:0] next_pc;               // 下一个PC的值
    wire br_e;                          // 标记分支是否发生
    wire [31:0] br_addr;                // 分支跳转的地址

    // 将分支信息从 `br_bus` 信号中解包出来
    assign {br_e, br_addr} = br_bus;

    // 在时钟上升沿更新PC寄存器的值
    always @ (posedge clk) begin
        if (rst) begin
            pc_reg <= 32'hbfbf_fffc;    // 复位时，PC设置为默认值（指令集开始的地址）
        end
        else if (stall[0] == `NoStop) begin  // 如果不需要暂停，则更新PC
            pc_reg <= next_pc;             // 将下一个PC的值赋给当前PC
        end
    end

    // 在时钟上升沿更新PC使能信号
    always @ (posedge clk) begin
        if (rst) begin
            ce_reg <= 1'b0;  // 复位时，使能信号为低
        end
        else if (stall[0] == `NoStop) begin
            ce_reg <= 1'b1;  // 不需要暂停时，启用PC
        end
    end

    // 根据分支信号和当前PC值，决定下一个PC值
    assign next_pc = br_e ? br_addr : pc_reg + 32'h4;  // 如果发生分支，则跳转到br_addr；否则，PC+4

    // 指令存储器的使能信号
    assign inst_sram_en = ce_reg;                     // 当PC使能信号有效时，开启指令存储器的访问

    // 指令存储器的写使能信号：由于IF阶段只读指令，写使能为0
    assign inst_sram_wen = 4'b0;                       // 不进行写操作

    // 指令存储器的地址和写数据
    assign inst_sram_addr = pc_reg;                    // 地址为当前PC的值
    assign inst_sram_wdata = 32'b0;                    // 不进行写操作，所以写数据为0

    // 输出给ID阶段的总线，包含PC和指令使能信号
    assign if_to_id_bus = {
        ce_reg,          // PC使能信号
        pc_reg           // 当前PC的值
    };

endmodule
