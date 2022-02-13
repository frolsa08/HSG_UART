-- Filename     : uart.vhd
-- Author       : Dmitriy Frolov
-- Date         : 21.11.2021
-- Annotation   : UART with 2 stop bits 
-- Version      : 8
-- Mod.Data     : 03.12.2021

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_unsigned.all;

entity uart is
	generic(
		clk_freq 	: integer := 50_000_000;
		bit_rate 	: integer := 115_200									
	);
			
    port (
        clk 	: in   	std_logic;
        rst 	: in   	std_logic;
		-- tx  
        tx  	: out  	std_logic;		  
		tx_run  : in    std_logic;
        tx_data : in   	std_logic_vector (7 downto 0);
		tx_bust : out 	std_logic;
		-- rx 
		rx 		: in   	std_logic; 
		rx_data : out  	std_logic_vector (7 downto 0)
    );
end entity;

architecture rtl of uart is

	 constant 	MAX_RANGE		: integer   := (clk_freq/bit_rate)-1;
	
	 -- signals for PB --
	 signal 	tx_run_prev 	: std_logic;	-- предыдущее нажатие кнопки
	 signal 	tx_freq_en  	: std_logic;	-- текущее состояние
	 -- signals and type for tx -- 
	 signal 	tx_reg         	: std_logic_vector (7 downto 0)	:= "00000000";			
	 signal     tx_enable		: std_logic	:= '0';
	 signal		tx_cnt			: integer range 0 to 7	:=  0;	-- счетчик битов для отправки
	 signal 	tx_freq_strob	: std_logic := '0';	-- '1' если счетчик для TX досчитал
	 signal 	ClkCntTX		: integer range 0 to MAX_RANGE	:=  0	;	--счетчик для TX

	 type		t_state_TX is (PB, START_TX, B0_TO_7, STOP1, STOP2);
	 signal		state_TX			: t_state_TX;
	 
	 -- signal and type for rx --
	 signal 	rx_reg         	: std_logic_vector (7 downto 0)	:= "00000000";
	 signal		rx_cnt			: integer range 0 to 7	:=  0	;
	 signal 	rx_freq_strob 	: std_logic;
	 signal 	ClkCntRX 		: integer range 0 to MAX_RANGE	:=  0	;
	 signal 	rx_freq_en 		: std_logic;
	 signal 	stop_cnt_rx		: std_logic;

	 type 		t_StateRX is (START_RX, BIT_0_TO_7, STOP_RX);
	 signal 	StateRX : t_StateRX; 

	--- other
	signal flag					: std_logic := '0';	--'1' Передается синусоида; '0' - Отправка закончена
	signal cnt_sin 				: integer range 0 to 999; -- кол-во точек синусоиды, которая передается по UART

