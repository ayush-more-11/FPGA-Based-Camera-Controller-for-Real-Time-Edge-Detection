`timescale 1ns / 1ps

module vga_controller (

    input  wire       i_clk_25M,   
    input  wire       i_reset,     
    
    output wire       o_hsync,     
    output wire       o_vsync,     
    output wire       o_video_on,  
    
    output wire [9:0] o_pixel_x,   
    output wire [9:0] o_pixel_y
);

    localparam HD = 640; 
    localparam HF = 16;  
    localparam HR = 96;  
    localparam HB = 48;  
    localparam HT = 800; 

    localparam VD = 480; 
    localparam VF = 10;  
    localparam VR = 2;   
    localparam VB = 33;  
    localparam VT = 525; 

    reg [9:0] h_count_reg, h_count_next;
    reg [9:0] v_count_reg, v_count_next;
    reg h_sync_reg, v_sync_reg;

    always @(posedge i_clk_25M or posedge i_reset) begin
        if (i_reset) begin
            h_count_reg <= 0;
            v_count_reg <= 0;
            h_sync_reg  <= 1'b1;
            v_sync_reg  <= 1'b1;
        end else begin
            h_count_reg <= h_count_next;
            v_count_reg <= v_count_next;
            h_sync_reg  <= (h_count_reg >= (HD + HF)) && (h_count_reg < (HD + HF + HR));
            v_sync_reg  <= (v_count_reg >= (VD + VF)) && (v_count_reg < (VD + VF + VR));
        end
    end

    always @(*) begin
        if (h_count_reg == HT - 1)
            h_count_next = 0;
        else
            h_count_next = h_count_reg + 1;
    end

    always @(*) begin
        if (h_count_reg == HT - 1) begin
            if (v_count_reg == VT - 1)
                v_count_next = 0;
            else
                v_count_next = v_count_reg + 1;
        end else begin
            v_count_next = v_count_reg;
        end
    end

    assign o_video_on = (h_count_reg < HD) && (v_count_reg < VD);
    assign o_hsync = ~h_sync_reg;
    assign o_vsync = ~v_sync_reg;
    assign o_pixel_x = h_count_reg;
    assign o_pixel_y = v_count_reg;

endmodule