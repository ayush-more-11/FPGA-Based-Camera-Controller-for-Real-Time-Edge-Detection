//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.08.2026 12:31:42
// Design Name: 
// Module Name: sdram_controller
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

module sdram_controller (
    input  wire        clk_100M,    // 100 MHz clock
    input  wire        rst_n,       // Active-low reset

    // --- Write FIFO Interface (From OV5640) ---
    input  wire [9:0]  fifo_wr_count, // How many pixels are waiting in Write FIFO
    output reg         fifo_wr_rd_en, // Read enable to pull pixels out of Write FIFO
    input  wire [15:0] fifo_wr_data,  // Pixel data from Write FIFO

    // --- Read FIFO Interface (To VGA) ---
    input  wire [9:0]  fifo_rd_count, // How many pixels are already in Read FIFO
    output reg         fifo_rd_wr_en, // Write enable to push pixels into Read FIFO
    output reg  [15:0] fifo_rd_data,  // Pixel data to Read FIFO

    // --- Physical SDRAM Pins (To EDGE Board) ---
    output wire        sdram_cke,
    output wire        sdram_cs_n,
    output wire        sdram_ras_n,
    output wire        sdram_cas_n,
    output wire        sdram_we_n,
    output wire [1:0]  sdram_ba,    // 4 Banks
    output wire [12:0] sdram_a,     // 8192 Rows, 512 Columns[cite: 2]
    output wire [1:0]  sdram_dqm,
    inout  wire [15:0] sdram_dq     // 16-bit Data Bus[cite: 2]
);

    // =========================================================
    // SDRAM COMMAND DEFINITIONS (CS_N, RAS_N, CAS_N, WE_N)
    // =========================================================
    localparam CMD_LMR   = 4'b0000; // Load Mode Register
    localparam CMD_REF   = 4'b0001; // Auto Refresh
    localparam CMD_PRE   = 4'b0010; // Precharge
    localparam CMD_ACT   = 4'b0011; // Bank Activate
    localparam CMD_WRITE = 4'b0100; // Write
    localparam CMD_READ  = 4'b0101; // Read
    localparam CMD_NOP   = 4'b0111; // No Operation

    // =========================================================
    // FSM STATES
    // =========================================================
    localparam S_INIT_WAIT = 4'd0, S_INIT_CMD  = 4'd1, S_IDLE      = 4'd2,
               S_REF_PRE   = 4'd3, S_REF_CMD   = 4'd4, S_WRITE_ACT = 4'd5,
               S_WRITE_CMD = 4'd6, S_WRITE_DAT = 4'd7, S_READ_ACT  = 4'd8,
               S_READ_CMD  = 4'd9, S_READ_DAT  = 4'd10,S_PRECHARGE = 4'd11;

    reg [3:0]  state, next_state;
    reg [3:0]  sdram_cmd;
    reg [15:0] delay_cnt;       
    reg [9:0]  burst_cnt;        // Tracks our 256-pixel bursts
    
    // Address & Data Registers
    reg [12:0] addr_reg;
    reg [1:0]  bank_reg;
    reg [15:0] dq_out;
    reg        dq_dir;           // 1 for Write (Output), 0 for Read (Input)
    
    // Refresh Counter (Needs to trigger every 7.5us = 750 clock cycles)
    reg [9:0]  refresh_cnt;
    reg        refresh_req;

    // 21-bit Address tracking (For 640x480 = 307,200 pixels)
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
            if (state == S_REF_CMD) refresh_req <= 1'b0; // Clear request when served
        end
    end

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
            // Default command is NOP to prevent accidental operations
            sdram_cmd     <= CMD_NOP;
            fifo_wr_rd_en <= 1'b0;
            fifo_rd_wr_en <= 1'b0;

            case (state)
                S_INIT_WAIT: begin
                    // Wait 200us (20,000 cycles at 100MHz) for SDRAM power stability
                    if (delay_cnt == 16'd20000) begin
                        state <= S_INIT_CMD;
                        delay_cnt <= 0;
                    end else delay_cnt <= delay_cnt + 1'b1;
                end

                S_INIT_CMD: begin
                    // Simplified Init: Precharge All -> Auto Refresh -> Load Mode Register
                    // Configures SDRAM for CAS Latency 2, Burst Length of Full Page
                    if (delay_cnt == 0) sdram_cmd <= CMD_PRE;
                    else if (delay_cnt == 4) sdram_cmd <= CMD_REF;
                    else if (delay_cnt == 12) begin
                        sdram_cmd <= CMD_LMR;
                        addr_reg  <= 13'b000_0_00_010_0111; // CAS 2, Full Page Burst
                    end
                    else if (delay_cnt == 15) state <= S_IDLE;
                    delay_cnt <= delay_cnt + 1'b1;
                end

                S_IDLE: begin
                    dq_dir <= 1'b0; // Ensure data bus is input
                    // 1. Refresh has highest priority
                    if (refresh_req) begin
                        state <= S_REF_PRE;
                    end 
                    // 2. Write Priority: If Write FIFO has >= 256 pixels
                    else if (fifo_wr_count >= 10'd256) begin
                        state    <= S_WRITE_ACT;
                        bank_reg <= wr_addr_ptr[21:20]; 
                        addr_reg <= wr_addr_ptr[19:9];  // Row Address
                    end 
                    // 3. Read Priority: If Read FIFO has space for >= 256 pixels
                    // (Assuming 2048 depth FIFO, threshold is < 1792)
                    else if (fifo_rd_count < 11'd1792) begin
                        state    <= S_READ_ACT;
                        bank_reg <= rd_addr_ptr[21:20];
                        addr_reg <= rd_addr_ptr[19:9];  // Row Address
                    end
                end

                S_REF_PRE: begin
                    sdram_cmd <= CMD_PRE;
                    addr_reg  <= 13'b0010000000000; // Precharge All Banks (A10 = 1)
                    state     <= S_REF_CMD;
                end

                S_REF_CMD: begin
                    sdram_cmd <= CMD_REF;
                    state     <= S_IDLE; // Simplified, assumes adequate tRC delay loops
                end

                S_WRITE_ACT: begin
                    sdram_cmd <= CMD_ACT;
                    state     <= S_WRITE_CMD;
                end

                S_WRITE_CMD: begin
                    sdram_cmd <= CMD_WRITE;
                    addr_reg  <= {4'b0000, wr_addr_ptr[8:0]}; // Column Address
                    dq_dir    <= 1'b1; // Turn on physical outputs
                    burst_cnt <= 10'd0;
                    state     <= S_WRITE_DAT;
                end

                S_WRITE_DAT: begin
                    // Stream 256 pixels from FIFO directly into SDRAM
                    fifo_wr_rd_en <= 1'b1;
                    dq_out        <= fifo_wr_data;
                    wr_addr_ptr   <= wr_addr_ptr + 1'b1;
                    
                    if (burst_cnt == 10'd255) begin
                        fifo_wr_rd_en <= 1'b0;
                        state         <= S_PRECHARGE;
                    end else begin
                        burst_cnt <= burst_cnt + 1'b1;
                    end
                    
                    // Frame wrap-around check
                    if (wr_addr_ptr == 22'd307200) wr_addr_ptr <= 22'd0;
                end

                S_READ_ACT: begin
                    sdram_cmd <= CMD_ACT;
                    state     <= S_READ_CMD;
                end

                S_READ_CMD: begin
                    sdram_cmd <= CMD_READ;
                    addr_reg  <= {4'b0000, rd_addr_ptr[8:0]}; // Column Address
                    burst_cnt <= 10'd0;
                    state     <= S_READ_DAT;
                end

                S_READ_DAT: begin
                    // Due to CAS Latency of 2, the first valid data arrives 2 cycles later
                    // We catch 256 pixels and push them into the Read FIFO
                    if (burst_cnt >= 2) begin
                        fifo_rd_wr_en <= 1'b1;
                        fifo_rd_data  <= sdram_dq; // Read physical pins
                        rd_addr_ptr   <= rd_addr_ptr + 1'b1;
                    end
                    
                    if (burst_cnt == 10'd257) begin
                        fifo_rd_wr_en <= 1'b0;
                        state         <= S_PRECHARGE;
                    end else begin
                        burst_cnt <= burst_cnt + 1'b1;
                    end

                    // Frame wrap-around check
                    if (rd_addr_ptr == 22'd307200) rd_addr_ptr <= 22'd0;
                end

                S_PRECHARGE: begin
                    // Issue Burst Stop / Precharge to close the active row
                    sdram_cmd <= CMD_PRE;
                    addr_reg  <= 13'b0010000000000; // Precharge All Banks
                    state     <= S_IDLE;
                end

            endcase
        end
    end

endmodule
