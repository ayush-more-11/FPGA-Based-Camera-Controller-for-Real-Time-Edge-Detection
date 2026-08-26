//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.08.2026 11:58:47
// Design Name: 
// Module Name: top
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

module top(
    input  wire        sys_clk_50M, // 50 MHz physical oscillator from Artix-7
    input  wire        sys_rst_n,   // Active-low system reset button

    // ------------------------------------
    // Physical Camera Interface (OV5640)
    // ------------------------------------
    output wire        cam_xclk,    // 24 MHz driven to camera
    input  wire        cam_pclk,    // 56 MHz received from camera
    input  wire        cam_vsync,   // Frame sync
    input  wire        cam_href,    // Line active
    input  wire [7:0]  cam_data,    // 8-bit raw DVP data
    output wire        cam_pwdn,    // Power down pin
    output wire        cam_resetb,  // Hardware reset pin
    output wire        cam_sioc,    // SCCB (I2C) Clock
    inout  wire        cam_siod,    // SCCB (I2C) Data

    // ------------------------------------
    // Physical SDRAM Interface
    // ------------------------------------
    output wire        sdram_clk,   // 100 MHz (180-deg shifted)
    output wire        sdram_cke,
    output wire        sdram_cs_n,
    output wire        sdram_ras_n,
    output wire        sdram_cas_n,
    output wire        sdram_we_n,
    output wire [1:0]  sdram_ba,
    output wire [12:0] sdram_a,
    output wire [1:0]  sdram_dqm,
    inout  wire [15:0] sdram_dq,

    // ------------------------------------
    // Physical VGA Interface
    // ------------------------------------
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b
);

    // =======================================================
    // 1. CLOCKING WIZARD (MMCM)
    // =======================================================
    wire clk_24M;
    wire clk_25M;
    wire clk_100M;
    wire clk_100M_shift;
    
    assign cam_xclk  = clk_24M;
    assign sdram_clk = clk_100M_shift;

    clk_wiz_0 clock_generator (
        .clk_in1          (sys_clk_50M),
        .clk_24MHz        (clk_24M),
        .clk_25MHz        (clk_25M),
        .clk_100MHz       (clk_100M),
        .clk_100MHz_shift (clk_100M_shift)
    );

    // =======================================================
    // 2. POWER & CONFIGURATION (OV5640 Boot Sequence)
    // =======================================================
    wire sccb_ready;
    
    pwd power_sequencer (
        .sclk               (clk_24M),
        .s_rst_n            (sys_rst_n),
        .ov5640_pwdn        (cam_pwdn),
        .ov5640_rst_n       (cam_resetb),
        .ov5640_sccb_begin  (sccb_ready)
    );

    ov5640_config camera_config (
        .clk_24M            (clk_24M),
        .s_rst_n            (sccb_ready), 
        .iic_clk            (cam_sioc),
        .iic_sda            (cam_siod)
    );

    // =======================================================
    // 3. IMAGE CAPTURE (56 MHz Domain)
    // =======================================================
    wire        capture_valid;
    wire [15:0] capture_data;

    ov5640_capture camera_capture (
        .pclk               (cam_pclk),
        .rst_n              (sys_rst_n),
        .vsync              (cam_vsync),
        .href               (cam_href),
        .cam_data           (cam_data),
        .pixel_valid        (capture_valid),
        .pixel_data         (capture_data)
    );

    // =======================================================
    // 4. WRITE FIFO (Crossing: 56 MHz -> 100 MHz)
    // =======================================================
    wire [10:0]  sdram_wr_fifo_count;
    wire        sdram_wr_fifo_rd_en;
    wire [15:0] sdram_wr_fifo_dout;

    async_fifo_16x2048 write_fifo (
        .rst                (~sys_rst_n),          
        .wr_clk             (cam_pclk),
        .rd_clk             (clk_100M),
        .din                (capture_data),
        .wr_en              (capture_valid),
        .rd_en              (sdram_wr_fifo_rd_en),
        .dout               (sdram_wr_fifo_dout),
        .full               (),
        .empty              (),
        .rd_data_count      (sdram_wr_fifo_count), 
        .wr_data_count      () 
    );

    // =======================================================
    // 5. SDRAM CONTROLLER (100 MHz Domain)
    // =======================================================
    wire [10:0]  sdram_rd_fifo_count;
    wire        sdram_rd_fifo_wr_en;
    wire [15:0] sdram_rd_fifo_din;
    
    wire raw_hsync;
    wire raw_vsync;
    wire video_on;

    sdram_controller memory_manager (
        .clk_100M           (clk_100M),
        .rst_n              (sys_rst_n),
        
        .cam_vsync          (cam_vsync), 
        .vga_vsync          (raw_vsync), 
        
        .fifo_wr_count      (sdram_wr_fifo_count),
        .fifo_wr_rd_en      (sdram_wr_fifo_rd_en),
        .fifo_wr_data       (sdram_wr_fifo_dout),
        
        .fifo_rd_count      (sdram_rd_fifo_count),
        .fifo_rd_wr_en      (sdram_rd_fifo_wr_en),
        .fifo_rd_data       (sdram_rd_fifo_din),
        
        .sdram_cke          (sdram_cke),
        .sdram_cs_n         (sdram_cs_n),
        .sdram_ras_n        (sdram_ras_n),
        .sdram_cas_n        (sdram_cas_n),
        .sdram_we_n         (sdram_we_n),
        .sdram_ba           (sdram_ba),
        .sdram_a            (sdram_a),
        .sdram_dqm          (sdram_dqm),
        .sdram_dq           (sdram_dq)
    );

    // =======================================================
    // 6. READ FIFO (Crossing: 100 MHz -> 25 MHz)
    // =======================================================
    wire        vga_fifo_rd_en;
    wire [15:0] vga_fifo_dout;
    wire        read_fifo_empty; // Wired flag to prevent empty reads

    async_fifo_16x2048 read_fifo (
        .rst                (~sys_rst_n),
        .wr_clk             (clk_100M),
        .rd_clk             (clk_25M),
        .din                (sdram_rd_fifo_din),
        .wr_en              (sdram_rd_fifo_wr_en),
        .rd_en              (vga_fifo_rd_en),
        .dout               (vga_fifo_dout),
        .full               (),
        .empty              (read_fifo_empty),     
        .rd_data_count      (),
        .wr_data_count      (sdram_rd_fifo_count)  
    );

    // =======================================================
    // 7. VGA DISPLAY (25 MHz Domain)
    // =======================================================
    vga_controller vga_timing (
        .i_clk_25M          (clk_25M),
        .i_reset            (~sys_rst_n),
        .o_hsync            (raw_hsync),
        .o_vsync            (raw_vsync),
        .o_video_on         (video_on),
        .o_pixel_x          (), 
        .o_pixel_y          ()  
    );

    vga_fifo_read vga_pixel_fetch (
        .clk_25M            (clk_25M),
        .reset              (~sys_rst_n),
        .video_on           (video_on),
        .fifo_data          (vga_fifo_dout),
        .fifo_empty         (read_fifo_empty),     // Gates the read requests
        .fifo_rd_en         (vga_fifo_rd_en),
        .vga_r              (vga_r),
        .vga_g              (vga_g),
        .vga_b              (vga_b)
    );

    // -------------------------------------------------------
    // VGA Sync Alignment Delay
    // -------------------------------------------------------
    reg hsync_delay, vsync_delay;
    
    always @(posedge clk_25M) begin
        if (~sys_rst_n) begin
            hsync_delay <= 1'b1;
            vsync_delay <= 1'b1;
        end else begin
            hsync_delay <= raw_hsync;
            vsync_delay <= raw_vsync;
        end
    end
    
    assign vga_hsync = hsync_delay;
    assign vga_vsync = vsync_delay;

endmodule