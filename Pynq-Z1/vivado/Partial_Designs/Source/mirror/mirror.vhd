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
	
	--#######################

	--registered video signals
	
	signal rgb_out_next : std_logic_vector(23 downto 0);
	signal vde_out_next : std_logic;
	signal hs_out_next   : std_logic;
	signal vs_out_next   : std_logic;

--state machine
type state_type is (row0,beginRow, sentHS, sentVS ,pass);  --type of state machine.
signal current_s,next_s: state_type := row0;  --current and next state declaration.

--HDMI signals
signal VDE      			: STD_LOGIC; --video enable
signal VDE_next 			: STD_LOGIC;
signal VDE_Last_clk 		: STD_LOGIC;
signal VDE_Last_clk_next 	: STD_LOGIC;
signal HS       			: STD_LOGIC; --H sync
signal HS_next  			: STD_LOGIC;
signal VS       			: STD_LOGIC; --V sync
signal VS_next  			: STD_LOGIC;
signal black_const 			: std_logic_vector(23 downto 0):= (others => '0');
signal color 				: std_logic_vector(23 downto 0);
signal color_next 			: std_logic_vector(23 downto 0);

--*****************
--  BRAM signals
--*****************
signal ena        	: STD_LOGIC :='0';
signal ena_next   	: STD_LOGIC :='0';
signal wea        	: STD_LOGIC :='0';
signal wea_next   	: STD_LOGIC :='0';
signal addra        : STD_LOGIC_VECTOR(10 downto 0) := (others =>'0');
signal addra_next   : STD_LOGIC_VECTOR(10 downto 0) := (others =>'0');
signal dina         : STD_LOGIC_VECTOR(23 downto 0) := (others =>'0');
signal dina_next    : STD_LOGIC_VECTOR(23 downto 0) := (others =>'0');
signal enb         	: STD_LOGIC :='0';
signal enb_next    	: STD_LOGIC :='0';
signal addrb        : STD_LOGIC_VECTOR(10 downto 0) := (others =>'0');
signal addrb_next   : STD_LOGIC_VECTOR(10 downto 0) := (others =>'0');
signal doutb        : STD_LOGIC_VECTOR(23 downto 0) := (others =>'0');

signal addr			: STD_LOGIC_VECTOR(10 downto 0) := (others =>'0');
signal addr_next	: STD_LOGIC_VECTOR(10 downto 0) := (others =>'0');

signal up_or_down		: STD_LOGIC := '0';
signal up_or_down_next	: STD_LOGIC := '0';

--***********************
--  Compoment declaration
--***********************
--The BRAM
COMPONENT blk_mem_gen_0 IS
  PORT(
	    CLKA        : IN  STD_LOGIC;
        ENA         : IN  STD_LOGIC;
        WEA         : IN  STD_LOGIC;
        ADDRA       : IN  STD_LOGIC_VECTOR(10 downto 0);
        DINA        : IN  STD_LOGIC_VECTOR(23 downto 0);
        CLKB        : IN  STD_LOGIC;
        ENB         : IN  STD_LOGIC;
        ADDRB       : IN  STD_LOGIC_VECTOR(10 downto 0);
        DOUTB       : OUT STD_LOGIC_VECTOR(23 downto 0));
 END COMPONENT;


