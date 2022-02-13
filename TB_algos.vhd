-- Filename     : TB_algos.vhd
-- Author       : Dmitriy Frolov
-- Date         : 29.11.2021
-- Annotation   : TestBench of algoritms for harmonic signals
-- Version      : 1
-- Mod.Data     : 29.12.21
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
use std.env.stop;

entity TB_algos is
    generic(
        ANGLE_TB    : integer := 1;
        U_M_TB      : integer := 50 
    ) ;
end TB_algos;

architecture sim of TB_algos is

    constant    clk_hz          : integer   := 100e6;
    constant    clk_period      : time      := 1 sec / clk_hz;
    constant    BIT_WIDTH       : integer   := 8;
    constant    MAX_SIZE        : integer   := 360; -- Max point count;
    constant    ANGLE           : integer   := ANGLE_TB;
    constant    LEN             : integer   := abs(MAX_SIZE / integer(ANGLE));
    

    signal      clk             : std_logic := '1';

    signal      i               : integer range 0 to LEN := 0; -- переменная индекс массива
    signal      sin_out         : real  := 0.0;    -- выход значений для синуса ф-ции Sin_Mode
    signal      test            : real  := 0.0; -- выход значений для синуса ф-ции SIN_MATH_REAL
    signal      delta           : real  := 0.0; -- разница между значениями синуса теста и алгоса 
    signal      sum_delta       : real  := 0.0; -- Суммарная погрешность на всем периоде
    

    type SIN_ARR is array (0 to LEN) of real;   -- пустой массив принимающий значения точек для синуса
    type TEST_SIN_ARR is array (0 to LEN) of real;   -- пустой массив принимающий значения точек для синуса

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
    function sin_wave(x : integer) return real is 
        variable x_r        : real;
        variable summ_r     : real;
        begin
            x_r     	:= (real(x)  * 3.14159265358979 / 180.0);
            summ_r      := (x_r - (pow(x_r, 3) /factorial(3)) + (pow(x_r, 5)/factorial(5)) - (pow(x_r, 7)/factorial(7)) + (pow(x_r, 9)/factorial(9)) - (pow(x_r, 11)/factorial(11)));-- + (pow(x_r, 13)/factorial(13)) - (pow(x_r, 15)/factorial(15))  + (pow(x_r, 17)/factorial(17)) - (pow(x_r, 19)/factorial(19)) + (pow(x_r, 21)/factorial(21)));
            return (summ_r); --* real(U_M_TB);
    end function;

    -- Функция заполнения массива. Ф-ция принмает аргумент
    -- iter, означающий шаг для угла синусоиды;
    -- то есть при х = 30 будет 12 точек в периоде синуса
    function sin_array_test(iter : integer) return TEST_SIN_ARR is
        variable x      	: integer := 0;
        variable arr		: TEST_SIN_ARR;
        variable j          : integer := 0;
        begin
            if even(LEN) then
                for i in 0 to (LEN / 2 - 1) loop
                    arr(i)  := SIN(MATH_DEG_TO_RAD * real(x)); --* real(U_M_TB);
                    x       := x + iter;
                end loop;
        
                for i in (LEN / 2) to (LEN) loop
                    arr(i)  :=  - arr(j);
                    j       :=  j + 1;
                end loop;
            else
                for i in 0 to (LEN / 2) loop
                    arr(i)  := real(U_M_TB) * SIN(real(x) * MATH_DEG_TO_RAD);
                    x       := x + iter;
                end loop;
                    
                for i in (LEN / 2 + 1) to (LEN ) loop
                    arr(i)  :=  - arr(j);
                    j       :=  j + 1;
                end loop;
            end if;            
            return arr;
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
                    j       := j + 1;
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


    constant S_ARR      : SIN_ARR        := sin_array(ANGLE);  -- сформерованный константный массив значений синуса от рядов
    constant S_ARR_TEST : TEST_SIN_ARR   := sin_array_test(ANGLE); -- сформерованный константный массив значений MATH_REAL_SIN
    

begin

    SEQUENCER_PROC : process
    begin

        wait for clk_period * 1;
        
        test <= S_ARR_TEST(i);
        sin_out <= S_ARR(i);
        delta <= abs(sin_out - test);  
        
        report "Angle = 1" ;
        report "delta MATH_REAL = " & real'image(abs(S_ARR_TEST(1) - 0.01745329251994352406)); -- sin(x)
        report "delta 1 = " & real'image(abs(S_ARR(1) - 0.01745329251994352406)); -- sin(x)
        report "Angle = 2" ;
        report "delta MATH_REAL = " & real'image(abs(S_ARR_TEST(2) - 0.034906585039887)); -- sin(x)
        report "delta 2 = " & real'image(abs(S_ARR(2) - 0.034906585039887)); -- sin(x)
        report "Angle = 3" ;
        report "delta MATH_REAL = " & real'image(abs(S_ARR_TEST(3) - 0.052359877559830)); -- sin(x)
        report "delta 3 = " & real'image(abs(S_ARR(3) - 0.052359877559830)); -- sin(x)
        report "Angle = 4" ;
        report "delta MATH_REAL = " & real'image(abs(S_ARR_TEST(4) - 0.069813170079773)); -- sin(x)
        report "delta 4 = " & real'image(abs(S_ARR(4) - 0.069813170079773)); -- sin(x)
        -------------------------------------------------------------------------
        report "Angle = 187" ;
        report "delta MATH_REAL = " & real'image(abs(S_ARR_TEST(187) - (-0.121869343405147))); -- sin(x)
        report "delta 187 = " & real'image(abs(S_ARR(187) - (-0.121869343405147))); -- sin(x)
        report "Angle = 188" ;
        report "delta 2 = " & real'image(abs(S_ARR(188) - (-0.139173100960065))); -- sin(x)
        report "delta MATH_REAL = " & real'image(abs(S_ARR_TEST(188) - (-0.139173100960065))); -- sin(x)
        report "Angle = 189" ;
        report "delta 3 = " & real'image(abs(S_ARR(189) - (-0.156434465040231 ))); -- sin(x)
        report "delta MATH_REAL = " & real'image(abs(S_ARR_TEST(189) - (-0.156434465040231 ))); -- sin(x)
        report "Angle = 190" ;
        report "delta 4 = " & real'image(abs(S_ARR(190) - (-0.173648177666930))); -- sin(x)
        report "delta MATH_REAL = " & real'image(abs(S_ARR_TEST(190) - (-0.173648177666930))); -- sin(x)
        

        if i = LEN - 1 then
            report "Sum_Delta = " & real'image(sum_delta);
            stop;
        end if;

    end process;

end architecture;