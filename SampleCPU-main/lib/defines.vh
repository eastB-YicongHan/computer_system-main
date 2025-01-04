// 定义不同阶段总线的位宽
`define IF_TO_ID_WD 33            // IF阶段到ID阶段的总线宽度为33位
`define ID_TO_EX_WD 169           // ID阶段到EX阶段的总线宽度为169位
`define EX_TO_MEM_WD 80           // EX阶段到MEM阶段的总线宽度为80位
`define MEM_TO_WB_WD 70           // MEM阶段到WB阶段的总线宽度为70位
`define BR_WD 33                  // 分支相关数据的总线宽度为33位
`define DATA_SRAM_WD 69           // 数据SRAM总线宽度为69位
`define WB_TO_RF_WD 38            // WB阶段到寄存器堆的总线宽度为38位

// 控制流水线暂停的信号
`define StallBus 6                // 暂停信号的宽度为6位
`define NoStop 1'b0               // 无暂停信号（低电平）
`define Stop 1'b1                 // 暂停信号（高电平）

// 定义零值常量，用于初始化寄存器等
`define ZeroWord 32'b0            // 32位的零值常量

// 定义除法器的状态
`define DivFree 2'b00             // 除法器空闲状态
`define DivByZero 2'b01           // 除法器除数为0
`define DivOn 2'b10               // 除法器正在执行除法
`define DivEnd 2'b11              // 除法器除法执行完毕
`define DivResultReady 1'b1       // 除法结果已准备好
`define DivResultNotReady 1'b0    // 除法结果未准备好
`define DivStart 1'b1             // 开始除法操作
`define DivStop 1'b0              // 停止除法操作

// 定义乘法器的状态
`define MulFree 2'b00             // 乘法器空闲状态
`define MulResultNotReady 1'b0    // 乘法结果未准备好
`define MulOn 2'b10               // 乘法器正在执行乘法
`define MulEnd 2'b11              // 乘法器乘法执行完毕
`define MulResultReady 1'b1       // 乘法结果已准备好
`define MulStop 1'b0              // 停止乘法操作
`define MulStart 1'b1             // 开始乘法操作
