#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 45nm                               */
#/**************************************************/
# [MOD] Copy of the provided compile_with_sram.tcl. Every edited line is
# [MOD] tagged with "[MOD]". Run from a fresh directory (see synth/Makefile).
# [MOD] PIPELINED design with imem/dmem mapped to the SRAM macro.

#/* All verilog files, separated by spaces         */
set my_verilog_files [list ../top_with_sram.sv ../../controller.sv ../../datapath.sv]   ;# [MOD]

#/* Top-level Module                               */
set my_toplevel   top                   ;# [MOD]

#/* The name of the clock pin. If no clock-pin     */
#/* exists, pick anything                          */
set my_clock_pin clk

#/* Target frequency in MHz for optimization       */
set my_clk_freq_MHz 1000

#/* Delay of input signals (Clock-to-Q, Package etc.)  */
set my_input_delay_ns 0.1

#/* Reserved time for output signals (Holdtime etc.)   */
set my_output_delay_ns 0.1


#/**************************************************/
#/* No modifications needed below                  */
#/**************************************************/

set SRAM_DIR   "/usr/local2/COURSES/ADDV/LAB2/sram_32x64/"
set SRAM_FILES [list SRAM_32x64_1rw.db]

set OSU_FREEPDK [format "%s%s"  [getenv "PDK_DIR"] "/osu_soc/lib/files"]

set search_path [concat  $search_path $OSU_FREEPDK $SRAM_DIR]
set alib_library_analysis_path $OSU_FREEPDK

set target_library [list gscl45nm.db dw_foundation.sldb]

set link_library [concat "*" $target_library $SRAM_FILES]

define_design_lib WORK -path ./WORK
set verilogout_show_unconnected_pins "true"
set_ultra_optimization true
set_ultra_optimization -force

analyze -format sverilog $my_verilog_files   ;# [MOD] was: analyze -f verilog (handout: use sverilog)

elaborate $my_toplevel

current_design $my_toplevel

link
uniquify

# [MOD] handout: keep imem / dmem from being optimized away
set_dont_touch [get_cells "imem"]
set_dont_touch [get_cells "dmem"]

set my_period [expr 1000 / $my_clk_freq_MHz]

set find_clock [ find port [list $my_clock_pin] ]
if {  $find_clock != [list] } {
   set clk_name $my_clock_pin
   create_clock -period $my_period $clk_name
} else {
   set clk_name vclk
   create_clock -period $my_period -name $clk_name
}

set_driving_cell  -lib_cell INVX1  [all_inputs]
set_input_delay $my_input_delay_ns -clock $clk_name [remove_from_collection [all_inputs] $my_clock_pin]
set_output_delay $my_output_delay_ns -clock $clk_name [all_outputs]

compile -map_effort medium

compile -incremental_mapping -map_effort medium

check_design
report_constraint -all_violators

#set filename [format "%s%s"  $my_toplevel ".vh"]
#write -f verilog -output $filename

#set filename [format "%s%s"  $my_toplevel ".sdc"]
#write_sdc $filename

#set filename [format "%s%s"  $my_toplevel ".db"]
#write -f db -hier -output $filename -xg_force_db

redirect timing.rep { report_timing }
redirect cell.rep { report_cell }
redirect power.rep { report_power }
redirect area.rep { report_area }
redirect area_hier.rep { report_area -hierarchy }   ;# [MOD] area per block (imem/dmem/mips)
redirect qor.rep { report_qor }                     ;# [MOD] summary: critical path length, slack, area

quit
