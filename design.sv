
module ram32 (
    input  logic       clk,
    input  logic       we,
    input  logic       en,
    input  logic [4:0] addr,
    input  logic [7:0] wdata,
    output logic [7:0] rdata
);
    logic [7:0] mem [0:31];

    always_ff @(posedge clk) begin
        if (we && en)
            mem[addr] <= wdata;
    end

    assign rdata = mem[addr];
endmodule
module ram128 (
    input  logic       clk,
    input  logic       we,
    input  logic [6:0] addr,
    input  logic [7:0] wdata,
    output logic [7:0] rdata
);
    logic [1:0] block_sel;
    logic [4:0] word_addr;
    logic [3:0] block_en;
    logic [7:0] rdata_arr [3:0];

    assign block_sel = addr[6:5];
    assign word_addr = addr[4:0];

    // 2-to-4 decoder: which block is active
    always_comb begin
        block_en = 4'b0000;
        block_en[block_sel] = 1'b1;
    end
genvar i;
    generate
        for (i = 0; i < 4; i++) begin : blocks
            ram32 u_ram32 (
                .clk   (clk),
                .we    (we),
                .en    (block_en[i]),
                .addr  (word_addr),
                .wdata (wdata),
                .rdata (rdata_arr[i])
            );
        end
    endgenerate

    assign rdata = rdata_arr[block_sel];
endmodule