begin
    
    -- counter for data valid TX
	TX_count: process (clk, rst) begin
		if (rst = '1') then
			ClkCntTX 		<= 	 0	;
			tx_freq_strob 	<= 	'0' ;
			
		elsif (rising_edge(clk)) then
		   if tx_freq_en = '1' then
				if (ClkCntTX = MAX_RANGE - 1) then
					tx_freq_strob 	<= 	'1';
					ClkCntTX    	<= 	 0	;
				else
					ClkCntTX    	<= ClkCntTX + 1 ;
					tx_freq_strob	<= 	'0';
				end if;
			else
				ClkCntTX <= 0;
				tx_freq_strob <= '0';
			end if;
				
		end if;
	 end process TX_count;
			
    -- UART TX 
    TX_PROC: process (clk, rst) begin
        if (rst = '1') then
            tx_reg        	<=  (others=>'0');
			tx				<= '1';
			state_TX		<= START_TX;
			tx_cnt			<=	0 ;
			tx_freq_en 		<= '0';
			tx_bust 		<= '0';
			tx_enable		<= '0';
			
				
        elsif (rising_edge(clk)) then
		  
			tx_run_prev <= tx_run; -- for PB
			  
			case state_TX is

				when PB 	=>
					if tx_run_prev = '0' and tx_run = '1' and flag = '0' then	-- PushButton state
						tx_enable 	<= '1';
						state_TX	<= START_TX;
					elsif flag = '1' then
						tx_enable 	<= '1';
						state_TX	<= START_TX;
					else
						state_TX 	<= PB;

					end if;

	
				when START_TX 	=>
					if tx_enable <= '1' then	
						tx         	<= '0';		-- START_TX bit;
						tx_freq_en 	<= '1';
						tx_reg     	<= tx_data;
						tx_bust		<= '1';
						state_TX 	<= B0_TO_7;
					else 
						tx_bust		<= '0';
					end if;
						
				when B0_TO_7 =>
					tx_bust		<= '0';
					if tx_freq_strob = '1' then
						tx <= tx_reg(tx_cnt);
						if tx_cnt = 7 then
							tx_cnt	<= 0;
							state_TX <= STOP1;
						else
							tx_cnt <= tx_cnt + 1;
						end if;
					end if;
					
					
				when STOP1 =>
					if tx_freq_strob = '1' then
						tx			<= '1';		-- stop bit
						state_TX <= STOP2;
					end if;
					
				when STOP2  =>
					if tx_freq_strob = '1' then
						tx			<= '1';		-- stop bit
						tx_enable   <= '0';
						
						if cnt_sin =  900 then
							flag 		<= '0';
							cnt_sin 	<= 0;
							state_TX	<= PB ;
						else
							flag <= '1';
							cnt_sin <= cnt_sin + 1;
							state_TX <= PB;
						end if;

					end if;
			end case;
		end if;
    end process TX_PROC;
	 


	RX_COUNT_PROC : process(clk, rst)
	begin
		if (rst = '1') or (stop_cnt_rx = '1') then
			ClkCntRX 		<= 0  ;
			rx_freq_strob 	<= '0';
		elsif (rising_edge(clk)) then
			if (rx_freq_en = '1') then
				if (ClkCntRX = MAX_RANGE - 1) then
					rx_freq_strob <= '1';
					ClkCntRX <= 0;
				else
					ClkCntRX <= ClkCntRX + 1;
					rx_freq_strob <= '0';
				end if;
			else
				ClkCntRX 		<=  0;
				rx_freq_strob 	<= '0';
			end if;
		end if;
	end process RX_COUNT_PROC;

	 -- UART RX
RX_PROC: process (clk, rst)
begin
	if (rst = '1') then
        rx_reg        	<=  (others=>'0')	;
		StateRX			<=  START_RX		;
		rx_cnt			<=	 0				;
		rx_freq_en		<=  '0'				;
	elsif (rising_edge(clk)) then
		case StateRX is
			-- start bit for RX
			when START_RX =>
				rx_freq_en 	<= '1';
				if rx_freq_strob = '1' and rx = '0' then	-- START_TX bit
					StateRX <= BIT_0_TO_7;
				else
					StateRX <= START_RX;
				end if;

			-- Check middle of start bit
			--when START_RX_MIDDLE =>
			--	if ClkCntRX = (MAX_RANGE - 1) / 2 then
			--		if rx = '0' then 
			--			stop_cnt_rx <= '1'; -- сигнал обнуление счетчика для rx
			--			StateRX <= BIT_0_TO_7;
			--		else
			--			StateRX <= START_RX;
			--		end if;
			--	else
			--		StateRX <= START_RX_MIDDLE;
			--	end if;

			-- serial data send	
			when BIT_0_TO_7 =>
				stop_cnt_rx <= '0';
				if rx_freq_strob = '1' then
					rx_reg(rx_cnt) <= rx;
					if rx_cnt = 7 then
						StateRX		<= STOP_RX;
						rx_cnt		<=	0;
					else
						rx_cnt <= rx_cnt + 1;
					end if;
				end if;
			-- Send stop bit= SB = '1';	
			when STOP_RX =>
				if rx = '1' and rx_freq_strob = '1' then	-- stop bit
					rx_data <= rx_reg;
					StateRX <= START_RX;
				end if;
		end case;	
	end if;
end process RX_PROC;
	

end architecture;