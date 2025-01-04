// 定义算术逻辑单元（ALU）模块
module alu(
    input wire [11:0] alu_control,  // ALU操作控制信号，12位，控制ALU的运算类型
    input wire [31:0] alu_src1,     // 第一个操作数（32位）
    input wire [31:0] alu_src2,     // 第二个操作数（32位）
    output wire [31:0] alu_result   // ALU计算结果（32位）
);

    // 定义ALU操作码：包括加法、减法、位移、逻辑运算等
    wire op_add, op_sub, op_slt, op_sltu, op_and, op_nor, op_or, op_xor, op_sll, op_srl, op_sra, op_lui;

    // 根据控制信号解析ALU的操作类型
    assign {op_add, op_sub, op_slt, op_sltu, op_and, op_nor, op_or, op_xor, op_sll, op_srl, op_sra, op_lui} = alu_control;
    // 从 alu_control 中解码出每个操作的控制位
    // 例如，op_add 为加法操作，op_and 为与操作，op_sll 为左移操作等

    // 中间变量，用于存储不同运算的结果
    wire [31:0] add_sub_result;     // 加法和减法结果
    wire [31:0] slt_result;         // 有符号小于比较结果
    wire [31:0] sltu_result;        // 无符号小于比较结果
    wire [31:0] and_result;         // 与运算结果
    wire [31:0] nor_result;         // 或非运算结果
    wire [31:0] or_result;          // 或运算结果
    wire [31:0] xor_result;         // 异或运算结果
    wire [31:0] sll_result;         // 逻辑左移结果
    wire [31:0] srl_result;         // 逻辑右移结果
    wire [31:0] sra_result;         // 算术右移结果
    wire [31:0] lui_result;         // LUI操作结果

    // 执行与、或、非、异或等逻辑运算
    assign and_result = alu_src1 & alu_src2;   // 与运算
    assign or_result = alu_src1 | alu_src2;    // 或运算
    assign nor_result = ~or_result;            // 或非运算
    assign xor_result = alu_src1 ^ alu_src2;   // 异或运算
    assign lui_result = {alu_src2[15:0], 16'b0};  // LUI操作，左移16位

    // 执行加法和减法
    wire [31:0] adder_a, adder_b, adder_result;
    wire adder_cin, adder_cout;

    assign adder_a = alu_src1;                // 加法操作数1
    assign adder_b = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  // 加法或减法操作数2
    assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1 : 1'b0;  // 加法器的进位输入
    assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;  // 执行加法/减法

    assign add_sub_result = adder_result;    // 加法/减法结果

    // 执行小于比较操作（有符号比较）
    assign slt_result[31:1] = 31'b0;  // 设置高位为0
    assign slt_result[0] = (alu_src1[31] & ~alu_src2[31]) | (~(alu_src1[31]^alu_src2[31]) & adder_result[31]);  // 有符号小于

    // 执行小于比较操作（无符号比较）
    assign sltu_result[31:1] = 31'b0;  // 设置高位为0
    assign sltu_result[0] = ~adder_cout;  // 无符号小于（通过加法器的进位来判断）

    // 执行位移操作
    assign sll_result = alu_src2 << alu_src1[4:0];  // 逻辑左移
    assign srl_result = alu_src2 >> alu_src1[4:0];  // 逻辑右移
    assign sra_result = ($signed(alu_src2)) >>> alu_src1[4:0];  // 算术右移（保持符号位）

    // 最终的ALU结果（根据控制信号选择对应操作的结果）
    assign alu_result = ({32{op_add | op_sub}} & add_sub_result)      // 加法或减法操作
                        | ({32{op_slt}} & slt_result)                // 有符号小于比较
                        | ({32{op_sltu}} & sltu_result)              // 无符号小于比较
                        | ({32{op_and}} & and_result)                // 与操作
                        | ({32{op_nor}} & nor_result)                // 或非操作
                        | ({32{op_or}} & or_result)                  // 或操作
                        | ({32{op_xor}} & xor_result)                // 异或操作
                        | ({32{op_sll}} & sll_result)                // 逻辑左移
                        | ({32{op_srl}} & srl_result)                // 逻辑右移
                        | ({32{op_sra}} & sra_result)                // 算术右移
                        | ({32{op_lui}} & lui_result);               // LUI操作

endmodule
