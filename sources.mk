# Source lists of the NCO, for any Makefile that includes this file (this repo or a parent project).
# Paths are absolute, so they work from whichever folder the includer runs in.
#   RTL_NCO_SRC   synthesisable sources, in compile order (packages first)
#   RTL_NCO_TB    testbenches and simulation-only packages

RTL_NCO_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

RTL_NCO_SRC := $(RTL_NCO_DIR)/src/sine_lut_pkg.vhd \
               $(RTL_NCO_DIR)/src/nco_pkg.vhd \
               $(RTL_NCO_DIR)/src/nco.vhd

RTL_NCO_TB  := $(wildcard $(RTL_NCO_DIR)/tb/*.vhd)
