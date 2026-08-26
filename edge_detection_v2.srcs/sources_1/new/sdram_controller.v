`timescale 1ns / 1ps

module sdram_controller (
    input  wire        clk_100M,    // 100 MHz clock
    input  wire        rst_n,       // Active-low reset

    // --- NEW VSYNC INPUTS ---
    input  wire        cam_vsync,   // [FIXED] Properly declared inside ports
    input  wire        vga_vsync,   // [FIXED] Properly declared inside ports

    // --- Write FIFO Interface (From OV5640) ---
    input  wire [10:0] fifo_wr_count, 
    output reg         fifo_wr_rd_en, 
    input  wire [15:0] fifo_wr_data,  

    // --- Read FIFO Interface (To VGA) ---
    input  wire [10:0] fifo_rd_count, 
    output reg         fifo_rd_wr_en, 
    output reg  [15:0] fifo_rd_data,  

    // --- Physical SDRAM Pins (To EDGE Board) ---
    output wire        sdram_cke,
    output wire        sdram_cs_n,
    output wire        sdram_ras_n,
    output wire        sdram_cas_n,
    output wire        sdram_we_n,
    output wire [1:0]  sdram_ba,    
    output wire [12:0] sdram_a,     
    output wire [1:0]  sdram_dqm,
    inout  wire [15:0] sdram_dq     
);

    // =========================================================
    // SDRAM COMMAND DEFINITIONS
    // =========================================================
    localparam CMD_LMR   = 4'b0000; 
    localparam CMD_REF   = 4'b0001; 
    localparam CMD_PRE   = 4'b0010; 
    localparam CMD_ACT   = 4'b0011; 
    localparam CMD_WRITE = 4'b0100; 
    localparam CMD_READ  = 4'b0101; 
    localparam CMD_NOP   = 4'b0111; 

    // =========================================================
    // FSM STATES
    // =========================================================
    localparam S_INIT_WAIT = 4'd0, S_INIT_CMD  = 4'd1, S_IDLE      = 4'd2,
               S_REF_PRE   = 4'd3, S_REF_CMD   = 4'd4, S_WRITE_ACT = 4'd5,
               S_WRITE_CMD = 4'd6, S_WRITE_DAT = 4'd7, S_READ_ACT  = 4'd8,
               S_READ_CMD  = 4'd9, S_READ_DAT  = 4'd10,S_PRECHARGE = 4'd11;

    reg [3:0]  state;
    reg [3:0]  sdram_cmd;
    reg [15:0] delay_cnt;       
    reg [9:0]  burst_cnt;        
    
    // Address & Data Registers
    reg [12:0] addr_reg;
    reg [1:0]  bank_reg;
    reg [15:0] dq_out;
    reg        dq_dir;           
    
    // Refresh Counter 
    reg [9:0]  refresh_cnt;
    reg        refresh_req;

    // 21-bit Address tracking
    reg [21:0] wr_addr_ptr, rd_addr_ptr;

    // Tie physical pins
    assign {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = sdram_cmd;
    assign sdram_cke = 1'b1;
    assign sdram_dqm = 2'b00;
    assign sdram_a   = addr_reg;
    assign sdram_ba  = bank_reg;
    assign sdram_dq  = dq_dir ? dq_out : 16'bz;

    // =========================================================
    // REFRESH COUNTER (100 MHz clock)
    // =========================================================
    always @(posedge clk_100M or negedge rst_n) begin
        if (!rst_n) begin
            refresh_cnt <= 10'd0;
            refresh_req <= 1'b0;
        end else if (refresh_cnt == 10'd750) begin
            refresh_cnt <= 10'd0;
            refresh_req <= 1'b1;
        end else begin
            refresh_cnt <= refresh_cnt + 1'b1;
            if (state == S_REF_CMD) refresh_req <= 1'b0; 
        end
    end

    // =========================================================
    // CROSS-DOMAIN VSYNC EDGE DETECTORS (100 MHz Domain)
    // =========================================================
    reg [2:0] cam_sync;
    reg [2:0] vga_sync;
    
    always @(posedge clk_100M or negedge rst_n) begin
        if (!rst_n) begin
            cam_sync <= 3'd0;
            vga_sync <= 3'd0;
        end else begin
            cam_sync <= {cam_sync[1:0], cam_vsync};
            vga_sync <= {vga_sync[1:0], vga_vsync};
        end
    end
    
    wire cam_vsync_pulse = (cam_sync[2:1] == 2'b01);
    wire vga_vsync_pulse = (vga_sync[2:1] == 2'b01);
    
    // =========================================================
    // MAIN STATE MACHINE
    // =========================================================
    always @(posedge clk_100M or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_INIT_WAIT;
            delay_cnt   <= 16'd0;
            sdram_cmd   <= CMD_NOP;
            dq_dir      <= 1'b0;
            burst_cnt   <= 10'd0;
            wr_addr_ptr <= 22'd0;
            rd_addr_ptr <= 22'd0;
        end else begin
            sdram_cmd     <= CMD_NOP;
            fifo_wr_rd_en <= 1'b0;
            fifo_rd_wr_en <= 1'b0;

            case (state)
                S_INIT_WAIT: begin
                    if (delay_cnt == 16'd20000) begin
                        state <= S_INIT_CMD;
                        delay_cnt <= 0;
                    end else delay_cnt <= delay_cnt + 1'b1;
                end

                S_INIT_CMD: begin
                    if (delay_cnt == 0) sdram_cmd <= CMD_PRE;
                    else if (delay_cnt == 4) sdram_cmd <= CMD_REF;
                    else if (delay_cnt == 12) begin
                        sdram_cmd <= CMD_LMR;
                        addr_reg  <= 13'b000_0_00_010_0111; 
                    end
                    else if (delay_cnt == 15) state <= S_IDLE;
                    delay_cnt <= delay_cnt + 1'b1;
                end

                S_IDLE: begin
                    dq_dir <= 1'b0; 
                    
                    // --- THE FIX: Hard Reset Pointers on Frame Start ---
                    if (cam_vsync_pulse) wr_addr_ptr <= 22'd0;
                    if (vga_vsync_pulse) rd_addr_ptr <= 22'd0;

                    // [FIXED] Removed the duplicated if(refresh_req) block
                    if (refresh_req) begin
                        state <= S_REF_PRE;
                    end 
                    else if (fifo_wr_count >= 10'd256) begin
                        state    <= S_WRITE_ACT;
                        bank_reg <= wr_addr_ptr[21:20]; 
                        addr_reg <= wr_addr_ptr[19:9];  
                    end 
                    else if (fifo_rd_count < 11'd1792) begin
                        state    <= S_READ_ACT;
                        bank_reg <= rd_addr_ptr[21:20];
                        addr_reg <= rd_addr_ptr[19:9];  
                    end
                end

                S_REF_PRE: begin
                    sdram_cmd <= CMD_PRE;
                    addr_reg  <= 13'b0010000000000; 
                    state     <= S_REF_CMD;
                end

                S_REF_CMD: begin
                    sdram_cmd <= CMD_REF;
                    state     <= S_IDLE; 
                end

                S_WRITE_ACT: begin
                    sdram_cmd <= CMD_ACT;
                    state     <= S_WRITE_CMD;
                end

                S_WRITE_CMD: begin
                    sdram_cmd <= CMD_WRITE;
                    addr_reg  <= {4'b0000, wr_addr_ptr[8:0]}; 
                    dq_dir    <= 1'b1; 
                    burst_cnt <= 10'd0;
                    state     <= S_WRITE_DAT;
                end

                S_WRITE_DAT: begin
                    fifo_wr_rd_en <= 1'b1;
                    dq_out        <= fifo_wr_data;
                    wr_addr_ptr   <= wr_addr_ptr + 1'b1;
                    
                    if (burst_cnt == 10'd255) begin
                        fifo_wr_rd_en <= 1'b0;
                        state         <= S_PRECHARGE;
                    end else begin
                        burst_cnt <= burst_cnt + 1'b1;
                    end
                    
                    if (wr_addr_ptr == 22'd307200) wr_addr_ptr <= 22'd0;
                end

                S_READ_ACT: begin
                    sdram_cmd <= CMD_ACT;
                    state     <= S_READ_CMD;
                end

                S_READ_CMD: begin
                    sdram_cmd <= CMD_READ;
                    addr_reg  <= {4'b0000, rd_addr_ptr[8:0]}; 
                    burst_cnt <= 10'd0;
                    state     <= S_READ_DAT;
                end

                S_READ_DAT: begin
                    if (burst_cnt >= 2) begin
                        fifo_rd_wr_en <= 1'b1;
                        fifo_rd_data  <= sdram_dq; 
                        rd_addr_ptr   <= rd_addr_ptr + 1'b1;
                    end
                    
                    if (burst_cnt == 10'd257) begin
                        fifo_rd_wr_en <= 1'b0;
                        state         <= S_PRECHARGE;
                    end else begin
                        burst_cnt <= burst_cnt + 1'b1;
                    end

                    if (rd_addr_ptr == 22'd307200) rd_addr_ptr <= 22'd0;
                end

                S_PRECHARGE: begin
                    sdram_cmd <= CMD_PRE;
                    addr_reg  <= 13'b0010000000000; 
                    state     <= S_IDLE;
                end

            endcase
        end
    end

endmodule