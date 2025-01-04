`include "lib/defines.vh"
// 执行阶段 (EX) 模块，用于执行指令中的算术、逻辑运算，并处理内存地址计算
module EX(
    input wire clk,                      // 时钟信号
    input wire rst,                      // 复位信号，高电平有效
    input wire [5:0] stall,             // 控制流水线暂停的信号
    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,  // 来自ID阶段的数据总线
    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,  // 传递给MEM阶段的数据总线
    output wire data_sram_en,            // 数据SRAM使能信号，控制是否进行内存访问
    output wire [3:0] data_sram_wen,     // 数据SRAM写使能信号，控制内存写入
    output wire [31:0] data_sram_addr,   // 数据SRAM地址
    output wire [31:0] data_sram_wdata, // 数据SRAM写数据
    output wire stallreq_from_ex,        // 来自EX阶段的暂停请求信号
    output wire ex_is_load,              // 标记是否为加载指令
    output wire [65:0] hilo_ex_to_id     // HI/LO寄存器的写回信号
);

    // 内部寄存器，用于保存来自ID阶段的数据总线
    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;

    // ALU控制信号和输入操作数的定义
    wire [31:0] ex_pc, inst;            // 指令地址和指令内容
    wire [11:0] alu_op;                 // ALU操作码，决定ALU的运算类型
    wire [2:0] sel_alu_src1;            // ALU源1的选择信号
    wire [3:0] sel_alu_src2;            // ALU源2的选择信号
    wire data_ram_en;                  // 数据内存使能信号
    wire [3:0] data_ram_wen, data_ram_readen; // 数据内存的读写使能信号
    wire rf_we;                         // 寄存器堆写使能信号
    wire [4:0] rf_waddr;                // 寄存器堆写地址
    wire sel_rf_res;                    // 控制寄存器堆选择ALU结果还是内存数据作为结果
    wire [31:0] rf_rdata1, rf_rdata2;   // 寄存器堆读取的数据
    reg is_in_delayslot;                // 用于延迟槽的标志

    // 将来自ID阶段的数据总线传递到内部寄存器
    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    // 解析来自ID阶段的数据总线，提取操作数和控制信号
    assign {
        data_ram_readen,      // 读取使能
        inst_mthi,            // mthi指令
        inst_mtlo,            // mtlo指令
        inst_multu,           // 无符号乘法指令
        inst_mult,            // 有符号乘法指令
        inst_divu,            // 无符号除法指令
        inst_div,             // 有符号除法指令
        ex_pc,                // 当前指令的PC
        inst,                 // 当前指令
        alu_op,               // ALU操作码
        sel_alu_src1,         // ALU源1选择信号
        sel_alu_src2,         // ALU源2选择信号
        data_ram_en,          // 数据内存使能
        data_ram_wen,         // 数据内存写使能
        rf_we,                // 寄存器堆写使能信号
        rf_waddr,             // 寄存器堆写地址
        sel_rf_res,           // 选择ALU结果还是内存数据
        rf_rdata1,            // 寄存器堆的读取数据1
        rf_rdata2             // 寄存器堆的读取数据2
    } = id_to_ex_bus_r;


    
      // 判断当前指令是否是加载指令
    assign ex_is_load = (inst[31:26] == 6'b10_0011) ? 1'b1 : 1'b0;

    // 立即数扩展：符号扩展、零扩展等
    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}}, inst[15:0]};  // 符号扩展（将立即数扩展为32位）
    assign imm_zero_extend = {16'b0, inst[15:0]};          // 零扩展（将立即数扩展为32位，低16位为原始数据，高16位为0）
    assign sa_zero_extend = {27'b0, inst[10:6]};            // 将sa字段扩展为32位

    // 选择ALU操作数：根据ALU源1和源2的选择信号决定源操作数
    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    // 根据选择信号 `sel_alu_src1` 选择 ALU 的第一个源操作数
    assign alu_src1 = sel_alu_src1[1] ? ex_pc :             // 如果选择PC作为源1操作数
                      sel_alu_src1[2] ? sa_zero_extend :  // 如果选择sa字段作为源1操作数
                      rf_rdata1;                           // 否则选择寄存器堆的第一个读数据

    // 根据选择信号 `sel_alu_src2` 选择 ALU 的第二个源操作数
    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :  // 如果选择符号扩展的立即数作为源2操作数
                      sel_alu_src2[2] ? 32'd8 :         // 如果选择常数8作为源2操作数
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2; // 否则选择寄存器堆的第二个读数据

    // ALU模块执行运算
    alu u_alu(
        .alu_control (alu_op),           // ALU操作控制信号
        .alu_src1    (alu_src1),         // ALU源操作数1
        .alu_src2    (alu_src2),         // ALU源操作数2
        .alu_result  (alu_result)        // ALU计算结果
    );

    // ALU结果传递到EX阶段的输出总线
    assign ex_result = alu_result;

    // 传递给MEM阶段的总线：包括内存使能信号、写使能、寄存器堆的写数据等
    assign ex_to_mem_bus = {
        data_ram_readen,      // 数据内存的读使能信号
        ex_pc,                // 当前PC值
        data_ram_en,          // 数据内存的使能信号
        data_ram_wen,         // 数据内存的写使能信号
        sel_rf_res,           // 是否从寄存器堆获取结果
        rf_we,                // 寄存器堆写使能信号
        rf_waddr,             // 寄存器堆写地址
        ex_result             // ALU计算结果或内存数据
    };

    // 将ALU计算结果或内存结果传递回ID阶段的HI/LO寄存器
    assign hilo_ex_to_id = {
        hi_wen,         // HI寄存器的写使能信号
        lo_wen,         // LO寄存器的写使能信号
        hi_data,        // HI寄存器的数据
        lo_data         // LO寄存器的数据
    };

    // 数据内存的访问使能：控制是否进行内存读写操作
    assign data_sram_en = data_ram_en;  // 数据内存使能信号直接来自EX阶段

    // 数据内存的写使能信号：根据不同的内存访问类型选择合适的使能信号
    assign data_sram_wen =   (data_ram_readen==4'b0101 && ex_result[1:0] == 2'b00 )? 4'b0001 
                            :(data_ram_readen==4'b0101 && ex_result[1:0] == 2'b01 )? 4'b0010
                            :(data_ram_readen==4'b0101 && ex_result[1:0] == 2'b10 )? 4'b0100
                            :(data_ram_readen==4'b0101 && ex_result[1:0] == 2'b11 )? 4'b1000
                            :(data_ram_readen==4'b0111 && ex_result[1:0] == 2'b00 )? 4'b0011
                            :(data_ram_readen==4'b0111 && ex_result[1:0]== 2'b10 )? 4'b1100
                            : data_ram_wen; // 如果没有上述条件，则直接选择原始的写使能信号        

// 数据内存的地址和写数据
assign data_sram_addr = ex_result;  // 内存的地址通过ALU计算的结果（ex_result）来确定

// 数据内存写数据：根据数据内存的写使能信号(data_sram_wen)，选择对应的数据
assign data_sram_wdata = data_sram_wen == 4'b1111 ? rf_rdata2 // 如果写使能为全1（写32位数据），直接写寄存器堆数据
                            : data_sram_wen == 4'b0001 ? {24'b0, rf_rdata2[7:0]} // 写低8位数据
                            : data_sram_wen == 4'b0010 ? {16'b0, rf_rdata2[7:0], 8'b0} // 写低16位数据
                            : data_sram_wen == 4'b0100 ? {8'b0, rf_rdata2[7:0], 16'b0}  // 写低24位数据
                            : data_sram_wen == 4'b1000 ? {rf_rdata2[7:0], 24'b0} // 写高8位数据
                            : data_sram_wen == 4'b0011 ? {16'b0, rf_rdata2[15:0]} // 写低16位数据
                            : data_sram_wen == 4'b1100 ? {rf_rdata2[15:0], 16'b0} // 写高16位数据
                            : 32'b0;  // 默认情况下，不写入数据，写入0

// HI/LO寄存器的写使能信号和写回数据
wire hi_wen, lo_wen, inst_mthi, inst_mtlo;  // 定义写使能信号和指令类型
wire [31:0] hi_data, lo_data;  // 定义HI/LO寄存器的数据

// 判断哪些指令需要写HI和LO寄存器
assign hi_wen = inst_divu | inst_div | inst_mult | inst_multu | inst_mthi;  // 如果是除法、乘法或mthi指令，需要写HI寄存器
assign lo_wen = inst_divu | inst_div | inst_mult | inst_multu | inst_mtlo;  // 如果是除法、乘法或mtlo指令，需要写LO寄存器

// 根据指令类型决定写入HI寄存器的数据
assign hi_data =  (inst_div | inst_divu)   ? div_result[63:32]   // 如果是除法指令，高32位为余数
                : (inst_mult | inst_multu) ? mul_result[63:32]   // 如果是乘法指令，高32位为乘法结果的高位
                : (inst_mthi)              ? rf_rdata1           // 如果是mthi指令，将寄存器数据写入HI寄存器
                : (32'b0);  // 默认为0

// 根据指令类型决定写入LO寄存器的数据
assign lo_data =  (inst_div | inst_divu)   ? div_result[31:0]   // 如果是除法指令，低32位为商
                : (inst_mult | inst_multu) ? mul_result[31:0]   // 如果是乘法指令，低32位为乘法结果的低位
                : (inst_mtlo)              ? rf_rdata1           // 如果是mtlo指令，将寄存器数据写入LO寄存器
                : (32'b0);  // 默认为0

// 将HI/LO寄存器的写使能信号和数据传递到ID阶段
assign hilo_ex_to_id = {
    hi_wen,         // HI寄存器的写使能信号（65位）
    lo_wen,         // LO寄存器的写使能信号（64位）
    hi_data,        // 写入HI寄存器的数据（63:32位）
    lo_data         // 写入LO寄存器的数据（31:0位）
};

    // MUL part
    wire inst_mult, inst_multu;  // 是否为乘法指令：有符号乘法(inst_mult) 和 无符号乘法(inst_multu)
    wire [63:0] mul_result;      // 乘法结果，64位

    // *************原有的 Booth-Wallace 乘法器部分（注释掉的部分）*************
    // wire mul_signed; // 有符号乘法标记
    // assign mul_signed =   inst_mult  ? 1 
    //                     : inst_multu ? 0 
    //                     : 0; 
    
    // wire [31:0] mul_data1, mul_data2;
    // assign mul_data1 = (inst_mult | inst_multu) ? rf_rdata1 : 32'b0;   // 如果是乘法指令，乘法源操作数1为寄存器堆的读数据1
    // assign mul_data2 = (inst_mult | inst_multu) ? rf_rdata2 : 32'b0;   // 如果是乘法指令，乘法源操作数2为寄存器堆的读数据2

    // 实例化乘法模块
    // mul u_mul(
    // 	.clk        (clk),                    // 时钟信号
    //     .resetn     (~rst),                   // 复位信号
    //     .mul_signed (mul_signed),            // 是否为有符号乘法
    //     .ina        (mul_opdata1_o),         // 乘法操作数1
    //     .inb        (mul_opdata2_o),         // 乘法操作数2
    //     .result     (mul_result)             // 乘法结果
    // );
    // ***********************************************************************  

    // 自己实现的 32 周期移位乘法器
    // ******************************************************************
    reg stallreq_for_mul;        // 乘法器暂停请求信号
    wire mul_ready_i;            // 乘法器是否准备好
    reg signed_mul_o;            // 是否进行有符号乘法标志
    reg [31:0] mul_opdata1_o;    // 乘法源操作数1
    reg [31:0] mul_opdata2_o;    // 乘法源操作数2
    reg mul_start_o;             // 是否启动乘法运算

    // 实例化自定义的乘法模块
    mymul my_mul(
        .rst            (rst),             // 复位信号
        .clk            (clk),             // 时钟信号
        .signed_mul_i   (signed_mul_o),    // 是否进行有符号乘法
        .a_o            (mul_opdata1_o),  // 乘法源操作数1
        .b_o            (mul_opdata2_o),  // 乘法源操作数2
        .start_i        (mul_start_o),     // 是否开始乘法运算
        .result_o       (mul_result),      // 乘法运算结果
        .ready_o        (mul_ready_i)      // 乘法器是否准备好
    );

    // 控制乘法操作
    always @ (*) begin
        if (rst) begin
            stallreq_for_mul = `NoStop;        // 复位时，乘法器暂停请求为不暂停
            mul_opdata1_o = `ZeroWord;         // 复位时，乘法源操作数1为0
            mul_opdata2_o = `ZeroWord;         // 复位时，乘法源操作数2为0
            mul_start_o = `MulStop;            // 复位时，乘法操作停止
            signed_mul_o = 1'b0;               // 复位时，乘法为无符号
        end else begin
            stallreq_for_mul = `NoStop;        // 默认不请求暂停
            mul_opdata1_o = `ZeroWord;         // 默认乘法源操作数1为0
            mul_opdata2_o = `ZeroWord;         // 默认乘法源操作数2为0
            mul_start_o = `MulStop;            // 默认不开始乘法
            signed_mul_o = 1'b0;               // 默认无符号乘法

            case ({inst_mult, inst_multu})      // 根据当前指令判断是否为乘法指令
                2'b10: begin
                    // 如果是有符号乘法指令
                    if (mul_ready_i == `MulResultNotReady) begin
                        // 如果乘法结果未准备好，开始乘法运算
                        mul_opdata1_o = rf_rdata1;  // 设置乘法源操作数1
                        mul_opdata2_o = rf_rdata2;  // 设置乘法源操作数2
                        mul_start_o = `MulStart;    // 开始乘法运算
                        signed_mul_o = 1'b1;        // 有符号乘法
                        stallreq_for_mul = `Stop;   // 请求暂停，等待乘法运算完成
                    end
                    else if (mul_ready_i == `MulResultReady) begin
                        // 如果乘法运算结果已准备好
                        mul_opdata1_o = rf_rdata1;  // 设置乘法源操作数1
                        mul_opdata2_o = rf_rdata2;  // 设置乘法源操作数2
                        mul_start_o = `MulStop;     // 停止乘法运算
                        signed_mul_o = 1'b1;        // 有符号乘法
                        stallreq_for_mul = `NoStop; // 解除暂停请求，继续执行
                    end
                    else begin
                        // 如果乘法器结果未准备好，则不做任何操作
                        mul_opdata1_o = `ZeroWord;
                        mul_opdata2_o = `ZeroWord;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `NoStop;
                    end
                end
                2'b01: begin
                    // 如果是无符号乘法指令
                    if (mul_ready_i == `MulResultNotReady) begin
                        // 如果乘法结果未准备好，开始乘法运算
                        mul_opdata1_o = rf_rdata1;  // 设置乘法源操作数1
                        mul_opdata2_o = rf_rdata2;  // 设置乘法源操作数2
                        mul_start_o = `MulStart;    // 开始乘法运算
                        signed_mul_o = 1'b0;        // 无符号乘法
                        stallreq_for_mul = `Stop;   // 请求暂停，等待乘法运算完成
                    end
                    else if (mul_ready_i == `MulResultReady) begin
                        // 如果乘法运算结果已准备好
                        mul_opdata1_o = rf_rdata1;  // 设置乘法源操作数1
                        mul_opdata2_o = rf_rdata2;  // 设置乘法源操作数2
                        mul_start_o = `MulStop;     // 停止乘法运算
                        signed_mul_o = 1'b0;        // 无符号乘法
                        stallreq_for_mul = `NoStop; // 解除暂停请求，继续执行
                    end
                    else begin
                        // 如果乘法器结果未准备好，则不做任何操作
                        mul_opdata1_o = `ZeroWord;
                        mul_opdata2_o = `ZeroWord;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `NoStop;
                    end
                end
                default: begin
                    // 如果当前指令不是乘法指令，则不做任何操作
                    mul_opdata1_o = `ZeroWord;
                    mul_opdata2_o = `ZeroWord;
                    mul_start_o = `MulStop;
                    signed_mul_o = 1'b0;
                    stallreq_for_mul = `NoStop;
                end
            endcase
        end
    end

    //******************************************************************

    // DIV part
    wire [63:0] div_result;          // 存储除法结果，64位（商和余数）
    wire inst_div, inst_divu;        // 判断是否为有符号除法(inst_div)或无符号除法(inst_divu)
    wire div_ready_i;                // 除法器是否准备好，表示除法是否完成
    reg stallreq_for_div;            // 控制是否需要暂停除法操作的请求信号
    assign stallreq_from_ex = stallreq_for_div | stallreq_for_mul;  // 将来自EX阶段的除法和乘法暂停请求信号合并

    reg [31:0] div_opdata1_o;        // 存储被除数（32位）
    reg [31:0] div_opdata2_o;        // 存储除数（32位）
    reg div_start_o;                 // 是否开始除法运算的控制信号
    reg signed_div_o;                // 是否进行有符号除法的标志（1表示有符号，0表示无符号）

    // 实例化除法器模块：用来执行除法操作
    div u_div(
        .rst          (rst),              // 复位信号，控制模块复位
        .clk          (clk),              // 时钟信号，驱动除法器模块的操作
        .signed_div_i (signed_div_o),     // 是否进行有符号除法的标志
        .opdata1_i    (div_opdata1_o),    // 被除数，来自寄存器堆的数据
        .opdata2_i    (div_opdata2_o),    // 除数，来自寄存器堆的数据
        .start_i      (div_start_o),      // 是否启动除法运算
        .annul_i      (1'b0),             // 是否取消除法操作，默认为0（不取消）
        .result_o     (div_result),       // 除法结果，64位（商和余数）
        .ready_o      (div_ready_i)       // 除法是否结束，1表示结果准备好，0表示结果未准备好
    );

    // 根据指令是否是除法指令，控制除法操作
    always @ (*) begin
        if (rst) begin
            // 复位时，除法器相关寄存器和信号重置
            stallreq_for_div = `NoStop;     // 不请求除法暂停
            div_opdata1_o = `ZeroWord;      // 被除数初始化为0
            div_opdata2_o = `ZeroWord;      // 除数初始化为0
            div_start_o = `DivStop;         // 除法停止
            signed_div_o = 1'b0;            // 默认进行无符号除法
        end
        else begin
            // 正常操作时
            stallreq_for_div = `NoStop;     // 默认不请求暂停
            div_opdata1_o = `ZeroWord;      // 被除数初始化为0
            div_opdata2_o = `ZeroWord;      // 除数初始化为0
            div_start_o = `DivStop;         // 默认停止除法
            signed_div_o = 1'b0;            // 默认进行无符号除法

            case ({inst_div, inst_divu})    // 根据指令判断是否为除法指令
                2'b10: begin  // 如果是有符号除法指令（inst_div）
                    if (div_ready_i == `DivResultNotReady) begin
                        // 如果除法结果未准备好，开始除法运算
                        div_opdata1_o = rf_rdata1;  // 被除数来自寄存器堆的读数据1
                        div_opdata2_o = rf_rdata2;  // 除数来自寄存器堆的读数据2
                        div_start_o = `DivStart;    // 启动除法运算
                        signed_div_o = 1'b1;        // 设置为有符号除法
                        stallreq_for_div = `Stop;   // 请求暂停，等待除法结果
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        // 如果除法结果准备好了，继续执行
                        div_opdata1_o = rf_rdata1;  // 被除数来自寄存器堆的读数据1
                        div_opdata2_o = rf_rdata2;  // 除数来自寄存器堆的读数据2
                        div_start_o = `DivStop;     // 停止除法运算
                        signed_div_o = 1'b1;        // 继续进行有符号除法
                        stallreq_for_div = `NoStop; // 解除暂停，继续执行
                    end
                    else begin
                        // 如果除法器结果未准备好，则不做任何操作
                        div_opdata1_o = `ZeroWord;  // 被除数置为0
                        div_opdata2_o = `ZeroWord;  // 除数置为0
                        div_start_o = `DivStop;     // 停止除法运算
                        signed_div_o = 1'b0;        // 设为无符号除法
                        stallreq_for_div = `NoStop; // 不请求暂停
                    end
                end
                2'b01: begin  // 如果是无符号除法指令（inst_divu）
                    if (div_ready_i == `DivResultNotReady) begin
                        // 如果除法结果未准备好，开始除法运算
                        div_opdata1_o = rf_rdata1;  // 被除数来自寄存器堆的读数据1
                        div_opdata2_o = rf_rdata2;  // 除数来自寄存器堆的读数据2
                        div_start_o = `DivStart;    // 启动除法运算
                        signed_div_o = 1'b0;        // 设置为无符号除法
                        stallreq_for_div = `Stop;   // 请求暂停，等待除法结果
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        // 如果除法结果准备好了，继续执行
                        div_opdata1_o = rf_rdata1;  // 被除数来自寄存器堆的读数据1
                        div_opdata2_o = rf_rdata2;  // 除数来自寄存器堆的读数据2
                        div_start_o = `DivStop;     // 停止除法运算
                        signed_div_o = 1'b0;        // 继续进行无符号除法
                        stallreq_for_div = `NoStop; // 解除暂停，继续执行
                    end
                    else begin
                        // 如果除法器结果未准备好，则不做任何操作
                        div_opdata1_o = `ZeroWord;  // 被除数置为0
                        div_opdata2_o = `ZeroWord;  // 除数置为0
                        div_start_o = `DivStop;     // 停止除法运算
                        signed_div_o = 1'b0;        // 设为无符号除法
                        stallreq_for_div = `NoStop; // 不请求暂停
                    end
                end
                default: begin
                    // 如果当前指令既不是有符号除法也不是无符号除法，则不做任何操作
                    div_opdata1_o = `ZeroWord;  // 被除数置为0
                    div_opdata2_o = `ZeroWord;  // 除数置为0
                    div_start_o = `DivStop;     // 停止除法运算
                    signed_div_o = 1'b0;        // 无符号除法
                    stallreq_for_div = `NoStop; // 不请求暂停
                    end
                end
                default:begin
                end
            endcase
        end
    end

    // mul_result 和 div_result 可以直接使用
endmodule