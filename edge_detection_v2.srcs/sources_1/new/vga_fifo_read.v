`timescale 1ns / 1ps
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

module vga_fifo_read (
    input  wire        clk_25M,
    input  wire        reset,
    
    input  wire        video_on,
    input  wire [15:0] fifo_data,   // 16-bit RGB565 pixel from Read FIFO
    
    output wire        fifo_rd_en,  // Tells the Read FIFO to pop the next pixel
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    // Request a new pixel from the FIFO on every active video clock cycle
    assign fifo_rd_en = video_on;

    // Standard FIFOs take 1 clock cycle to output data after rd_en goes high.
    // We must delay the video_on gate by 1 cycle to align with the arriving pixel.
    reg video_on_delay;
    
    always @(posedge clk_25M) begin
        if (reset) begin
            video_on_delay <= 1'b0;
        end else begin
            video_on_delay <= video_on;
        end
    end

    // Map 16-bit RGB565 to 12-bit VGA DAC
    always @(posedge clk_25M) begin
        if (reset) begin
            vga_r <= 4'd0; 
            vga_g <= 4'd0; 
            vga_b <= 4'd0;
        end else begin
            if (video_on_delay) begin
                // Extract the top 4 bits of each RGB565 channel
                vga_r <= fifo_data[15:12]; 
                vga_g <= fifo_data[10:7];  
                vga_b <= fifo_data[4:1];   
            end else begin
                // Blank the screen during HSYNC/VSYNC porches
                vga_r <= 4'd0; 
                vga_g <= 4'd0; 
                vga_b <= 4'd0;
            end
        end
    end
endmodule