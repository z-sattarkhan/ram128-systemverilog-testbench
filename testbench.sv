interface ram_if (input logic clk);
    logic       valid;
    logic       we;
    logic [6:0] addr;
    logic [7:0] wdata;
    logic [7:0] rdata;
    logic [7:0] rdata_s;   // copy of rdata taken at each clock edge
    always @(posedge clk) rdata_s <= rdata;
endinterface

class ram_txn;
    rand bit       we;
    rand bit [6:0] addr;
    rand bit [7:0] wdata;
         bit [7:0] rdata;

    function void post_randomize();
        addr = {addr[6:5], 2'b00, addr[2:0]};   // all 4 blocks, 8 words each
        if (wdata == 0) wdata = 1;
    endfunction

    function void display(string tag);
        $display("[%s] we=%0d addr=%0d wdata=%0d rdata=%0d",
                 tag, we, addr, wdata, rdata);
    endfunction
endclass

class generator;
    mailbox #(ram_txn) gen2drv;
    int count;

    function new(mailbox #(ram_txn) mb, int n);
        gen2drv = mb;
        count   = n;
    endfunction

    task run();
        ram_txn t;
        repeat (count) begin
            t = new();
            void'(t.randomize());
            gen2drv.put(t);
        end
    endtask
endclass

class driver;
    virtual ram_if vif;
    mailbox #(ram_txn) gen2drv;
    int count;

    function new(virtual ram_if v, mailbox #(ram_txn) mb, int n);
        vif     = v;
        gen2drv = mb;
        count   = n;
    endfunction

    task run();
        ram_txn t;
        repeat (count) begin
            gen2drv.get(t);
            @(posedge vif.clk); #1;
            vif.we    = t.we;
            vif.addr  = t.addr;
            vif.wdata = t.wdata;
            vif.valid = 1;
        end
        @(posedge vif.clk); #1;
        vif.valid = 0;
    endtask
endclass

class monitor;
    virtual ram_if vif;
    mailbox #(ram_txn) mon2scb;
    int count;

    function new(virtual ram_if v, mailbox #(ram_txn) mb, int n);
        vif     = v;
        mon2scb = mb;
        count   = n;
    endfunction

    task run();
        ram_txn t;
        int seen;
        seen = 0;
        while (seen < count) begin
            @(posedge vif.clk);
            if (vif.valid) begin
                t = new();
                t.we    = vif.we;
                t.addr  = vif.addr;
                t.wdata = vif.wdata;
                #2;
                t.rdata = vif.rdata_s;
                mon2scb.put(t);
                seen++;
            end
        end
    endtask
endclass

class scoreboard;
    mailbox #(ram_txn) mon2scb;
    int count;
    bit [7:0] ref_mem [0:127];
    bit       written [0:127];
    int pass_cnt, fail_cnt, skip_cnt;

    function new(mailbox #(ram_txn) mb, int n);
        mon2scb = mb;
        count   = n;
        pass_cnt = 0; fail_cnt = 0; skip_cnt = 0;
        for (int i = 0; i < 128; i++) written[i] = 0;
    endfunction

    task run();
        ram_txn t;
        repeat (count) begin
            mon2scb.get(t);
            if (t.we) begin
                ref_mem[t.addr] = t.wdata;
                written[t.addr] = 1;
            end
            else if (written[t.addr]) begin
                if (t.rdata == ref_mem[t.addr]) begin
                    pass_cnt++;
                end
                else begin
                    $display("FAIL: addr %0d expected %0d got %0d", t.addr, ref_mem[t.addr], t.rdata);
                    fail_cnt++;
                end
            end
            else skip_cnt++;
        end
        $display("SUMMARY: pass=%0d fail=%0d skipped=%0d", pass_cnt, fail_cnt, skip_cnt);
    endtask
endclass

module tb;
    logic clk = 0;
    always #5 clk = ~clk;

    ram_if vif(clk);

    ram128 dut (.clk(clk), .we(vif.we), .addr(vif.addr),
                .wdata(vif.wdata), .rdata(vif.rdata));

    mailbox #(ram_txn) mb;
    mailbox #(ram_txn) mon_mb;
    generator gen;
    driver    drv;
    monitor   mon;
    scoreboard scb;

    initial begin
        vif.valid = 0; vif.we = 0; vif.addr = 0; vif.wdata = 0;
        mb     = new();
        mon_mb = new();
        gen = new(mb, 200);
        drv = new(vif, mb, 200);
        mon = new(vif, mon_mb, 200);
        scb = new(mon_mb, 200);
        gen.run();
        fork
            drv.run();
            mon.run();
            scb.run();
        join
        #20;
        $finish;
    end
endmodule
