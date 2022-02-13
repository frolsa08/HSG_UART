-- Filename     : sin_mode_TB.vhd
-- Author       : Dmitriy Frolov
-- Date         : 29.11.2021
-- Annotation   : TestBench for sin_mode.vhd
-- Version      : 1
-- Mod.Data     : 29.12.21
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use std.textio.all;
use std.env.stop;

entity sin_mode_tb is
    generic(
        ANGLE_TB    : integer := 1;
        U_M_TB      : integer := 50 
    ) ;
end sin_mode_tb;

architecture sim of sin_mode_tb is

    constant    clk_hz          : integer   := 100e6;
    constant    clk_period      : time      := 1 sec / clk_hz;
    constant    BIT_WIDTH       : integer   := 8;
    constant    ANGLE           : integer   := (ANGLE_TB);

    constant    MAX_SIZE        : integer := 360; -- Кол - во углов для одного периода синусоиды;
    constant    LEN             : integer := abs(MAX_SIZE / ANGLE); -- Длина массива, определяемая значением угла;
    constant    LEN_SAW         : integer := abs(2 * U_M_TB / ANGLE) ;   -- Длина массива, для пилообразного сигнала;
    
    signal      clk             : std_logic := '1';
    signal      rst             : std_logic := '0';
    signal      tx_val_in       : std_logic := '0';
    signal      data_out        : std_logic_vector (7 downto 0);

    signal      err_cnt         : integer range 0 to LEN :=  0; -- счетчик ошибок
    signal      i               : integer range 0 to LEN := 0; -- переменная индекс массива
    signal      int_data_out    : integer range -U_M_TB to U_M_TB := 0;    -- int выход значений для синуса ф-ции Sin_Mode
    signal      test            : integer range -U_M_TB to U_M_TB := 0; -- int выход значений для синуса ф-ции SIN_MATH_REAL

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
    
        
    type SIN_ARR is array (0 to LEN) of integer;   -- пустой массив принимающий значения точек для синуса
        
    -- Функция заполнения массива. Ф-ция принмает аргумент
    -- iter, означающий шаг для угла синусоиды;
    -- то есть при х = 30 будет 12 точек в периоде синуса
    function sin_array(iter : integer) return SIN_ARR is
    variable x      	: integer := 0;
    variable arr		: SIN_ARR;
    variable j          : integer := 0;
    begin
        if even(LEN) then
            for i in 0 to (LEN / 2 - 1) loop
                arr(i)  := integer(round(SIN(MATH_DEG_TO_RAD * real(x)) * real(U_M_TB)));
                x       := x + iter;
            end loop;
    
            for i in (LEN / 2) to (LEN) loop
                arr(i)  :=  - arr(j);
                j       :=  j + 1;
            end loop;
        else
            for i in 0 to (LEN / 2) loop
                arr(i)  := integer(round(real(U_M_TB) * SIN(real(x) * MATH_DEG_TO_RAD)));
                x       := x + iter;
            end loop;
                
            for i in (LEN / 2 + 1) to (LEN ) loop
                arr(i)  :=  - arr(j);
                j       :=  j + 1;
            end loop;
        end if;            
        return arr;
    end function;

    constant S_ARR : SIN_ARR := sin_array(ANGLE);  -- сформерованный константный массив значений синуса ф-ции SIN_MATH_REAL

begin

    clk <= not clk after clk_period / 2;

    DUT : entity work.sin_mode(rtl)
    generic map(
        ANGLE   => ANGLE_TB,
        U_M     => U_M_TB
    )
    port map (
        clk => clk,
        rst => rst,
        tx_val_in => tx_val_in,
        data_out => data_out        
    );

    SEQUENCER_PROC : process
    begin

        rst <= '0';
        if data_out /= "UUUUUUUU" and i < LEN then

            test <= S_ARR(i);
            int_data_out <= to_integer(signed(data_out));

            if int_data_out = test then
                report "Angle = " & integer'image(integer(ANGLE) * i); -- угол
                report "Math_Sin = " & integer'image(int_data_out); -- значение синуса для угла, сформированное при помощи ряда тейлора
                report "Real_math = " & integer'image(test); -- значение синуса для угла, сформированное при помощи встроенной ф-ции SIN
                report "Okey";
            else
                report "Angle = " & integer'image(integer(ANGLE) * i); -- угол
                report "Math_Sin = " & integer'image(int_data_out); -- значение синуса для угла, сформированное при помощи ряда тейлора
                report "Real_math = " & integer'image(test); -- значение синуса для угла, сформированное при помощи встроенной ф-ции SIN
                report "Not Okey";
                err_cnt <= err_cnt + 1;
            end if;
            
            i <= i + 1;

            wait for clk_period * 1;
            tx_val_in <= '0';

            wait for clk_period * 1;
            tx_val_in <= '1';

        elsif i = LEN then
            report "Count of errors is " & integer'image(err_cnt);
            stop;
        else 
            wait for clk_period;
            tx_val_in <= '0';
            wait for clk_period;
            tx_val_in <= '1';
            i <= 0;
        end if;
    end process;

end architecture;