
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.08.2026 12:38:02
// Design Name: 
// Module Name: vga_fifo_read
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module vga_fifo_read (
    input  wire        clk_25M,
    input  wire        reset,
    
    input  wire        video_on,
    input  wire [15:0] fifo_data,
    input  wire        fifo_empty,    // [ADDED] Gatekeeper flag
    
    output wire        fifo_rd_en,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    // [ADDED] Never pop an empty FIFO
    assign fifo_rd_en = video_on & ~fifo_empty;

    reg rd_valid_delay;
    
    always @(posedge clk_25M) begin
        if (reset) rd_valid_delay <= 1'b0;
        else       rd_valid_delay <= fifo_rd_en; // [ADDED] Track actual valid reads
    end

    always @(posedge clk_25M) begin
        if (reset) begin
            vga_r <= 4'd0; vga_g <= 4'd0; vga_b <= 4'd0;
        end else if (rd_valid_delay) begin       // [MODIFIED] Only draw if data is valid
            vga_r <= fifo_data[15:12];
            vga_g <= fifo_data[10:7];
            vga_b <= fifo_data[4:1];
        end else begin
            vga_r <= 4'd0; vga_g <= 4'd0; vga_b <= 4'd0; // Output clean black, not static
        end
    end

endmodule