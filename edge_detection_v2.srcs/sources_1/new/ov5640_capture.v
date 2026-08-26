`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.08.2026 11:25:33
// Design Name: 
// Module Name: ov5640_capture
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

module ov5640_capture(
    input  wire        pclk,       // 56 MHz Pixel Clock from Camera
    input  wire        rst_n,      // Active low reset
    
    // Camera DVP Interface
    input  wire        vsync,      // Vertical Sync (Frame boundary)
    input  wire        href,       // Horizontal Reference (Line active)
    input  wire [7:0]  cam_data,   // 8-bit raw data from camera
    
    // Output to FIFO / SDRAM
    output reg         pixel_valid,// Goes HIGH when a full 16-bit pixel is ready
    output reg  [15:0] pixel_data  // The stitched RGB565 16-bit pixel
);

    reg [7:0] byte_latched; 
    reg       byte_flag;    

    reg vsync_prev;
    
    always @(posedge pclk or negedge rst_n) begin
        if (rst_n == 1'b0) begin  // <--- THE FIX: Explicit binary check
            byte_latched <= 8'd0;
            byte_flag    <= 1'b0;
            pixel_valid  <= 1'b0;
            pixel_data   <= 16'd0;
            vsync_prev   <= 1'b0;
        end else begin
            vsync_prev <= vsync;
            
            if (vsync == 1'b1 && vsync_prev == 1'b0) begin
                byte_flag   <= 1'b0;
                pixel_valid <= 1'b0;
            end 
            else if (href == 1'b1) begin
                if (byte_flag == 1'b0) begin
                    byte_latched <= cam_data;
                    byte_flag    <= 1'b1;
                    pixel_valid  <= 1'b0; 
                end else begin
                    pixel_data   <= {byte_latched, cam_data};
                    byte_flag    <= 1'b0;
                    pixel_valid  <= 1'b1; 
                end
            end 
            else begin
                byte_flag   <= 1'b0;
                pixel_valid <= 1'b0;
            end
        end
    end

endmodule