begin

	process (PIXEL_CLK)
	begin
	if (rising_edge(PIXEL_CLK)) then
	   --state change.
	  current_s <= next_s;
	  
	  --HDMI signals
	  VDE 			<= VDE_next;
	  HS 			<= HS_next;
	  VS 			<= VS_next;
	  color 		<= color_next;
	  VDE_Last_clk	<= VDE_Last_clk_next;
	  
	  --BRAM signals
	  ena 			<= ena_next;
	  wea 			<= wea_next;
	  addra 		<= addra_next;
	  dina			<= dina_next;
	  enb 			<= enb_next;
	  addrb 		<= addrb_next;

	  addr			<= addr_next;
	  up_or_down	<= up_or_down_next;
	  
	end if;
	end process;


	--state machine process.
	process (current_s,VDE_IN_reg, HS_IN_reg, VS_IN_reg)
	begin

	  --default values for BRAM
	  ena_next 				<= '0';
	  wea_next 				<= '0';
	  addra_next 			<= (others => '0');
	  dina_next				<= (others => '0');
	  enb_next 				<= '0';
	  addrb_next 			<= (others => '0');
	  
	  up_or_down_next		<= up_or_down;
	 
	  
	  --defult HDMI signals
	  color_next 		<= black_const;
	  VDE_next 			<= '0';
	  HS_next 			<= '0';
	  VS_next 			<= '0';
	  VDE_Last_clk_next <= VDE_IN_reg;
	  
	  
	  case current_s is
		 when row0 =>        --when current state is "row0"
		 
			 if(VDE_IN_reg = '1') then --when screen starts being displays
				--write to the BRAM
				ena_next 			<= '1';
				wea_next 			<= '1';
				dina_next			<= RGB_IN_reg;
				next_s 				<= row0;
			
			 elsif(HS_IN_reg ='1') then -- then HS goes high changing rows 
				next_s 				<= sentHS; -- go to beginrow
				
			 end if; 

		 when beginRow =>
		 
			if(VDE_IN_reg = '1') then --when screen starts being displays
				--write to the BRAM
				ena_next 			<= '1';
				wea_next 			<= '1';
				dina_next			<= RGB_IN_reg;
				--start read from BRAM, will be ready next clk
				enb_next 	<= '1';
				next_s <= pass; -- go to pass
			elsif(VS_IN_reg ='1') then
				next_s <= sentVS;
			else
				next_s <= beginRow; -- go to beginrow
				
			end if;
		 

		 when pass =>        --when current state is "pass"
		 
			 if(VDE_IN_reg = '1') then
				--turn on VDE
				VDE_next 			<= '1';
				--write to the BRAM
				ena_next 			<= '1';
				wea_next 			<= '1';
				dina_next			<= RGB_IN_reg;
				--start read from BRAM, will be ready next clk
				enb_next 	<= '1';
				--output color
				color_next 			<= doutb;
				next_s <= pass; -- go to pass		 
			 
			elsif(VS_IN_reg ='1') then
				next_s <= sentVS;
				
			elsif(HS_IN_reg ='1') then -- then HS goes high changing rows
				next_s <= sentHS;
				
			elsif(VDE_IN_reg = '0' and VDE_Last_clk = '1') then --last pixel on row
				--turn on VDE
				VDE_next 			<= '1';
				--output color
				color_next 			<= doutb;
				next_s 				<= pass; -- go to pass
							
			 end if;
			 
		 when sentHS =>
			--set HS high to do to new row
			HS_next 			<= '1';
			up_or_down_next		<= not up_or_down; -- address go back down
			next_s 		<= beginRow;
			if(VS_IN_reg ='1') then
				next_s <= sentVS;
			end if;
			
		 when sentVS =>
			--set VS high to do to frame
			up_or_down_next 	<= '0';
			VS_next 			<= '1';
			next_s <= row0;	
		
			 


	  end case;
	end process;

	addr_next <= STD_LOGIC_VECTOR(unsigned(addr) + 1) when VDE_IN_reg = '1' and up_or_down = '0' else
				 STD_LOGIC_VECTOR(unsigned(addr) - 1) when VDE_IN_reg = '1' and up_or_down = '1' else
				 (others => '0') when VS_IN_reg = '1' else
				 addr;
				 
	rgb_out_next <= color;
	vde_out_next <= VDE;
	hs_out_next <= HS;
	vs_out_next <= VS;
	


	--**************************
	--  BRAM
	--**************************
	--this bram is read first
	blk_mem_inst : blk_mem_gen_0 
		PORT MAP (
			   CLKA        => PIXEL_CLK,
			   ENA         => ena,
			   WEA         => wea,
			   ADDRA       => addr,
			   DINA        => dina,
			   CLKB        => PIXEL_CLK,
			   ENB         => enb,
			   ADDRB       => addr,
			   DOUTB       => doutb);
	
	--the user can edit the rgb values here
	USER_LOGIC <= RGB_IN_reg; 
	






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
