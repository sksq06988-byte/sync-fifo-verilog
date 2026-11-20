`timescale 1ns/1ps

// Synchronous FIFO with an explicit occupancy counter.
// The counter makes non-power-of-two depths legal; boundary decisions use the
// flag values from the beginning of the clock edge (no bypass behavior).
module sync_fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH = 4
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  wr_en,
    input  wire                  rd_en,
    input  wire [DATA_WIDTH-1:0] wdata,
    output reg  [DATA_WIDTH-1:0] rdata,
    output wire                  full,
    output wire                  empty
);
    function integer clog2(input integer value);
        integer remaining;
        begin
            remaining = value - 1;
            clog2 = 0;
            while (remaining > 0) begin
                clog2 = clog2 + 1;
                remaining = remaining >> 1;
            end
        end
    endfunction
    localparam integer PTR_WIDTH = (DEPTH <= 1) ? 1 : clog2(DEPTH);
    localparam integer COUNT_WIDTH = (DEPTH <= 1) ? 1 : clog2(DEPTH + 1);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] wr_ptr;
    reg [PTR_WIDTH-1:0] rd_ptr;
    reg [COUNT_WIDTH-1:0] count;
    wire do_write;
    wire do_read;

    assign empty = (count == 0);
    assign full  = (count == DEPTH);
    assign do_write = wr_en && !full;
    assign do_read  = rd_en && !empty;

    initial begin
        if (DATA_WIDTH <= 0 || DEPTH <= 0)
            $fatal(1, "DATA_WIDTH and DEPTH must be positive");
    end

    function [PTR_WIDTH-1:0] next_ptr(input [PTR_WIDTH-1:0] ptr);
        begin
            if (ptr == DEPTH - 1)
                next_ptr = {PTR_WIDTH{1'b0}};
            else
                next_ptr = ptr + 1'b1;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= {PTR_WIDTH{1'b0}};
            rd_ptr <= {PTR_WIDTH{1'b0}};
            count  <= {COUNT_WIDTH{1'b0}};
            rdata  <= {DATA_WIDTH{1'b0}};
        end else begin
            if (do_write) begin
                mem[wr_ptr] <= wdata;
                wr_ptr <= next_ptr(wr_ptr);
            end
            if (do_read) begin
                rdata <= mem[rd_ptr];
                rd_ptr <= next_ptr(rd_ptr);
            end

            case ({do_write, do_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
