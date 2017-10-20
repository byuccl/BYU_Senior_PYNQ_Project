----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/10/2017 11:07:04 AM
-- Design Name: 
-- Module Name: Video_Box - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Video_Box is
generic (
    -- Width of S_AXI data bus
    C_S_AXI_DATA_WIDTH    : integer    := 32;
    -- Width of S_AXI address bus
    C_S_AXI_ADDR_WIDTH    : integer    := 11
);
port (
    S_AXI_ARESETN : in std_logic;
    slv_reg_wren : in std_logic;
    slv_reg_rden : in std_logic;
    S_AXI_WSTRB    : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    axi_awaddr    : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_WDATA    : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    axi_araddr    : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    reg_data_out    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    
    --Bus Clock
    S_AXI_ACLK : in std_logic;
    --Video
    RGB_IN : in std_logic_vector(23 downto 0); -- Parallel video data (required)
    VDE_IN : in std_logic; -- Active video Flag (optional)

    HS_IN : in std_logic; -- Horizontal sync signal (optional)
    VS_IN : in std_logic; -- Veritcal sync signal (optional)

    --  additional ports here
    RGB_OUT : out std_logic_vector(23 downto 0); -- Parallel video data (required)
    VDE_OUT : out std_logic; -- Active video Flag (optional)

    HS_OUT : out std_logic; -- Horizontal sync signal (optional)
    VS_OUT : out std_logic; -- Veritcal sync signal (optional)

    
    PIXEL_CLK : in std_logic;
    
    X_Coord : in std_logic_vector(15 downto 0);
    Y_Coord : in std_logic_vector(15 downto 0)

);
end Video_Box;

