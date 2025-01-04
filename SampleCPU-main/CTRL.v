// 控制单元模块（CTRL），用于生成各个阶段的控制信号，管理流水线的暂停和继续
module CTRL(
    input wire rst,                       // 复位信号，高电平有效
    input wire stallreq_from_ex,          // 来自EX阶段的暂停请求
    input wire stallreq_from_id,          // 来自ID阶段的暂停请求
    output reg [5:0] stall               // 控制流水线的暂停信号，6位宽
);  

    // 解释：stall[0]为1表示没有暂停，
    // stall[1]为1表示IF阶段暂停，
    // stall[2]为1表示ID阶段暂停，
    // stall[3]为1表示EX阶段暂停，
    // stall[4]为1表示MEM阶段暂停，
    // stall[5]为1表示WB阶段暂停。

    // always块在任意输入信号变化时触发
    always @ (*) begin
        if (rst) begin
            // 如果复位信号为高电平，则清空暂停信号
            stall <= 6'b000000;   // 所有阶段均不暂停
        end
        else if (stallreq_from_ex == 1'b1) begin
            // 如果来自EX阶段的暂停请求为高电平，则从EX阶段开始暂停
            stall <= 6'b001111;   // 暂停EX、MEM、WB阶段
        end
        else if (stallreq_from_id == 1'b1) begin
            // 如果来自ID阶段的暂停请求为高电平，则从ID阶段开始暂停
            stall <= 6'b000111;   // 暂停ID、EX、MEM、WB阶段
        end
        else begin 
            // 如果没有暂停请求，则所有阶段继续执行
            stall <= 6'b000000;   // 所有阶段都继续运行
        end
    end
    
endmodule
