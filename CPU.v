`default_nettype none
module processor( input         clk, reset,
                  output [31:0] PC,
                  input  [31:0] instruction,
                  output        WE,
                  output [31:0] address_to_mem,
                  output [31:0] data_to_mem,
                  input  [31:0] data_from_mem
                );
    wire WE3, branchBeq, branchJal, branchJalr, branchBlt, branchLui, branchAuipc, regWrite, memToReg, ALUSrc, branchOut, branchJalx, branchBequ, branchLess, Less, Zero;
    wire [2:0] immControl;
    wire [3:0] ALUControl;
    wire [31:0] WD3, immResult, srcA, srcB, RD1, next_pc, pc_imm, addr_imm, pc_inn, jalx_res, d_to_reg;
    
    ControlUnit controlUnit(instruction, branchBeq, branchJal, branchJalr, branchBlt, branchLui, branchAuipc, WE3, memToReg, WE, ALUSrc, immControl, ALUControl);
    
    assign branchLess = branchBlt & Less;
    assign branchBequ = branchBeq & Zero;
    assign branchJalx = branchJal | branchJalr;
    assign branchOut = branchLess | branchBequ | branchJalx;

    gprSet gpr_set(WE3, clk, instruction[19:15], instruction[24:20], instruction[11:7], WD3, RD1, data_to_mem);
    immDecode imm_decode(instruction[31:7], immControl, immResult);    
    mux mux_lui(branchLui, 0, RD1, srcA);
    mux mux_alu(ALUSrc, immResult, data_to_mem, srcB);
    ALU alu(srcA, srcB, ALUControl, Zero, Less, address_to_mem);
    alu_plus alu_p1(4, PC, next_pc);
    alu_plus alu_p2(immResult, PC, pc_imm);
    mux mux_jalr(branchJalr, address_to_mem, pc_imm, addr_imm);
    mux mux_out(branchOut, addr_imm, next_pc, pc_inn);
    mux mux_jalx(branchJalx, next_pc, address_to_mem, jalx_res);
    mux mux_we(memToReg, data_from_mem, jalx_res, d_to_reg);
    mux mux_auipc(branchAuipc, pc_imm, d_to_reg, WD3);
    PCount prog_count(clk, reset, pc_inn, PC);
    
endmodule
module gprSet (
    input WE3, CLK,
    input [4:0] A1, A2, A3,
    input [31:0] WD3,
    output reg [31:0] RD1, RD2);
    reg [31:0] set [31:0];
    initial begin
        set[0] = 0;
    end
    always @(*) begin
        RD1 = set[A1];
        RD2 = set[A2];
    end
    always @(posedge CLK) begin
        if(WE3 == 1 && A3 != 0) set[A3] = WD3;
    end
endmodule
module PCount (
    input clk, reset,
    input [31:0] inp,
    output reg [31:0] out);
    always @(posedge clk) begin
        if(reset == 1)
            out = 0;
        else 
            out = inp;
    end
endmodule
module mux (
    input Select, 
    input [31:0] srcA, srcB,
    output reg [31:0] MultResult );
    always @(*) begin
        if(Select == 1)
            MultResult = srcA;
        else
            MultResult = srcB;
    end
endmodule
module ALU (
    input [31:0] srcA, srcB,
    input [3:0]ALUControl,
    output reg Zero, Less,
    output reg [31:0] ALUResult);
    always @(*) begin
        case (ALUControl)
        4'b0000: ALUResult = srcA;
        4'b0001: ALUResult = srcA + srcB;
        4'b0010: ALUResult = srcA - srcB;
        4'b0011: begin
            if($signed(srcA) < $signed(srcB)) ALUResult = 1;
            else ALUResult = 0;
        end
        4'b0100: ALUResult = srcA % srcB;
        4'b0101: ALUResult = srcA / srcB;
        4'b0110: ALUResult = srcA >> srcB;
        4'b0111: ALUResult = srcA << srcB;
        4'b1000: ALUResult = $signed($signed(srcA) >>> srcB);
        4'b1001: ALUResult = srcA & srcB;
        default: ALUResult = 0;
        endcase
        if(ALUResult == 0) begin
            Zero = 1;
            Less = 0;
        end
        else begin
            Zero = 0;
            if ($signed(srcA) < $signed(srcB)) Less = 1;
        end
    end
endmodule
module alu_plus (
    input [31:0] srcA, srcB,
    output [31:0] Result);
    assign Result = srcA + srcB;
endmodule
module immDecode (
    input [31:7] immInput,
    input [2:0] immControl,
    output reg [31:0] immResult);
    always @(*) begin
        if (immControl == 1) begin
            immResult[10:0] = immInput[30:20];
            immResult[31:11] = {21{immInput[31]}};
        end
        else if (immControl == 2) begin
            immResult[31:11] = {21{immInput[31]}};
            immResult[10:5] = immInput[30:25];
            immResult[4:0] = immInput[11:7];
        end
        else if (immControl == 3) begin
            immResult[31:12] = {20{immInput[31]}};
            immResult[11] = immInput[7];
            immResult[10:5] = immInput[30:25];
            immResult[4:1] = immInput[11:8];
            immResult[0] = 0;
        end
        else if (immControl == 4) begin
            immResult[31:12] = immInput[31:12];
            immResult[11:0] = 0;
        end
        else if (immControl == 5) begin
            immResult[31:20] = {12{immInput[31]}};
            immResult[19:12] = immInput[19:12];
            immResult[11] = immInput[20];
            immResult[10:1] = immInput[30:21];
            immResult[0] = 0;
        end
        else begin
            immResult = 0;
        end
    end
endmodule
module ControlUnit (
    input [31:0] instruction,
    output reg branchBeq, branchJal, branchJalr, branchBlt, branchLui, branchAuipc, regWrite, memToReg, memWrite, ALUSrc,
    output reg [2:0] immControl,
    output reg [3:0] ALUControl);
    wire [6:0] opcode = instruction[6:0];
    wire [6:0] funtc7 = instruction[31:25];
    wire [2:0] funtc3 = instruction[14:12];
    always @(*) begin
        if(opcode == 7'b0110011)begin
            assign branchBlt = 0;
            assign branchBeq = 0;
            assign branchLui = 0;
            assign branchJal = 0;
            assign branchJalr = 0;
            assign branchAuipc = 0;
            assign regWrite = 1;
            assign memToReg = 0;
            assign memWrite = 0;
            assign ALUSrc = 0;
            assign immControl[2:0] = 0;
            if(funtc7 == 0)begin
                if(funtc3 == 0)begin
                    // add
                    assign ALUControl = 1;
                end
                else if(funtc3 == 3'b111)begin
                    // and
                    assign ALUControl = 9;
                end
                else if(funtc3 == 3'b010)begin
                    // slt
                    assign ALUControl = 3;
                end
                
                else if(funtc3 == 3'b001)begin
                    // sll
                    assign ALUControl = 7;
                end
                else if(funtc3 == 3'b101)begin
                    // srl
                    assign ALUControl = 6;
                end
            end
            else if(funtc7 == 7'b0100000)begin
                if(funtc3 == 0)begin
                    // sub
                    assign ALUControl = 2;
                end
                else if(funtc3 == 3'b101)begin
                    // sra
                    assign ALUControl = 8;
                end
            end
            else if(funtc7 == 7'b0000001)begin
                if(funtc3 == 3'b100)begin
                    //div
                    assign ALUControl = 5;
                end
                else if(funtc3 == 3'b110)begin
                    //rem
                    assign ALUControl = 4;
                end
            end
        end
        if(opcode == 7'b0010011 && funtc3 == 0)begin
            //addi
            assign branchBlt = 0;
            assign branchBeq = 0;
            assign branchLui = 0;
            assign branchJal = 0;
            assign branchJalr = 0;
            assign branchAuipc = 0;
            assign regWrite = 1;
            assign memToReg = 0;
            assign memWrite = 0;
            assign ALUSrc = 1;
            assign immControl[2:0] = 1;
            assign ALUControl = 1;
        end
        if(opcode == 7'b1100011)begin
            assign immControl[2:0] = 3;
            assign branchLui = 0;
            assign branchJal = 0;
            assign branchJalr = 0;
            assign branchAuipc = 0;
            assign regWrite = 0;
            assign memToReg = 0;
            assign memWrite = 0;
            assign ALUSrc = 0;
            if(funtc3 == 0)begin
                //beq
                assign ALUControl = 2;
                assign branchBeq = 1;
                assign branchBlt = 0;
            end
            else if(funtc3 == 3'b100)begin
                //blt
                assign ALUControl = 3;
                assign branchBlt = 1;
                assign branchBeq = 0;
            end
        end
        if(opcode == 7'b0000011 && funtc3 == 3'b010)begin
            //lw
            assign branchBlt = 0;
            assign branchBeq = 0;
            assign branchLui = 0;
            assign branchJal = 0;
            assign branchJalr = 0;
            assign branchAuipc = 0;
            assign regWrite = 1;
            assign memToReg = 1;
            assign memWrite = 0;
            assign ALUSrc = 1;
            assign immControl[2:0] = 1;
            assign ALUControl = 1;
        end
        if(opcode == 7'b0100011 && funtc3 == 3'b010)begin
            //sw
            assign branchBlt = 0;
            assign branchBeq = 0;
            assign branchLui = 0;
            assign branchJal = 0;
            assign branchJalr = 0;
            assign branchAuipc = 0;
            assign regWrite = 0;
            assign memToReg = 1;
            assign memWrite = 1;
            assign ALUSrc = 1;
            assign immControl[2:0] = 2;
            assign ALUControl = 1;
        end
        if (opcode == 7'b0110111)begin
            //lui
            assign branchBlt = 0;
            assign branchBeq = 0;
            assign branchLui = 1;
            assign branchJal = 0;
            assign branchJalr = 0;
            assign branchAuipc = 0;
            assign regWrite = 1;
            assign memToReg = 0;
            assign memWrite = 0;
            assign immControl[2:0] = 4;
            assign ALUControl = 1;
            assign ALUSrc = 1;
        end
        if(opcode == 7'b1101111)begin
            //jal
            assign branchBlt = 0;
            assign branchBeq = 0;
            assign branchLui = 0;
            assign branchJal = 1;
            assign branchJalr = 0;
            assign branchAuipc = 0;
            assign regWrite = 1;
            assign memToReg = 0;
            assign memWrite = 0;
            assign immControl[2:0] = 5;
            assign ALUControl = 1;
        end
        if(opcode == 7'b1100111)begin
            //jalr
            assign branchBlt = 0;
            assign branchBeq = 0;
            assign branchLui = 0;
            assign branchJal = 0;
            assign branchJalr = 1;
            assign branchAuipc = 0;
            assign regWrite = 1;
            assign memToReg = 0;
            assign memWrite = 0;
            assign ALUSrc = 1;
            assign immControl[2:0] = 1;
            assign ALUControl = 1;
        end
        if(opcode == 7'b0010111)begin
            //auipc
            assign branchBlt = 0;
            assign branchBeq = 0;
            assign branchLui = 0;
            assign branchJal = 0;
            assign branchJalr = 0;
            assign branchAuipc = 1;
            assign regWrite = 1;
            assign memToReg = 0;
            assign memWrite = 0;
            
            assign immControl[2:0] = 4;
            assign ALUControl = 1;
        end
    end
endmodule
`default_nettype wire