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
    reg       byte_flag;    // 0 = waiting for High Byte, 1 = waiting for Low Byte

    // Edge detection for VSYNC to reset the frame
    reg vsync_prev;
    
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            byte_latched <= 8'd0;
            byte_flag    <= 1'b0;
            pixel_valid  <= 1'b0;
            pixel_data   <= 16'd0;
            vsync_prev   <= 1'b0;
        end else begin
            vsync_prev <= vsync;
            
            // If VSYNC goes HIGH (start of a new frame), reset the byte state machine
            // Note: OV5640 VSYNC polarity is positive by default in our config
            if (vsync == 1'b1 && vsync_prev == 1'b0) begin
                byte_flag   <= 1'b0;
                pixel_valid <= 1'b0;
            end 
            // Only capture data when HREF is HIGH (active video line)
            else if (href == 1'b1) begin
                if (byte_flag == 1'b0) begin
                    // Catch the High Byte
                    byte_latched <= cam_data;
                    byte_flag    <= 1'b1;
                    pixel_valid  <= 1'b0; // Pixel not complete yet
                end else begin
                    // Catch the Low Byte, stitch it, and output
                    pixel_data   <= {byte_latched, cam_data};
                    byte_flag    <= 1'b0;
                    pixel_valid  <= 1'b1; // Full 16-bit pixel is ready!
                end
            end 
            // When HREF is LOW (blanking period between lines), do not output
            else begin
                byte_flag   <= 1'b0;
                pixel_valid <= 1'b0;
            end
        end
    end

endmodule
