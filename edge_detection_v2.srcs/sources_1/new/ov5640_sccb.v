`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.08.2026 15:13:59
// Design Name: 
// Module Name: ov5640_sccb
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


`timescale 1ns/1ns

module ov5640_sccb(
    input       clk_24M,    // Uses the 24MHz Camera XCLK
    input       s_rst_n,
        
    //data input
    input       [31:0]  w_data,
    input               start,
    output      reg     [7:0]   riic_data,
    output      reg             busy,
    
    //iic
    output      reg     iic_clk,
    inout               iic_sda
);

// =========================================================
// 1. CLOCK DIVIDER: 24 MHz to 800 kHz
// =========================================================
    
    reg [4:0] divider;
    reg       sclk;

    always @(posedge clk_24M or negedge s_rst_n) begin
        if(s_rst_n == 1'b0) begin
            divider <= 5'd0;
            sclk    <= 1'b0;
        end 
        else 
        if(divider == 5'd14) begin // Counts 0 to 14 (15 ticks)
            divider <= 5'd0; 
            sclk    <= ~sclk; // Toggles every 15 ticks (Divide by 30 total)
        end else begin
            divider <= divider + 1'b1;
        end
    end

// =========================================================
// 2. SIGNAL SYNCHRONIZATION LATCH
// =========================================================
    
    reg        start_latched;
    reg [31:0] w_data_reg;
    
    always @(posedge clk_24M or negedge s_rst_n) begin
        if(s_rst_n == 1'b0) begin
            start_latched <= 1'b0;
            w_data_reg    <= 32'd0;
        end 
        else 
        if(start) begin     //start bit 1
            start_latched <= 1'b1;
            w_data_reg    <= w_data;  // writes data from w_data to w_data_reg
        end 
        else 
        if(busy) begin
            start_latched <= 1'b0;    
        end
    end

 // =========================================================
 // 3. ORIGINAL VERIFIED I2C STATE MACHINE
 // =========================================================
    
    reg     [5:0]       cfg_cnt;
    reg                 iic_sda_reg;
    reg                 flag_ack;
    reg     [3:0]       delay_cnt;
    reg                 done;
    wire                dir;  // direction - 0 for write and 1 for read 


    always @(posedge sclk or negedge s_rst_n) begin // Initialize i2c_clk
        if(s_rst_n == 1'b0) // checks reset
            iic_clk <=  1'b1;
        else 
        if(start_latched == 1'b1) // checks latch
            iic_clk <= 1'b0;
        else 
        if(cfg_cnt == 'd28 && dir ==1'b1 && delay_cnt <='d3) // when in read mode at 28th bit and dir = 0
            iic_clk <= 1'b1;
        else 
        if(busy == 1'b1) // checks busy status
            iic_clk <= ~iic_clk;
        else 
        iic_clk <=  1'b1;
    end


    always @(negedge sclk or negedge s_rst_n) begin // Initializes Busy
        if(s_rst_n == 1'b0)
            busy <= 1'b0;
        else 
        if(start_latched == 1'b1) // busy till latch completes the transaction
            busy <= 1'b1;
        else 
        if(done == 1'b1) 
            busy <= 1'b0;
    end


    always @(negedge sclk or negedge s_rst_n) begin // Initialize Counter
        if(s_rst_n == 1'b0)
            cfg_cnt <= 'd0;
        else 
        if((cfg_cnt >= 'd47 && dir == 1'b1) || (cfg_cnt >= 'd37 && dir == 1'b0)) // check the count for both write(37) and read(47)
            cfg_cnt <= 'd0;
        else 
        if(cfg_cnt == 'd28 && delay_cnt <= 'd4 && dir == 1'b1) // pause at 28
            cfg_cnt <= 'd28;
        else 
        if(busy == 1'b1 && iic_clk ==1'b0) 
            cfg_cnt <= cfg_cnt + 1'b1;
    end


    always @(negedge sclk or negedge s_rst_n) begin
        if(s_rst_n == 1'b0)
            riic_data <= 'd0;
        else 
        if(iic_clk == 1'b1 && cfg_cnt >= 'd38 && flag_ack ==1'b1)
            riic_data   <= {riic_data[6:0],iic_sda};
    end


    always @(negedge sclk or negedge s_rst_n) begin // Initialize Done 
        if(s_rst_n == 1'b0)
            done <= 1'b0;
        else 
        if(dir == 1'b1 && cfg_cnt == 'd46 && iic_clk == 1'b1)
            done <=  1'b1;
        else 
        if(dir == 1'b0 && cfg_cnt == 'd36 && iic_clk == 1'b1)
            done <=  1'b1;
        else done <=  1'b0;
    end

 
    always @(posedge sclk or negedge s_rst_n) begin // Initializing Delay when in read mode and at 28 bit
        if(s_rst_n == 1'b0)
            delay_cnt <= 'd0;   
        else 
        if(dir == 1'b1 && cfg_cnt == 'd28)
            delay_cnt <= delay_cnt + 1'b1; 
        else 
            delay_cnt <= 'd0;
    end 

// Module for ack at every 9th bit, - tri state ack
    always @(*) begin
        if(dir == 1'b1 && (cfg_cnt =='d9 || cfg_cnt =='d18 ||cfg_cnt =='d27 ||(cfg_cnt >='d37 &&cfg_cnt <='d45)))
            flag_ack <=1'b1; 
        else 
        if(dir == 1'b0 && (cfg_cnt =='d9 || cfg_cnt =='d18 ||cfg_cnt =='d27 ||cfg_cnt =='d36))
            flag_ack <=1'b1;  
        else    flag_ack <=1'b0;
    end
        

    always @(*) begin
        if(dir == 1'b1) // Read Condition   
            case(cfg_cnt)
                0:
                    if(busy == 1'b1)
                        iic_sda_reg = 1'b0; 
                    else    
                        iic_sda_reg = 1'b1;
                //ID Address
                1:      iic_sda_reg = w_data_reg[31];
                2:      iic_sda_reg = w_data_reg[30];
                3:      iic_sda_reg = w_data_reg[29];
                4:      iic_sda_reg = w_data_reg[28];
                5:      iic_sda_reg = w_data_reg[27];
                6:      iic_sda_reg = w_data_reg[26];
                7:      iic_sda_reg = w_data_reg[25];
                8:      iic_sda_reg = 1'b0;  
                
                //Address High  Byte
                10:     iic_sda_reg = w_data_reg[23];
                11:     iic_sda_reg = w_data_reg[22];
                12:     iic_sda_reg = w_data_reg[21];
                13:     iic_sda_reg = w_data_reg[20];
                14:     iic_sda_reg = w_data_reg[19];           
                15:     iic_sda_reg = w_data_reg[18];
                16:     iic_sda_reg = w_data_reg[17];
                17:     iic_sda_reg = w_data_reg[16];
                
                //Address   Low Byte
                19:     iic_sda_reg = w_data_reg[15];
                20:     iic_sda_reg = w_data_reg[14];
                21:     iic_sda_reg = w_data_reg[13];
                22:     iic_sda_reg = w_data_reg[12];
                23:     iic_sda_reg = w_data_reg[11];
                24:     iic_sda_reg = w_data_reg[10];           
                25:     iic_sda_reg = w_data_reg[9];
                26:     iic_sda_reg = w_data_reg[8];
                
                //STOP & START
                28:
                        if(delay_cnt <= 'd1 || delay_cnt >= 'd4)
                            iic_sda_reg = 1'b0;
                        else
                            iic_sda_reg = 1'b1;
                            
                //ID        Address
                29:     iic_sda_reg = w_data_reg[31];
                30:     iic_sda_reg = w_data_reg[30];
                31:     iic_sda_reg = w_data_reg[29];
                32:     iic_sda_reg = w_data_reg[28];
                33:     iic_sda_reg = w_data_reg[27];
                34:     iic_sda_reg = w_data_reg[26];           
                35:     iic_sda_reg = w_data_reg[25];
                36:     iic_sda_reg = w_data_reg[24]; 
                
                47:     iic_sda_reg = 1'b0;
                default:iic_sda_reg = 1'b1;     
            endcase
        else  
            case(cfg_cnt) // Write Condition 
                0:
                    if(busy == 1'b1)
                        iic_sda_reg = 1'b0;
                    else    iic_sda_reg = 1'b1;
                //ID Address
                1:      iic_sda_reg = w_data_reg[31];
                2:      iic_sda_reg = w_data_reg[30];
                3:      iic_sda_reg = w_data_reg[29];
                4:      iic_sda_reg = w_data_reg[28];
                5:      iic_sda_reg = w_data_reg[27];
                6:      iic_sda_reg = w_data_reg[26];
                7:      iic_sda_reg = w_data_reg[25];
                8:      iic_sda_reg = 1'b0; 
                
                //Address High  Byte
                10:     iic_sda_reg = w_data_reg[23];
                11:     iic_sda_reg = w_data_reg[22];
                12:     iic_sda_reg = w_data_reg[21];
                13:     iic_sda_reg = w_data_reg[20];
                14:     iic_sda_reg = w_data_reg[19];           
                15:     iic_sda_reg = w_data_reg[18];
                16:     iic_sda_reg = w_data_reg[17];
                17:     iic_sda_reg = w_data_reg[16];
                
                //Address   Low Byte
                19:     iic_sda_reg = w_data_reg[15];
                20:     iic_sda_reg = w_data_reg[14];
                21:     iic_sda_reg = w_data_reg[13];
                22:     iic_sda_reg = w_data_reg[12];
                23:     iic_sda_reg = w_data_reg[11];
                24:     iic_sda_reg = w_data_reg[10];           
                25:     iic_sda_reg = w_data_reg[9];
                26:     iic_sda_reg = w_data_reg[8];
                
                //STOP & START
                28:     iic_sda_reg = w_data_reg[7];
                29:     iic_sda_reg = w_data_reg[6];
                30:     iic_sda_reg = w_data_reg[5];
                31:     iic_sda_reg = w_data_reg[4];
                32:     iic_sda_reg = w_data_reg[3];
                33:     iic_sda_reg = w_data_reg[2];
                34:     iic_sda_reg = w_data_reg[1];            
                35:     iic_sda_reg = w_data_reg[0];
                
                37:     iic_sda_reg = 1'b0;
                
                default: iic_sda_reg = 1'b1;     
            endcase
    end

    assign      iic_sda     =   (flag_ack == 1'b1)  ? 1'bz : iic_sda_reg;
    assign      dir         =   w_data_reg[24];  

endmodule


/*
Separation of Protocols: The two blocks split the I2C Write (dir == 0) and I2C Read (dir == 1) operations. While the first half of both transactions is identical, they diverge completely after state 27.

Write Sequence (dir == 0): A straightforward, linear operation.

States 0-26: Sends Device ID (Write bit) and 16-bit Register Address.

States 28-35: Sends the 8-bit Data payload.

State 37: Issues the STOP condition.

Read Sequence (dir == 1): Requires a "dummy write" followed by a restart.

States 0-26: Sends the identical "dummy write" (Device ID + 16-bit Address) to tell the camera which register to look at.

State 28: Issues a Repeated START condition to flip the data direction on the bus.

States 29-36: Sends the Device ID again, this time with a Read bit.

States 38-45: The FPGA releases the SDA pin so the camera can transmit the requested data back.

Hardware Efficiency: If combined into one case, the author would have had to write if (dir == 1)... else... inside every single state from 28 to 47. Splitting them creates cleaner multiplexer logic during FPGA synthesis and makes the code much easier to read and debug.

*/