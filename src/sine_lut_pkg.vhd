library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package sine_lut_pkg is
    type t_sine_lut is array (natural range <>) of signed;

    function f_sine_lut(constant addr_width : positive; constant sample_width : positive) return t_sine_lut;
end package;

package body sine_lut_pkg is
    function f_sine_lut(constant addr_width : positive; constant sample_width : positive) return t_sine_lut is
        constant C_LUT_DEPTH : positive := 2 ** addr_width;
        constant C_AMPLITUDE : real     := real(2 ** (sample_width - 1) - 1);
        variable v_lut       : t_sine_lut(0 to C_LUT_DEPTH - 1)(sample_width - 1 downto 0);
        variable v_sample    : real;
    begin
        for i in v_lut'range loop
            v_sample := sin(MATH_2_PI * real(i) / real(C_LUT_DEPTH));
            v_lut(i) := to_signed(integer(round(v_sample * C_AMPLITUDE)), sample_width);
        end loop;
        return v_lut;
    end function;
end package body;
