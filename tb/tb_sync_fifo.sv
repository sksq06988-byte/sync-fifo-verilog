`timescale 1ns/1ps

module tb_sync_fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH = 4,
    parameter integer SEED = 1,
    parameter integer RANDOM_CYCLES = 1000
);
    reg clk = 0, rst = 1, wr_en = 0, rd_en = 0;
    reg [DATA_WIDTH-1:0] wdata = 0;
    wire [DATA_WIDTH-1:0] rdata;
    wire full, empty;
    logic [DATA_WIDTH-1:0] model[$];
    logic [DATA_WIDTH-1:0] expected_rdata = 0;
    bit take_write, take_read;
    bit reset_seen = 0;
    integer writes = 0, reads = 0, discarded = 0, resets = 0;
    integer blocked_write = 0, blocked_read = 0, both = 0;
    integer empty_both = 0, full_both = 0, write_wraps = 0, read_wraps = 0;
    integer model_wp = 0, model_rp = 0, nonempty_resets = 0;
    integer i, round_number;
    reg [31:0] random_state;
    reg [31:0] request_word;
    string vcd_name;

    sync_fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en),
        .wdata(wdata), .rdata(rdata), .full(full), .empty(empty)
    );
    always #5 clk = ~clk;

    function automatic [31:0] next_random;
        begin
            random_state = random_state ^ (random_state << 13);
            random_state = random_state ^ (random_state >> 17);
            random_state = random_state ^ (random_state << 5);
            next_random = random_state;
        end
    endfunction
    function automatic [DATA_WIDTH-1:0] random_data;
        integer b;
        reg [31:0] word_value;
        begin
            for (b = 0; b < DATA_WIDTH; b = b + 1) begin
                if ((b % 32) == 0) word_value = next_random();
                random_data[b] = word_value[b % 32];
            end
        end
    endfunction

    // This is the only owner of the queue and the expected output. All
    // acceptance decisions are captured before DUT nonblocking assignments.
    always @(posedge clk) begin
        if (rst) begin
            if (!reset_seen) begin
                discarded = discarded + model.size();
                if (model.size() != 0) nonempty_resets = nonempty_resets + 1;
                resets = resets + 1;
            end
            reset_seen = 1;
            model.delete();
            expected_rdata = 0;
            model_wp = 0;
            model_rp = 0;
        end else begin
            reset_seen = 0;
            if (full !== (model.size() == DEPTH) ||
                empty !== (model.size() == 0))
                $fatal(1, "SYNC pre-edge flags disagree with model t=%0t size=%0d", $time, model.size());
            take_write = wr_en && !full;
            take_read = rd_en && !empty;
            if (wr_en && full) blocked_write = blocked_write + 1;
            if (rd_en && empty) blocked_read = blocked_read + 1;
            if (wr_en && rd_en && empty) empty_both = empty_both + 1;
            if (wr_en && rd_en && full) full_both = full_both + 1;
            if (take_read && take_write) both = both + 1;
            if (take_read) begin
                if (model.size() == 0) $fatal(1, "SYNC reference underflow");
                expected_rdata = model.pop_front();
                reads = reads + 1;
                if (model_rp == DEPTH-1) begin
                    model_rp = 0;
                    read_wraps = read_wraps + 1;
                end else model_rp = model_rp + 1;
            end
            if (take_write) begin
                if (model.size() >= DEPTH) $fatal(1, "SYNC reference overflow");
                model.push_back(wdata);
                writes = writes + 1;
                if (model_wp == DEPTH-1) begin
                    model_wp = 0;
                    write_wraps = write_wraps + 1;
                end else model_wp = model_wp + 1;
            end
        end
        #0.001;
        if (rdata !== expected_rdata)
            $fatal(1, "SYNC registered read/hold expected=%h got=%h t=%0t", expected_rdata, rdata, $time);
        if (empty !== (model.size() == 0) || full !== (model.size() == DEPTH))
            $fatal(1, "SYNC post-edge flags size=%0d full=%b empty=%b", model.size(), full, empty);
        if (dut.wr_ptr !== model_wp || dut.rd_ptr !== model_rp || dut.count !== model.size())
            $fatal(1, "SYNC pointer/count hold or wrap failure t=%0t", $time);
    end

    task automatic step(input bit w, input bit r, input logic [DATA_WIDTH-1:0] data);
        begin
            @(negedge clk);
            wr_en = w; rd_en = r; wdata = data;
            @(posedge clk);
            #0.1;
        end
    endtask
    task automatic reset_fifo;
        begin
            @(negedge clk);
            // Requests remain asserted during reset to prove reset priority.
            rst = 1; wr_en = 1; rd_en = 1;
            repeat (2) @(posedge clk);
            @(negedge clk);
            rst = 0; wr_en = 0; rd_en = 0;
            #0.1;
            $display("SYNC_RESET t=%0t resets=%0d discarded=%0d", $time, resets, discarded);
        end
    endtask
    task automatic drain;
        integer limit;
        begin
            limit = 0;
            while (model.size() != 0 && limit < DEPTH+2) begin
                step(0, 1, 0);
                limit = limit + 1;
            end
            if (model.size() != 0) $fatal(1, "SYNC drain timeout");
            step(0, 0, 0);
        end
    endtask

    initial begin
        if (DATA_WIDTH < 1 || DEPTH < 1 || RANDOM_CYCLES < 1)
            $fatal(1, "SYNC invalid test configuration");
        random_state = 32'h9e3779b9 ^ SEED;
        if (random_state == 0) random_state = 1;
        if (!$value$plusargs("VCD=%s", vcd_name)) vcd_name = "sync_fifo.vcd";
        $dumpfile(vcd_name);
        $dumpvars(0, tb_sync_fifo);
        $display("SYNC_FIFO_START WIDTH=%0d DEPTH=%0d SEED=%0d RANDOM_CYCLES=%0d", DATA_WIDTH, DEPTH, SEED, RANDOM_CYCLES);
        reset_fifo();
        step(0, 1, 0);
        step(1, 1, 'h31); // empty: write accepted, read rejected
        drain();
        for (round_number = 0; round_number < 3; round_number = round_number + 1) begin
            for (i = 0; i < DEPTH; i = i + 1) step(1, 0, random_data());
            step(1, 0, 'hfa);
            step(1, 1, 'hfb); // full: read accepted, write rejected
            drain();
        end
        if (DEPTH > 1) begin
            step(1, 0, 'h55);
            repeat (DEPTH*3) step(1, 1, random_data());
            drain();
        end
        step(1, 0, 'ha5);
        reset_fifo(); // guaranteed nonempty reset
        for (i = 0; i < RANDOM_CYCLES; i = i + 1) begin
            request_word = next_random();
            step(request_word[0], request_word[1], random_data());
            if (i == RANDOM_CYCLES/2) reset_fifo();
        end
        drain();
        step(0, 1, 0);
        step(0, 0, 0);
        if (writes != reads + discarded || model.size() != 0)
            $fatal(1, "SYNC conservation writes=%0d reads=%0d discarded=%0d", writes, reads, discarded);
        if (blocked_write == 0 || blocked_read == 0 || empty_both == 0 || full_both == 0 ||
            write_wraps == 0 || read_wraps == 0 || nonempty_resets == 0 || (DEPTH > 1 && both == 0))
            $fatal(1, "SYNC required directed coverage missing");
        $display("SYNC_COVERAGE blocked_write=%0d blocked_read=%0d empty_both=%0d full_both=%0d both=%0d write_wraps=%0d read_wraps=%0d nonempty_resets=%0d", blocked_write, blocked_read, empty_both, full_both, both, write_wraps, read_wraps, nonempty_resets);
        $display("SYNC_FIFO_PASS writes=%0d reads=%0d discarded=%0d resets=%0d", writes, reads, discarded, resets);
        $finish;
    end
    initial begin
        #((RANDOM_CYCLES + DEPTH*50 + 200)*100);
        $fatal(1, "SYNC watchdog timeout");
    end
endmodule
