library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use work.sine_lut_pkg.all;

entity sine_lut_pkg_tb is
end entity sine_lut_pkg_tb;

architecture bhv of sine_lut_pkg_tb is
    constant GC_ADDR_BITS : positive := 4; -- M LUT address = top M bits of the phase
    constant GC_OUT_BITS  : positive := 8; -- L output amplitude width

    -- golden values for M = 4, L = 8: round(sin(2*pi*i/16) * 127) for the first quarter,
    -- written out by hand so they don't depend on the formula in the package
    constant C_GOLDEN_QUARTER : integer_vector := (0, 49, 90, 117, 127);
begin

    -- The package has no clock or ports, so one sequential process calls the function
    -- and checks its result. Each check is a property of a sampled sine, not a copy
    -- of the formula, so a bug in the package can't be repeated in the testbench.
    stimulus : process
        procedure check_lut(constant addr_bits : positive; constant out_bits : positive) is
            constant C_LUT       : t_sine_lut := f_sine_lut(out_bits => out_bits, addr_bits => addr_bits);
            constant C_DEPTH     : positive   := 2 ** addr_bits;
            constant C_AMPLITUDE : integer    := 2 ** (out_bits - 1) - 1;
            constant C_SIZE      : string     := " (M=" & to_string(addr_bits) & ", L=" & to_string(out_bits) & ")";
        begin
            -- shape of the table
            check_value(C_LUT'length, C_DEPTH, ERROR, "number of entries" & C_SIZE);
            check_value(C_LUT'low, 0, ERROR, "first address" & C_SIZE);
            check_value(C_LUT(0)'length, out_bits, ERROR, "entry width" & C_SIZE);

            -- the four quadrant points: 0, +peak, 0, -peak
            check_value(to_integer(C_LUT(0)), 0, ERROR, "sin(0)" & C_SIZE);
            check_value(to_integer(C_LUT(C_DEPTH / 4)), C_AMPLITUDE, ERROR, "sin(pi/2)" & C_SIZE);
            check_value(to_integer(C_LUT(C_DEPTH / 2)), 0, ERROR, "sin(pi)" & C_SIZE);
            check_value(to_integer(C_LUT(3 * C_DEPTH / 4)), -C_AMPLITUDE, ERROR, "sin(3pi/2)" & C_SIZE);

            for i in 1 to C_DEPTH - 1 loop
                -- odd symmetry: sin(2pi - x) = -sin(x)
                check_value(to_integer(C_LUT(i)), -to_integer(C_LUT(C_DEPTH - i)), ERROR,
                "odd symmetry at " & to_string(i) & C_SIZE);
                -- never above the peak, so +1.0 did not wrap to a negative value
                check_value_in_range(to_integer(C_LUT(i)), -C_AMPLITUDE, C_AMPLITUDE, ERROR,
                "range at " & to_string(i) & C_SIZE);
            end loop;

            -- first quarter never falls (neighbours can be equal when M > L)
            for i in 1 to C_DEPTH / 4 loop
                check_value(to_integer(C_LUT(i)) >= to_integer(C_LUT(i - 1)), ERROR,
                "rising first quarter at " & to_string(i) & C_SIZE);
            end loop;
        end procedure;

        constant C_LUT : t_sine_lut := f_sine_lut(out_bits => GC_OUT_BITS, addr_bits => GC_ADDR_BITS);
    begin
        set_log_file_name("sine_lut_pkg_tb_log.txt");
        set_alert_file_name("sine_lut_pkg_tb_alert.txt");
        set_alert_stop_limit(ERROR, 0); -- see every failure, not just the first
        disable_log_msg(ID_POS_ACK);    -- don't log every passing check

        log(ID_LOG_HDR, "Golden values, M=" & to_string(GC_ADDR_BITS) & " L=" & to_string(GC_OUT_BITS));
        for i in C_GOLDEN_QUARTER'range loop
            check_value(to_integer(C_LUT(i)), C_GOLDEN_QUARTER(i), ERROR, "golden entry " & to_string(i));
        end loop;

        log(ID_LOG_HDR, "Properties for several table sizes");
        check_lut(addr_bits => GC_ADDR_BITS, out_bits => GC_OUT_BITS);
        check_lut(addr_bits => 2, out_bits => 2);   -- smallest table with four quadrant points
        check_lut(addr_bits => 6, out_bits => 4);   -- more entries than amplitude levels
        check_lut(addr_bits => 10, out_bits => 12); -- the nco defaults

        report_alert_counters(FINAL); -- prints "Simulation SUCCESS" or "Simulation FAILED"
        std.env.stop;
        wait;
    end process;
end architecture;
