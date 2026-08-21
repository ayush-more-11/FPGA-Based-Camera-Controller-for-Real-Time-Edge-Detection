`timescale	1ns/1ns

module		ov5640_config(
	input		clk_24M, // 24Mhz System Clock
	input		s_rst_n,
	
	output		wire	iic_clk,
	inout				iic_sda
	//debug 
);
localparam NUM_REG = 254;
localparam DELAY_20ms = 19'd480_000; // 20ms delay at 24MHz = 480,000 clock cycles

wire [31:0]	cfg_array[NUM_REG-1:0];
reg	[7:0] cfg_index;
wire cfg_done;		

reg	[15:0] cnt_200us;
reg	start;

//busy
wire	busy_neg;
reg		[2:0]	busy_array;
wire	busy;

//iic_Start   iic_wdata

 
//=============================================================================
//                            ID    REG_ADDR  REG_VAL
    assign  cfg_array[0]  = {8'h78, 16'h3103, 8'h11}; // System Clock Control
    assign  cfg_array[1]  = {8'h78, 16'h3008, 8'h82}; // Software Reset

    assign cfg_array[2]   = {8'h78, 16'h3008, 8'h42}; // Software Wakeup				  
    assign cfg_array[3]   = {8'h78, 16'h3103, 8'h03}; 
    assign cfg_array[4]   = {8'h78, 16'h3017, 8'hff}; // I/O Output Enable
    assign cfg_array[5]   = {8'h78, 16'h3018, 8'hff}; // I/O Output Enable
    assign cfg_array[6]   = {8'h78, 16'h3034, 8'h1A}; // PLL Control
    assign cfg_array[7]   = {8'h78, 16'h3037, 8'h13}; // PLL Control
    assign cfg_array[8]   = {8'h78, 16'h3108, 8'h01}; // System Root Divider
    assign cfg_array[9]   = {8'h78, 16'h3630, 8'h36}; // Analog Control
    assign cfg_array[10]  = {8'h78, 16'h3631, 8'h0e};
    assign cfg_array[11]  = {8'h78, 16'h3632, 8'he2};
    assign cfg_array[12]  = {8'h78, 16'h3633, 8'h12};
    assign cfg_array[13]  = {8'h78, 16'h3621, 8'he0};
    assign cfg_array[14]  = {8'h78, 16'h3704, 8'ha0}; // Sensor Control
    assign cfg_array[15]  = {8'h78, 16'h3703, 8'h5a};
    assign cfg_array[16]  = {8'h78, 16'h3715, 8'h78};
    assign cfg_array[17]  = {8'h78, 16'h3717, 8'h01};
    assign cfg_array[18]  = {8'h78, 16'h370b, 8'h60};
    assign cfg_array[19]  = {8'h78, 16'h3705, 8'h1a};
    assign cfg_array[20]  = {8'h78, 16'h3905, 8'h02}; // BLC Control
    assign cfg_array[21]  = {8'h78, 16'h3906, 8'h10};
    assign cfg_array[22]  = {8'h78, 16'h3901, 8'h0a};
    assign cfg_array[23]  = {8'h78, 16'h3731, 8'h12};
    assign cfg_array[24]  = {8'h78, 16'h3600, 8'h08}; // VCM Control
    assign cfg_array[25]  = {8'h78, 16'h3601, 8'h33};
    assign cfg_array[26]  = {8'h78, 16'h302d, 8'h60}; // System Control
    assign cfg_array[27]  = {8'h78, 16'h3620, 8'h52}; // Analog Control
    assign cfg_array[28]  = {8'h78, 16'h371b, 8'h20}; // Sensor Control
    assign cfg_array[29]  = {8'h78, 16'h471c, 8'h50}; // DVP Control
    assign cfg_array[30]  = {8'h78, 16'h3a13, 8'h43}; // AEC/AGC Control
    assign cfg_array[31]  = {8'h78, 16'h3a18, 8'h00};
    assign cfg_array[32]  = {8'h78, 16'h3a19, 8'hf8};
    assign cfg_array[33]  = {8'h78, 16'h3635, 8'h13}; // Analog Control
    assign cfg_array[34]  = {8'h78, 16'h3636, 8'h03};
    assign cfg_array[35]  = {8'h78, 16'h3634, 8'h40};
    assign cfg_array[36]  = {8'h78, 16'h3622, 8'h01};
    assign cfg_array[37]  = {8'h78, 16'h3c01, 8'h34}; // 50/60Hz Detection Control
    assign cfg_array[38]  = {8'h78, 16'h3c04, 8'h28};
    assign cfg_array[39]  = {8'h78, 16'h3c05, 8'h98};
    assign cfg_array[40]  = {8'h78, 16'h3c06, 8'h00};
    assign cfg_array[41]  = {8'h78, 16'h3c07, 8'h08};
    assign cfg_array[42]  = {8'h78, 16'h3c08, 8'h00};
    assign cfg_array[43]  = {8'h78, 16'h3c09, 8'h1c};
    assign cfg_array[44]  = {8'h78, 16'h3c0a, 8'h9c};
    assign cfg_array[45]  = {8'h78, 16'h3c0b, 8'h40};
    assign cfg_array[46]  = {8'h78, 16'h3810, 8'h00}; // Timing Control HOFFSET
    assign cfg_array[47]  = {8'h78, 16'h3811, 8'h10}; // Timing Control HOFFSET
    assign cfg_array[48]  = {8'h78, 16'h3812, 8'h00}; // Timing Control VOFFSET
    assign cfg_array[49]  = {8'h78, 16'h3708, 8'h64}; // Sensor Control
    assign cfg_array[50]  = {8'h78, 16'h4001, 8'h02}; // BLC Control
    assign cfg_array[51]  = {8'h78, 16'h4005, 8'h1a};
    assign cfg_array[52]  = {8'h78, 16'h3000, 8'h00}; // System Control
    assign cfg_array[53]  = {8'h78, 16'h3004, 8'hff}; // Clock Enable
    assign cfg_array[54]  = {8'h78, 16'h300e, 8'h58}; // MIPI Control
    assign cfg_array[55]  = {8'h78, 16'h302e, 8'h00}; // System Control
    assign cfg_array[56]  = {8'h78, 16'h4300, 8'h61}; // Format Control (RGB565)
    assign cfg_array[57]  = {8'h78, 16'h501f, 8'h01}; // ISP Format Mux
    assign cfg_array[58]  = {8'h78, 16'h440e, 8'h00}; // JPEG Control
    assign cfg_array[59]  = {8'h78, 16'h5000, 8'ha7}; // ISP Control
    assign cfg_array[60]  = {8'h78, 16'h3a0f, 8'h30}; // AEC Control
    assign cfg_array[61]  = {8'h78, 16'h3a10, 8'h28};
    assign cfg_array[62]  = {8'h78, 16'h3a1b, 8'h30};
    assign cfg_array[63]  = {8'h78, 16'h3a1e, 8'h26};
    assign cfg_array[64]  = {8'h78, 16'h3a11, 8'h60};
    assign cfg_array[65]  = {8'h78, 16'h3a1f, 8'h14};
    assign cfg_array[66]  = {8'h78, 16'h5800, 8'h23}; // Lens Correction (LENC)
    assign cfg_array[67]  = {8'h78, 16'h5801, 8'h14};
    assign cfg_array[68]  = {8'h78, 16'h5802, 8'h0f};
    assign cfg_array[69]  = {8'h78, 16'h5803, 8'h0f};
    assign cfg_array[70]  = {8'h78, 16'h5804, 8'h12};
    assign cfg_array[71]  = {8'h78, 16'h5805, 8'h26};
    assign cfg_array[72]  = {8'h78, 16'h5806, 8'h0c};
    assign cfg_array[73]  = {8'h78, 16'h5807, 8'h08};
    assign cfg_array[74]  = {8'h78, 16'h5808, 8'h05};
    assign cfg_array[75]  = {8'h78, 16'h5809, 8'h05};
    assign cfg_array[76]  = {8'h78, 16'h580a, 8'h08};
    assign cfg_array[77]  = {8'h78, 16'h580b, 8'h0d};
    assign cfg_array[78]  = {8'h78, 16'h580c, 8'h08};
    assign cfg_array[79]  = {8'h78, 16'h580d, 8'h03};
    assign cfg_array[80]  = {8'h78, 16'h580e, 8'h00};
    assign cfg_array[81]  = {8'h78, 16'h580f, 8'h00};
    assign cfg_array[82]  = {8'h78, 16'h5810, 8'h03};
    assign cfg_array[83]  = {8'h78, 16'h5811, 8'h09};
    assign cfg_array[84]  = {8'h78, 16'h5812, 8'h07};
    assign cfg_array[85]  = {8'h78, 16'h5813, 8'h03};
    assign cfg_array[86]  = {8'h78, 16'h5814, 8'h00};
    assign cfg_array[87]  = {8'h78, 16'h5815, 8'h01};
    assign cfg_array[88]  = {8'h78, 16'h5816, 8'h03};
    assign cfg_array[89]  = {8'h78, 16'h5817, 8'h08};
    assign cfg_array[90]  = {8'h78, 16'h5818, 8'h0d};
    assign cfg_array[91]  = {8'h78, 16'h5819, 8'h08};
    assign cfg_array[92]  = {8'h78, 16'h581a, 8'h05};
    assign cfg_array[93]  = {8'h78, 16'h581b, 8'h06};
    assign cfg_array[94]  = {8'h78, 16'h581c, 8'h08};
    assign cfg_array[95]  = {8'h78, 16'h581d, 8'h0e};
    assign cfg_array[96]  = {8'h78, 16'h581e, 8'h29};
    assign cfg_array[97]  = {8'h78, 16'h581f, 8'h17};
    assign cfg_array[98]  = {8'h78, 16'h5820, 8'h11};
    assign cfg_array[99]  = {8'h78, 16'h5821, 8'h11};
    assign cfg_array[100] = {8'h78, 16'h5822, 8'h15};
    assign cfg_array[101] = {8'h78, 16'h5823, 8'h28};
    assign cfg_array[102] = {8'h78, 16'h5824, 8'h46};
    assign cfg_array[103] = {8'h78, 16'h5825, 8'h26};
    assign cfg_array[104] = {8'h78, 16'h5826, 8'h08};
    assign cfg_array[105] = {8'h78, 16'h5827, 8'h26};
    assign cfg_array[106] = {8'h78, 16'h5828, 8'h64};
    assign cfg_array[107] = {8'h78, 16'h5829, 8'h26};
    assign cfg_array[108] = {8'h78, 16'h582a, 8'h24};
    assign cfg_array[109] = {8'h78, 16'h582b, 8'h22};
    assign cfg_array[110] = {8'h78, 16'h582c, 8'h24};
    assign cfg_array[111] = {8'h78, 16'h582d, 8'h24};
    assign cfg_array[112] = {8'h78, 16'h582e, 8'h06};
    assign cfg_array[113] = {8'h78, 16'h582f, 8'h22};
    assign cfg_array[114] = {8'h78, 16'h5830, 8'h40};
    assign cfg_array[115] = {8'h78, 16'h5831, 8'h42};
    assign cfg_array[116] = {8'h78, 16'h5832, 8'h24};
    assign cfg_array[117] = {8'h78, 16'h5833, 8'h26};
    assign cfg_array[118] = {8'h78, 16'h5834, 8'h24};
    assign cfg_array[119] = {8'h78, 16'h5835, 8'h22};
    assign cfg_array[120] = {8'h78, 16'h5836, 8'h22};
    assign cfg_array[121] = {8'h78, 16'h5837, 8'h26};
    assign cfg_array[122] = {8'h78, 16'h5838, 8'h44};
    assign cfg_array[123] = {8'h78, 16'h5839, 8'h24};
    assign cfg_array[124] = {8'h78, 16'h583a, 8'h26};
    assign cfg_array[125] = {8'h78, 16'h583b, 8'h28};
    assign cfg_array[126] = {8'h78, 16'h583c, 8'h42};
    assign cfg_array[127] = {8'h78, 16'h583d, 8'hce};
    assign cfg_array[128] = {8'h78, 16'h5180, 8'hff}; // AWB Control
    assign cfg_array[129] = {8'h78, 16'h5181, 8'hf2};
    assign cfg_array[130] = {8'h78, 16'h5182, 8'h00};
    assign cfg_array[131] = {8'h78, 16'h5183, 8'h14};
    assign cfg_array[132] = {8'h78, 16'h5184, 8'h25};
    assign cfg_array[133] = {8'h78, 16'h5185, 8'h24};
    assign cfg_array[134] = {8'h78, 16'h5186, 8'h09};
    assign cfg_array[135] = {8'h78, 16'h5187, 8'h09};
    assign cfg_array[136] = {8'h78, 16'h5188, 8'h09};
    assign cfg_array[137] = {8'h78, 16'h5189, 8'h75};
    assign cfg_array[138] = {8'h78, 16'h518a, 8'h54};
    assign cfg_array[139] = {8'h78, 16'h518b, 8'he0};
    assign cfg_array[140] = {8'h78, 16'h518c, 8'hb2};
    assign cfg_array[141] = {8'h78, 16'h518d, 8'h42};
    assign cfg_array[142] = {8'h78, 16'h518e, 8'h3d};
    assign cfg_array[143] = {8'h78, 16'h518f, 8'h56};
    assign cfg_array[144] = {8'h78, 16'h5190, 8'h46};
    assign cfg_array[145] = {8'h78, 16'h5191, 8'hf8};
    assign cfg_array[146] = {8'h78, 16'h5192, 8'h04};
    assign cfg_array[147] = {8'h78, 16'h5193, 8'h70};
    assign cfg_array[148] = {8'h78, 16'h5194, 8'hf0};
    assign cfg_array[149] = {8'h78, 16'h5195, 8'hf0};
    assign cfg_array[150] = {8'h78, 16'h5196, 8'h03};
    assign cfg_array[151] = {8'h78, 16'h5197, 8'h01};
    assign cfg_array[152] = {8'h78, 16'h5198, 8'h04};
    assign cfg_array[153] = {8'h78, 16'h5199, 8'h12};
    assign cfg_array[154] = {8'h78, 16'h519a, 8'h04};
    assign cfg_array[155] = {8'h78, 16'h519b, 8'h00};
    assign cfg_array[156] = {8'h78, 16'h519c, 8'h06};
    assign cfg_array[157] = {8'h78, 16'h519d, 8'h82};
    assign cfg_array[158] = {8'h78, 16'h519e, 8'h38};
    assign cfg_array[159] = {8'h78, 16'h5480, 8'h01}; // Gamma Control
    assign cfg_array[160] = {8'h78, 16'h5481, 8'h08};
    assign cfg_array[161] = {8'h78, 16'h5482, 8'h14};
    assign cfg_array[162] = {8'h78, 16'h5483, 8'h28};
    assign cfg_array[163] = {8'h78, 16'h5484, 8'h51};
    assign cfg_array[164] = {8'h78, 16'h5485, 8'h65};
    assign cfg_array[165] = {8'h78, 16'h5486, 8'h71};
    assign cfg_array[166] = {8'h78, 16'h5487, 8'h7d};
    assign cfg_array[167] = {8'h78, 16'h5488, 8'h87};
    assign cfg_array[168] = {8'h78, 16'h5489, 8'h91};
    assign cfg_array[169] = {8'h78, 16'h548a, 8'h9a};
    assign cfg_array[170] = {8'h78, 16'h548b, 8'haa};
    assign cfg_array[171] = {8'h78, 16'h548c, 8'hb8};
    assign cfg_array[172] = {8'h78, 16'h548d, 8'hcd};
    assign cfg_array[173] = {8'h78, 16'h548e, 8'hdd};
    assign cfg_array[174] = {8'h78, 16'h548f, 8'hea};
    assign cfg_array[175] = {8'h78, 16'h5490, 8'h1d};
    assign cfg_array[176] = {8'h78, 16'h5381, 8'h1e}; // Color Matrix (CMX)
    assign cfg_array[177] = {8'h78, 16'h5382, 8'h5b};
    assign cfg_array[178] = {8'h78, 16'h5383, 8'h08};
    assign cfg_array[179] = {8'h78, 16'h5384, 8'h0a};
    assign cfg_array[180] = {8'h78, 16'h5385, 8'h7e};
    assign cfg_array[181] = {8'h78, 16'h5386, 8'h88};
    assign cfg_array[182] = {8'h78, 16'h5387, 8'h7c};
    assign cfg_array[183] = {8'h78, 16'h5388, 8'h6c};
    assign cfg_array[184] = {8'h78, 16'h5389, 8'h10};
    assign cfg_array[185] = {8'h78, 16'h538a, 8'h01};
    assign cfg_array[186] = {8'h78, 16'h538b, 8'h98};
    assign cfg_array[187] = {8'h78, 16'h5580, 8'h06}; // SDE Control
    assign cfg_array[188] = {8'h78, 16'h5583, 8'h40};
    assign cfg_array[189] = {8'h78, 16'h5584, 8'h10};
    assign cfg_array[190] = {8'h78, 16'h5589, 8'h10};
    assign cfg_array[191] = {8'h78, 16'h558a, 8'h00};
    assign cfg_array[192] = {8'h78, 16'h558b, 8'hf8};
    assign cfg_array[193] = {8'h78, 16'h501d, 8'h40}; // ISP Misc
    assign cfg_array[194] = {8'h78, 16'h5300, 8'h08}; // Color Interpolation (CIP)
    assign cfg_array[195] = {8'h78, 16'h5301, 8'h30};
    assign cfg_array[196] = {8'h78, 16'h5302, 8'h10};
    assign cfg_array[197] = {8'h78, 16'h5303, 8'h00};
    assign cfg_array[198] = {8'h78, 16'h5304, 8'h08};
    assign cfg_array[199] = {8'h78, 16'h5305, 8'h30};
    assign cfg_array[200] = {8'h78, 16'h5306, 8'h08};
    assign cfg_array[201] = {8'h78, 16'h5307, 8'h16};
    assign cfg_array[202] = {8'h78, 16'h5309, 8'h08};
    assign cfg_array[203] = {8'h78, 16'h530a, 8'h30};
    assign cfg_array[204] = {8'h78, 16'h530b, 8'h04};
    assign cfg_array[205] = {8'h78, 16'h530c, 8'h06};
    assign cfg_array[206] = {8'h78, 16'h5025, 8'h00}; // Draw Window
    
    // =========================================================================
    // RESOLUTION, FORMATTING & CLOCKING: Explicitly 640x480 (VGA) @ 30fps
    // =========================================================================
    assign cfg_array[207] = {8'h78, 16'h3008, 8'h02}; // System Control
    assign cfg_array[208] = {8'h78, 16'h3035, 8'h11}; // PLL Control
    assign cfg_array[209] = {8'h78, 16'h3036, 8'h46}; // PLL Control 
    assign cfg_array[210] = {8'h78, 16'h3c07, 8'h08}; // 50/60Hz Detection
    assign cfg_array[211] = {8'h78, 16'h3820, 8'h47}; // Timing TC REG20 (V-Flip/Mirror)
    assign cfg_array[212] = {8'h78, 16'h3821, 8'h01}; // Timing TC REG21 (H-Binning)
    assign cfg_array[213] = {8'h78, 16'h3814, 8'h31}; // Timing X INC
    assign cfg_array[214] = {8'h78, 16'h3815, 8'h31}; // Timing Y INC
    
    assign cfg_array[215] = {8'h78, 16'h3800, 8'h00}; // HS (X Addr Start)
    assign cfg_array[216] = {8'h78, 16'h3801, 8'h00}; // HS
    assign cfg_array[217] = {8'h78, 16'h3802, 8'h00}; // VS (Y Addr Start)
    assign cfg_array[218] = {8'h78, 16'h3803, 8'h04}; // VS
    assign cfg_array[219] = {8'h78, 16'h3804, 8'h0a}; // HW (X Addr End)
    assign cfg_array[220] = {8'h78, 16'h3805, 8'h3f}; // HW
    assign cfg_array[221] = {8'h78, 16'h3806, 8'h07}; // VH (Y Addr End)
    assign cfg_array[222] = {8'h78, 16'h3807, 8'h9b}; // VH
    
    // --> Setting output strictly to 640x480 <--
    assign cfg_array[223] = {8'h78, 16'h3808, 8'h02}; // DVPHO (Output H-Width = 0x0280 = 640)
    assign cfg_array[224] = {8'h78, 16'h3809, 8'h80}; // DVPHO
    assign cfg_array[225] = {8'h78, 16'h380a, 8'h01}; // DVPVO (Output V-Height = 0x01E0 = 480)
    assign cfg_array[226] = {8'h78, 16'h380b, 8'he0}; // DVPVO
    
    assign cfg_array[227] = {8'h78, 16'h380c, 8'h07}; // HTS (Total H-Size)
    assign cfg_array[228] = {8'h78, 16'h380d, 8'h68}; // HTS
    assign cfg_array[229] = {8'h78, 16'h380e, 8'h03}; // VTS (Total V-Size)
    assign cfg_array[230] = {8'h78, 16'h380f, 8'hd8}; // VTS
    assign cfg_array[231] = {8'h78, 16'h3813, 8'h06}; // Timing VOFFSET
    
    assign cfg_array[232] = {8'h78, 16'h3618, 8'h00}; 
    assign cfg_array[233] = {8'h78, 16'h3612, 8'h29};
    assign cfg_array[234] = {8'h78, 16'h3709, 8'h52};
    assign cfg_array[235] = {8'h78, 16'h370c, 8'h03};
    assign cfg_array[236] = {8'h78, 16'h3a02, 8'h17}; // 60Hz Max Exposure
    assign cfg_array[237] = {8'h78, 16'h3a03, 8'h10}; // 60Hz Max Exposure
    assign cfg_array[238] = {8'h78, 16'h3a14, 8'h17}; // 50Hz Max Exposure
    assign cfg_array[239] = {8'h78, 16'h3a15, 8'h10}; // 50Hz Max Exposure
    assign cfg_array[240] = {8'h78, 16'h4004, 8'h02}; // BLC CTRL04
    assign cfg_array[241] = {8'h78, 16'h3002, 8'h1c}; // SYSTEM RESET02
    assign cfg_array[242] = {8'h78, 16'h3006, 8'hc3}; // CLOCK ENABLE02
    assign cfg_array[243] = {8'h78, 16'h4713, 8'h03}; // JPG MODE SELECT
    assign cfg_array[244] = {8'h78, 16'h4407, 8'h04}; // JPEG CTRL07
    assign cfg_array[245] = {8'h78, 16'h460b, 8'h35}; // VFIFO CTRL0B
    assign cfg_array[246] = {8'h78, 16'h460c, 8'h22}; // VFIFO CTRL0C
    assign cfg_array[247] = {8'h78, 16'h4837, 8'h22}; // MIPI PCLK PERIOD
    assign cfg_array[248] = {8'h78, 16'h3824, 8'h02}; // Timing DVP PCLK Divider
    assign cfg_array[249] = {8'h78, 16'h5001, 8'h83}; // ISP CONTROL 01
    assign cfg_array[250] = {8'h78, 16'h3503, 8'h00}; // AEC PK MANUAL
    assign cfg_array[251] = {8'h78, 16'h3016, 8'h02}; // PAD OUTPUT ENABLE 00
    assign cfg_array[252] = {8'h78, 16'h3b07, 8'h0a}; // FREX MODE
    assign cfg_array[253] = {8'h78, 16'h3b00, 8'h83}; // STROBE CTRL
//-----------------------------------------------------------------------------


always @(posedge clk_24M or negedge s_rst_n) begin // Busy array logic
	if(s_rst_n == 1'b0)
		busy_array <= 'd0; // 3-bit reg of cascaded flip flop, at every clk cycle it grabs bust signal from i2c and shits it to left ( kinda memory of last 3 clocks )  
	else 
		busy_array <= {busy_array[1:0],busy}; // shift register
end
    
    assign	busy_neg = (~busy_array[1]) & busy_array[2];

always @(posedge clk_24M or negedge s_rst_n) begin // Initilaize Start 
	if(s_rst_n == 1'b0)
		start <= 1'b0;
	else 
	if(cfg_index == 'd0 && start == 1'b0) 
		start <= 1'b1;
	else 
	if(busy_neg == 1'b1 && cfg_index < NUM_REG)
		start <= 1'b1;
	else start <= 1'b0;
end


always @(posedge clk_24M or negedge s_rst_n) begin // Initialize configuration index when start = 1
	if(s_rst_n == 1'b0)
		cfg_index <= 'd0;
	else 
	if(cfg_index >= NUM_REG)
		cfg_index <= NUM_REG;
	else 
	if(start == 1'b1)
		cfg_index <= cfg_index + 1'b1;
end


always @(posedge clk_24M or negedge s_rst_n) begin // Initialize delay count of 200us
	if(s_rst_n == 1'b0)
		cnt_200us <= 'd0;
	else 
	if(cfg_index >= NUM_REG && cfg_done == 1'b0)
		cnt_200us <= cnt_200us + 1'b1;
end


assign	cfg_done = (cnt_200us >= DELAY_20ms) ? 1'b1: 1'b0;

sccb ov5640_iic_inst(
	.clk_24M	(clk_24M),
	.s_rst_n    (s_rst_n),

	.w_data     (cfg_array[cfg_index]),
	.start      (start),
	.riic_data  (),
	
	.busy       (busy      ),      
	.iic_clk    (iic_clk   ),
	.iic_sda    (iic_sda   )

);

endmodule