architecture Behavioral of Video_Box is


	constant ADDR_LSB  : integer := (C_S_AXI_DATA_WIDTH/32)+ 1;
	constant OPT_MEM_ADDR_BITS : integer := C_S_AXI_ADDR_WIDTH-ADDR_LSB-1;
	signal slv_reg0	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg1	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg2	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg3	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg4	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg5	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg6	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg7	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	
	signal RGB_IN_reg, RGB_OUT_reg: std_logic_vector(23 downto 0):= (others=>'0');
	signal X_Coord_reg,Y_Coord_reg : std_logic_vector(15 downto 0):= (others=>'0');
	signal VDE_IN_reg,VDE_OUT_reg,HS_IN_reg,HS_OUT_reg,VS_IN_reg,VS_OUT_reg : std_logic := '0';
	signal USER_LOGIC : std_logic_vector(23 downto 0);
	--##################################################

	--registered video signals
	
	signal rgb_out_next : std_logic_vector(23 downto 0);
	signal vde_out_next : std_logic;
	signal hs_out_next   : std_logic;
	signal vs_out_next   : std_logic;

	--HDMI signals
	signal VDE      			: STD_LOGIC; --video enable
	signal VDE_next 			: STD_LOGIC;
	signal VDE_Last_clk 		: STD_LOGIC;
	signal VDE_Last_clk_next 	: STD_LOGIC;
	signal HS       			: STD_LOGIC; --H sync
	signal HS_next			  	: STD_LOGIC;
	signal VS       			: STD_LOGIC; --V sync
	signal VS_next  			: STD_LOGIC;
	signal HS_delay  			: STD_LOGIC_VECTOR(21 downto 0);
	signal VS_delay  			: STD_LOGIC_VECTOR(21 downto 0);
	signal black_const 			: std_logic_vector(23 downto 0):= (others => '0');
	signal color 				: std_logic_vector(23 downto 0);
	signal color_next 			: std_logic_vector(23 downto 0);
	
	signal previous_pixel 				: std_logic_vector(23 downto 0);
	signal previous_pixel_next 			: std_logic_vector(23 downto 0);

	signal red_added, blue_added, green_added						: unsigned(19 downto 0):= (others => '0');
	signal red_added_next, blue_added_next, green_added_next		: unsigned(19 downto 0):= (others => '0');
	signal red_padded, blue_padded, green_padded					: unsigned(19 downto 0):= (others => '0');
	signal red, blue, green											: unsigned(7 downto 0):= (others => '0');
	signal red_out, blue_out, green_out 							: STD_LOGIC_VECTOR(39 downto 0);
	signal red_in, blue_in, green_in 							: STD_LOGIC_VECTOR(23 downto 0);
	signal red_valid, blue_valid, green_valid						:STD_LOGIC;
	signal divisor                                                   :STD_LOGIC_VECTOR(15 downto 0);

	--*****************
	--  FIFO signals
	--*****************
	--TOP ROW FIFO
	signal reset        : STD_LOGIC :='0';
	signal reset_next   : STD_LOGIC :='0';
	signal wr_en        : STD_LOGIC :='0';
	signal wr_en_next   : STD_LOGIC :='0';
	signal rd_en        : STD_LOGIC :='0';
	signal rd_en_next   : STD_LOGIC :='0';
	signal din          : STD_LOGIC_VECTOR(23 downto 0);
	signal din_next     : STD_LOGIC_VECTOR(23 downto 0);
	signal dout         :STD_LOGIC_VECTOR(23 downto 0);
	signal dout_next    :STD_LOGIC_VECTOR(23 downto 0);
	signal full         : STD_LOGIC;
	signal empty        : STD_LOGIC;
	
	signal blur_length, blur_length_next	: unsigned (15 downto 0);
	signal pixel_counter, pixel_counter_past: unsigned (15 downto 0);
	signal pixel_counter_next, pixel_counter_past_next: unsigned (15 downto 0);


	--***********************
	--  Compoment declaration
	--***********************
	--The FIFO
	COMPONENT fifo_generator_0 IS
	  PORT(
			CLK        :  IN  STD_LOGIC;
			SRST       :  IN  STD_LOGIC;
			WR_EN      :  IN STD_LOGIC;
			RD_EN      :  IN STD_LOGIC;
			DIN        : in STD_LOGIC_VECTOR(23 downto 0);
			DOUT       : out STD_LOGIC_VECTOR(23 downto 0);
			FULL       : out STD_LOGIC;
			EMPTY      : out STD_LOGIC);
	 END COMPONENT;
	 
	 --Divider
	 COMPONENT div_gen_0 IS
		PORT(
		    ACLK                        :  IN  STD_LOGIC;
			S_AXIS_DIVISOR_TVALID       :  IN  STD_LOGIC;
			S_AXIS_DIVISOR_TDATA        :  IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			S_AXIS_DIVIDEND_TVALID      :  IN  STD_LOGIC;
			S_AXIS_DIVIDEND_TDATA       :  IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
			M_AXIS_DOUT_TVALID          :  OUT STD_LOGIC;
			M_AXIS_DOUT_TDATA           :  OUT STD_LOGIC_VECTOR(39 DOWNTO 0));
		END COMPONENT;

	begin



	process (PIXEL_CLK)
	begin
	if (rising_edge(PIXEL_CLK)) then
	  
	  pixel_counter		<= pixel_counter_next;
	  pixel_counter_past <= pixel_counter_past_next;
	  previous_pixel	<= previous_pixel_next;
	  
	  red_added			<= red_added_next;
	  green_added		<= green_added_next;
	  blue_added		<= blue_added_next;
	  
	  reset      <=	reset_next;
	  VDE_Last_clk <= VDE_Last_clk_next;
		
	end if;
	end process;
	
	
	process (S_AXI_ACLK)
	begin
		if (rising_edge(S_AXI_ACLK)) then
		  
		  blur_length		<= blur_length_next;

		  
		end if;
	end process;
	
	VDE_Last_clk_next <= VDE_IN_reg;

	blur_length_next <= unsigned(slv_reg0(15 downto 0))+1;
	
	previous_pixel_next <= RGB_IN_reg;
	
	pixel_counter_past_next <= pixel_counter;
	
	pixel_counter_next 	<= 	("0000000000000001") when VDE_IN_reg = '0' else
							pixel_counter +1 when (pixel_counter) < blur_length else
							blur_length;
	
	wr_en 				<= '1' when (VDE_IN_reg = '1' and blur_length > 1) else
							'0';
					
	din					<= RGB_IN_reg when (VDE_IN_reg = '1' and blur_length > 1) else
							(others => '0');
				  
	rd_en		<=	'1' when (VDE_IN_reg = '1' and pixel_counter >= blur_length and blur_length > 1) else
                    '0';
				  
				  	  
				  
				  
	red_added_next <=	(others => '0') when VDE_IN_reg = '0' else
						"000000000000" & unsigned(RGB_IN_reg(23 downto 16)) when blur_length = 1 else
						( "000000000000" & unsigned(RGB_IN_reg(23 downto 16)) + unsigned( "000000000000" &previous_pixel(23 downto 16))) when blur_length = 2 else						
						red_added + ( "000000000000" & unsigned(RGB_IN_reg(23 downto 16))) when pixel_counter < blur_length or pixel_counter_past < blur_length else
						red_added + ("000000000000" & unsigned(RGB_IN_reg(23 downto 16))) - ("000000000000" & unsigned(dout(23 downto 16)));
				  
	green_added_next <=	(others => '0') when VDE_IN_reg = '0' else
						"000000000000" &unsigned(RGB_IN_reg(15 downto 8)) when blur_length = 1 else
						("000000000000" &unsigned(RGB_IN_reg(15 downto 8)) + unsigned("000000000000" &previous_pixel(15 downto 8))) when blur_length = 2 else
						green_added + ("000000000000" & unsigned(RGB_IN_reg(15 downto 8))) when pixel_counter < blur_length or pixel_counter_past < blur_length  else
						green_added + ("000000000000" & unsigned(RGB_IN_reg(15 downto 8))) - unsigned("000000000000" & dout(15 downto 8));			  
				  
	blue_added_next <=	(others => '0') when VDE_IN_reg = '0' else
						"000000000000" & unsigned(RGB_IN_reg(7 downto 0)) when blur_length = 1 else
						(unsigned("000000000000" & RGB_IN_reg(7 downto 0)) + unsigned("000000000000" & previous_pixel(7 downto 0))) when blur_length = 2 else
						blue_added + (unsigned("000000000000" & RGB_IN_reg(7 downto 0))) when pixel_counter < blur_length or pixel_counter_past < blur_length else
						blue_added + (unsigned("000000000000" & RGB_IN_reg(7 downto 0))) - unsigned("000000000000" & dout(7 downto 0));				  
				  
				  
	reset_next <=  '1' when VDE_IN_reg = '0' and VDE_Last_clk = '1' else
	               '0';		  
				  
				  

	red_padded <= 		unsigned(red_out(35 downto 16)) when red_valid = '1' else (others => '0');
					  
	green_padded <= 	unsigned(green_out(35 downto 16)) when green_valid = '1' else (others => '0');

	blue_padded <= 		unsigned(blue_out(35 downto 16)) when blue_valid = '1' else (others => '0');
	
	red_in      <=     "0000" & STD_LOGIC_vector(red_added_next);
	green_in      <=     "0000" & STD_LOGIC_vector(green_added_next);
	blue_in      <=     "0000" & STD_LOGIC_vector(blue_added_next);
					  
	red <=			"11111111" when red_padded > 255 else
					red_padded(7 downto 0);
					
	green <=		"11111111" when green_padded > 255 else
					green_padded(7 downto 0);
					
	blue <=			"11111111" when blue_padded > 255 else
					blue_padded(7 downto 0);
					
					
	HS_delay <= (HS_delay(20 downto 0) & HS_IN_reg) when rising_edge(PIXEL_CLK);
	VS_delay <= (VS_delay(20 downto 0) & VS_IN_reg) when rising_edge(PIXEL_CLK);	
		
	rgb_out_next <= STD_LOGIC_VECTOR(red(7 downto 0)) & STD_LOGIC_VECTOR(green(7 downto 0)) & STD_LOGIC_VECTOR(blue(7 downto 0));
	vde_out_next <= red_valid;
	hs_out_next <= HS_delay(21);
	vs_out_next <= VS_delay(21);

	
	divisor <= STD_LOGIC_VECTOR(pixel_counter);
	

	div_red : div_gen_0 
		PORT MAP (
		       ACLK                       => PIXEL_CLK,
			   S_AXIS_DIVISOR_TVALID      => VDE_IN_reg,
			   S_AXIS_DIVISOR_TDATA 	  => divisor,
			   S_AXIS_DIVIDEND_TVALID     => VDE_IN_reg,
			   S_AXIS_DIVIDEND_TDATA      => red_in,
			   M_AXIS_DOUT_TVALID         => red_valid,
			   M_AXIS_DOUT_TDATA           => red_out);
			   
			   
	div_green : div_gen_0 
		PORT MAP (    
		       ACLK                       => PIXEL_CLK,
			   S_AXIS_DIVISOR_TVALID      => VDE_IN_reg,
			   S_AXIS_DIVISOR_TDATA 	  => divisor,
			   S_AXIS_DIVIDEND_TVALID     => VDE_IN_reg,
			   S_AXIS_DIVIDEND_TDATA      => green_in,
			   M_AXIS_DOUT_TVALID         => green_valid,
			   M_AXIS_DOUT_TDATA           => green_out);
			   
	div_blue : div_gen_0 
		PORT MAP (
		      ACLK                       => PIXEL_CLK,
			   S_AXIS_DIVISOR_TVALID      => VDE_IN_reg,
			   S_AXIS_DIVISOR_TDATA 	  => divisor,
			   S_AXIS_DIVIDEND_TVALID     => VDE_IN_reg,
			   S_AXIS_DIVIDEND_TDATA      => blue_in,
			   M_AXIS_DOUT_TVALID         => blue_valid,
			   M_AXIS_DOUT_TDATA           => blue_out);

	--**************************
	--  FIFOs
	--**************************
	--FIFO for the top row in the 3x3 blur array
	top_row_fifo : fifo_generator_0 
		PORT MAP (
			   CLK                       => PIXEL_CLK,
			   SRST                      => reset,
			   WR_EN 		             => wr_en,
			   RD_EN                     => rd_en,
			   DIN                       => din,
			   DOUT                      => dout,
			   FULL                      => full,
			   EMPTY                     => empty);
			   
		-- Just pass through all of the video signals
	RGB_OUT 	<= RGB_OUT_reg;
	VDE_OUT		<= VDE_OUT_reg;

	HS_OUT		<= HS_OUT_reg;
	VS_OUT		<= VS_OUT_reg;
			   
	process(PIXEL_CLK) is
    begin
        if (rising_edge (PIXEL_CLK)) then
            -- Video Input Signals
            RGB_IN_reg <= RGB_IN;
            X_Coord_reg <= X_Coord;
            Y_Coord_reg  <= Y_Coord;
            VDE_IN_reg  <= VDE_IN;
            HS_IN_reg  <= HS_IN;
            VS_IN_reg  <= VS_IN;
            -- Video Output Signals
            RGB_OUT_reg  <= rgb_out_next;
            VDE_OUT_reg  <= vde_out_next;
            HS_OUT_reg  <= hs_out_next;
            VS_OUT_reg  <= vs_out_next;
 
         end if;
    end process;
		
	
	process (S_AXI_ACLK)
		variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0); 
	begin
	  if rising_edge(S_AXI_ACLK) then 
		if S_AXI_ARESETN = '0' then
		  slv_reg0 <= (others => '0');
		  slv_reg1 <= (others => '0');
		  slv_reg2 <= (others => '0');
		  slv_reg3 <= (others => '0');
		  slv_reg4 <= (others => '0');
		  slv_reg5 <= (others => '0');
		  slv_reg6 <= (others => '0');
		  slv_reg7 <= (others => '0');
		else
		  loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
		  if (slv_reg_wren = '1') then
			case loc_addr is
			  when b"000000000" =>
				for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
				  if ( S_AXI_WSTRB(byte_index) = '1' ) then
					-- Respective byte enables are asserted as per write strobes                   
					-- slave registor 0
					slv_reg0(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
				  end if;
				end loop;
			  when b"000000001" =>
				for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
				  if ( S_AXI_WSTRB(byte_index) = '1' ) then
					-- Respective byte enables are asserted as per write strobes                   
					-- slave registor 1
					slv_reg1(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
				  end if;
				end loop;
			  when b"000000010" =>
				for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
				  if ( S_AXI_WSTRB(byte_index) = '1' ) then
					-- Respective byte enables are asserted as per write strobes                   
					-- slave registor 2
					slv_reg2(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
				  end if;
				end loop;
			  when b"000000011" =>
				for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
				  if ( S_AXI_WSTRB(byte_index) = '1' ) then
					-- Respective byte enables are asserted as per write strobes                   
					-- slave registor 3
					slv_reg3(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
				  end if;
				end loop;
			  when b"000000100" =>
				for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
				  if ( S_AXI_WSTRB(byte_index) = '1' ) then
					-- Respective byte enables are asserted as per write strobes                   
					-- slave registor 4
					slv_reg4(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
				  end if;
				end loop;
			  when b"000000101" =>
				for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
				  if ( S_AXI_WSTRB(byte_index) = '1' ) then
					-- Respective byte enables are asserted as per write strobes                   
					-- slave registor 5
					slv_reg5(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
				  end if;
				end loop;
			  when b"000000110" =>
				for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
				  if ( S_AXI_WSTRB(byte_index) = '1' ) then
					-- Respective byte enables are asserted as per write strobes                   
					-- slave registor 6
					slv_reg6(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
				  end if;
				end loop;
			  when b"000000111" =>
				for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
				  if ( S_AXI_WSTRB(byte_index) = '1' ) then
					-- Respective byte enables are asserted as per write strobes                   
					-- slave registor 7
					slv_reg7(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
				  end if;
				end loop;
			  when others =>
				slv_reg0 <= slv_reg0;
				slv_reg1 <= slv_reg1;
				slv_reg2 <= slv_reg2;
				slv_reg3 <= slv_reg3;
				slv_reg4 <= slv_reg4;
				slv_reg5 <= slv_reg5;
				slv_reg6 <= slv_reg6;
				slv_reg7 <= slv_reg7;
			end case;
		  end if;
		end if;
	  end if;                   
	end process; 
		
	process (slv_reg0, slv_reg1, slv_reg2, slv_reg3, slv_reg4, slv_reg5, slv_reg6, slv_reg7, axi_araddr, S_AXI_ARESETN, slv_reg_rden)
		variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
	begin
		-- Address decoding for reading registers
		loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
		case loc_addr is
		  when b"000000000" =>
			reg_data_out <= slv_reg0;
		  when b"000000001" =>
			reg_data_out <= slv_reg1;
		  when b"000000010" =>
			reg_data_out <= slv_reg2;
		  when b"000000011" =>
			reg_data_out <= slv_reg3;
		  when b"000000100" =>
			reg_data_out <= slv_reg4;
		  when b"000000101" =>
			reg_data_out <= slv_reg5;
		  when b"000000110" =>
			reg_data_out <= slv_reg6;
		  when b"000000111" =>
			reg_data_out <= slv_reg7;
		  when others =>
			reg_data_out  <= (others => '0');
		end case;
end process;

end Behavioral;
