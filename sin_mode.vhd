-- Filename     : sin_mode.vhd
-- Author       : Dmitriy Frolov
-- Date         : 29.11.2021
-- Annotation   : Generating harmonic signals
-- Version      : 7
-- Mod.Data     : 27.01.2022
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sin_mode is
    generic(   
        U_M         : integer := 99;   -- Амплитуда выходного сигнала
        BIT_WIDTH   : integer := 16;     -- Ширина шины
        ANGLE       : integer := 1      -- Шаг дискретизации сигнала
    );

    port (
        clk         : in std_logic;
        rst         : in std_logic;
        tx_val_in   : in std_logic;     -- Сигнал, разрешающий передачу данных;
        data_out    : out std_logic_vector(BIT_WIDTH - 1 downto 0)  -- выходная шина данных
		
    );
end entity;

architecture rtl of sin_mode is

    constant MAX_SIZE   : integer := 360; -- Кол - во углов для одного периода синусоиды;
    constant LEN        : integer := abs(MAX_SIZE / ANGLE); -- Длина массива, определяемая значением угла;
    constant LEN_SAW    : integer := abs(2 * U_M / ANGLE) ;   -- Длина массива, для пилообразного сигнала;
 
    -- КА для передачи данных сигнала на data_out 
    type		SIN_STATE is  (START, START_SIN_UP);
	signal		State		: SIN_STATE;

    signal i : integer range 0 to LEN	:=	0;  -- счетчик для передачи данных из массива в data_out

    type SIN_ARR is array (0 to LEN) of integer;   -- пустой массив принимающий значения точек для синуса
    type SAW_ARRAY is array (0 to LEN_SAW) of integer;  -- пустой массив принимающий значения точек для пилообразного сигнала
    type COS_ARR is array (0 to LEN) of integer;  -- пустой массив принимающий значения точек для cos
    
    -- Функция фактораила. 
    -- Возвращает Res = n!;
    function factorial (x : integer) return real is
        variable prod : integer := 1;
        begin
            for i in 1 to x loop
                prod := prod * i;
            end loop;
        return real(prod);
    end function;

    -- Функция возведения в степень
    -- Возвращает res = x ^ y;
    function pow (x : real; y : integer) return real is
        variable res : real := 1.0;
        begin
            for i in 1 to y loop
                res := res * x;
            end loop;
        return res;
    end function;

    -- Функция. Генерация синосидального сигнала при помощи разложения аргументов в ряд Маклорена
    -- Аргумент х означет угол (в градусах), для которого рассчитывается синусоида
    -- Возвращает значение синусоиды для данного угла, умноженное на амплитуду U_M
    function sin_wave(x : integer) return integer is 
        variable x_r        : real;
        variable summ_r     : real;
        begin
            x_r     	:= (real(x)  * 3.141592 / 180.0);
            summ_r      := round(real(U_M) * (x_r - (pow(x_r, 3) /factorial(3)) + (pow(x_r, 5)/factorial(5)) - (pow(x_r, 7)/factorial(7)) + (pow(x_r, 9)/factorial(9)) - (pow(x_r, 11)/factorial(11))));
            return integer(summ_r);
    end function;
        
    -- функция проверки четности
    -- возвращает TRUE если x mod 2 = 0 (то есть число четное)
    function even(x : integer) return boolean is
        variable us_len : unsigned(BIT_WIDTH - 1 downto 0);
        begin
            us_len := to_unsigned(x, BIT_WIDTH);
            if us_len(0) = '0' then
                return TRUE;
            else
                return FALSE;
            end if;
    end function;
 
    -- Функция заполнения массива. Ф-ция принмает аргумент
    -- iter, означающий шаг для угла синусоиды;
	function sin_array(iter : integer) return SIN_ARR is
        variable x      	: integer := 0;
        variable arr		: SIN_ARR;
        variable j          : integer := 0;
        begin
            if even(LEN) then
                for i in 0 to (LEN / 2 - 1) loop
                    arr(i)  := sin_wave(x);
                    x       := x + iter;
                end loop;

                for i in (LEN / 2) to (LEN) loop
                    arr(i)  :=  - arr(j);
                    j       :=  j + 1;
                end loop;
            else
                for i in 0 to (LEN / 2) loop
                    arr(i)  := sin_wave(x);
                    x       := x + iter;
                end loop;
                
                for i in (LEN / 2 + 1) to (LEN - 1) loop
                    arr(i)  :=  - arr(j);
                    j       :=  j + 1;
                end loop;
            end if;            
        return arr;
    end function;

    -- Функция заполнения массива, формирующая пилообразный сигнал 
    --Ф-ция принмает аргумент iter, означающий шаг дискретизации;
    -- Выход - сформерованный массив точек для пилы
    function SAW_SIGNAL_ARRAY (iter : integer) return SAW_ARRAY is
        variable x      : integer := 0;
        variable arr    : SAW_ARRAY ;
        begin
            if even(LEN_SAW) then
                for i in 0 to (LEN_SAW / 2 ) loop
                    arr(i) := x;
                    x := x + iter;
                end loop;

                x := - U_M;

                for i in (LEN_SAW / 2 + 1) to (LEN_SAW) loop
                    arr(i) := x;
                    x := x + iter;
                end loop;
            else
                for i in 0 to (LEN_SAW / 2) loop
                    arr(i) := x;
                    x := x + iter;
                end loop;

                x := - U_M;

                for i in (LEN_SAW / 2 + 1) to (LEN_SAW - 1) loop
                    arr(i) := x;
                    x := x + iter;
                end loop;
            end if;
            return arr;        
    end function;

    -- Функция заполнения массива. Ф-ция принмает аргумент
    -- iter, означающий шаг дискретизации cos(x);
	function cos_array(iter : integer) return COS_ARR is
        variable x      	: integer := 0;
        variable arr		: COS_ARR;
        variable j          : integer := 0;
        begin
            if even(LEN) then
                for i in 0 to (LEN / 2 - 1) loop
                    arr(i)  := sin_wave(90 - x);
                    x       := x + iter;
                end loop;
    
                for i in (LEN / 2) to (LEN) loop
                    arr(i)  :=  - arr(j);
                    j       :=  j + 1;
                end loop;
            else
                for i in 0 to (LEN / 2) loop
                    arr(i)  := sin_wave(90 - x);
                    x       := x + iter;
                end loop;
                
                for i in (LEN / 2 + 1) to (LEN - 1) loop
                    arr(i)  :=  - arr(j);
                    j       :=  j + 1;
                end loop;
            end if;            
            return arr;
    end function;
	 
    constant S_ARR      : SIN_ARR   := sin_array(ANGLE);  -- сформерованный константный массив значений синуса
    constant SAW_ARR    : SAW_ARRAY := SAW_SIGNAL_ARRAY(ANGLE); -- сформерованный константный массив значений пилообразного сигнала;
    constant C_ARR      : COS_ARR   := cos_array(ANGLE); -- сформерованный константный массив значений cos(x);
    

begin

    SIN_PROC : process(clk, rst)
    begin
        
        if rst = '1' then
            State <= START;
            i 	  <= 	0;
        elsif (rising_edge(clk)) then
            case State is

                when START =>
                    if tx_val_in = '1' then
                        State   	<= START_SIN_UP;
						i 			<= 	0;	
                    else 
                        State <= START;
                   end if;

                -- положительный полупериод синуса
                when START_SIN_UP =>
                    if tx_val_in = '1' then
                        data_out    <= std_logic_vector(to_signed(S_ARR(i), BIT_WIDTH)); -- передача данных на шину
                        i  <= i + 1;
                        if i = LEN - 1 then
                            i <= 0;
                        end if;
                        --data_out    <= std_logic_vector(to_signed(SAW_ARR(i), BIT_WIDTH)); -- ПИЛА
                        -- if (i = LEN_SAW / 2) then -- ПИЛА
                        --if (i = LEN / 2) then
                        --    i  <= i + 1; 
                        --    State   <= START_SIN_DOWN;
                        --else	
						--	i  <= i + 1;
                        --end if;
                    end if;
			end case;
        end if;
    end process;

end architecture rtl;
