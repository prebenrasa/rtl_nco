--------------------------------------------------------------------------------
-- Package : nco_pkg
-- Purpose : Constants and functions for usage of the nco entity.
--
-- Contents
--   C_NCO_LATENCY       : clocks from the edge that samples clk_en = '1' to the
--                         edge after which sine_valid/sine_data hold that sample.
--   f_nco_step          : step_size for a carrier of cycles / samples cycles per
--                         sample (i.e. per clk_en), rounded down.
--   f_nco_step_is_exact : true when that step_size is an exact integer, so the
--                         carrier phase does not drift relative to the samples.
--   f_nco_config_ok     : true when the nco generics are legal; reports why not.
--   f_nco_quarter_wave  : LUT address offset of 90 degrees, 2**(addr_width - 2),
--                         added to the sine address to read the cosine.
--
-- Notes
--   - The step is computed in unsigned of width phase_width + 32, so any
--     phase_width works (integer arithmetic overflows above 2**31).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package nco_pkg is
    constant C_NCO_LATENCY : positive := 2; -- accumulator -> ROM read -> ROM output register

    function f_nco_step(constant cycles : positive; constant samples : positive; constant phase_width : positive) return unsigned;
    function f_nco_step_is_exact(constant cycles : positive; constant samples : positive; constant phase_width : positive) return boolean;
    function f_nco_config_ok(constant phase_width : positive; constant addr_width : positive; constant sample_width : positive) return boolean;
    function f_nco_quarter_wave(constant addr_width : positive) return unsigned;
end package;

package body nco_pkg is
    -- cycles * 2**phase_width, wide enough for any cycles < 2**31
    function f_step_numerator(constant cycles : positive; constant phase_width : positive) return unsigned is
    begin
        return shift_left(resize(to_unsigned(cycles, 32), phase_width + 32), phase_width);
    end function;

    function f_nco_step(constant cycles : positive; constant samples : positive; constant phase_width : positive) return unsigned is
    begin
        return resize(f_step_numerator(cycles, phase_width) / samples, phase_width);
    end function;

    function f_nco_step_is_exact(constant cycles : positive; constant samples : positive; constant phase_width : positive) return boolean is
    begin
        return f_step_numerator(cycles, phase_width) mod samples = 0;
    end function;

    function f_nco_config_ok(constant phase_width : positive; constant addr_width : positive; constant sample_width : positive) return boolean is
    begin
        if addr_width > phase_width then
            report "nco: GC_ADDR_WIDTH (" & integer'image(addr_width) & ") must be <= GC_PHASE_WIDTH (" &
                integer'image(phase_width) & ")" severity failure;
            return false;
        end if;
        if addr_width < 2 then
            report "nco: GC_ADDR_WIDTH (" & integer'image(addr_width) & ") must be >= 2 (a quarter wave needs 4 LUT entries)" severity failure;
            return false;
        end if;
        if sample_width < 2 then
            report "nco: GC_SAMPLE_WIDTH must be >= 2 (1 bit gives an all-zero sine)" severity failure;
            return false;
        end if;
        return true;
    end function;

    function f_nco_quarter_wave(constant addr_width : positive) return unsigned is
    begin
        return to_unsigned(2 ** (addr_width - 2), addr_width);
    end function;
end package body;
