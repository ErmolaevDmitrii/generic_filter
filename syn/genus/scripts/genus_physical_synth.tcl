set script_dir [file dirname [file normalize [info script]]]
if {[info exists ::env(GENUS_RUN_ROOT)]} {
    set package_root [file normalize $::env(GENUS_RUN_ROOT)]
} else {
    set package_root [file normalize [file join $script_dir ../..]]
}

if {[info exists ::env(GENUS_TOP)]} {
    set top_module $::env(GENUS_TOP)
} else {
    set top_module generic_fp_rd
}

if {[info exists ::env(GENUS_CLOCK_PERIOD_NS)]} {
    set clock_period_ns $::env(GENUS_CLOCK_PERIOD_NS)
} else {
    set clock_period_ns 10.0
}

if {[info exists ::env(GENUS_IO_DELAY_NS)]} {
    set io_delay_ns $::env(GENUS_IO_DELAY_NS)
} else {
    set io_delay_ns 1.0
}

set rtl_filelist [file join $package_root manifest fp_rd_tt_package_rtl.f]
set pdk_manifest [file join $package_root manifest fp_rd_tt_package_pdk_tt.tcl]

if {![file exists $rtl_filelist]} {
    error "RTL filelist not found: $rtl_filelist"
}
if {![file exists $pdk_manifest]} {
    error "PDK manifest not found: $pdk_manifest"
}

source $pdk_manifest

set report_dir [file join $package_root reports]
set output_dir [file join $package_root outputs]
set work_dir   [file join $package_root work]
file mkdir $report_dir
file mkdir $output_dir
file mkdir $work_dir

puts "GENUS_RUN_ROOT: $package_root"
puts "Top module:     $top_module"
puts "Corner:         $PDK_CORNER"
puts "RTL filelist:   $rtl_filelist"
puts "Clock period:   ${clock_period_ns} ns"
puts "IO delay:       ${io_delay_ns} ns"

set lib_search_path [list]
foreach lib $PDK_LIBERTY_FILES {
    lappend lib_search_path [file dirname $lib]
}
set_db init_lib_search_path [lsort -unique $lib_search_path]
set_db library $PDK_LIBERTY_FILES

if {[llength $PDK_LEF_FILES] > 0} {
    set_db lef_library $PDK_LEF_FILES
}

set rtl_fh [open $rtl_filelist r]
while {[gets $rtl_fh rtl_file] >= 0} {
    set rtl_file [string trim $rtl_file]
    if {$rtl_file eq ""} {
        continue
    }
    set full_rtl_file [file join $package_root $rtl_file]
    if {![file exists $full_rtl_file]} {
        error "RTL file not found: $full_rtl_file"
    }
    read_hdl -sv $full_rtl_file
}
close $rtl_fh

elaborate $top_module
init_design

set clk_ports [get_ports clk]
if {[sizeof_collection $clk_ports] == 0} {
    error "Clock port 'clk' not found in top module $top_module"
}

create_clock -name clk -period $clock_period_ns $clk_ports

set input_ports [remove_from_collection [all_inputs] $clk_ports]
if {[sizeof_collection $input_ports] > 0} {
    set_input_delay -clock [get_clocks clk] $io_delay_ns $input_ports
}

set output_ports [all_outputs]
if {[sizeof_collection $output_ports] > 0} {
    set_output_delay -clock [get_clocks clk] $io_delay_ns $output_ports
}

if {![catch {set rst_ports [get_ports rst_n]}] && [sizeof_collection $rst_ports] > 0} {
    set_false_path -from $rst_ports
}

check_design -unresolved > [file join $report_dir check_design_unresolved.rpt]

syn_generic
syn_map
syn_opt

report_area > [file join $report_dir area.rpt]
report_gates > [file join $report_dir gates.rpt]
report_power > [file join $report_dir power.rpt]
report_timing > [file join $report_dir timing.rpt]
report_timing -max_paths 10 -path_type full > [file join $report_dir timing_full.rpt]
report_timing -unconstrained > [file join $report_dir timing_unconstrained.rpt]
report_qor > [file join $report_dir qor.rpt]

write_hdl > [file join $output_dir ${top_module}_mapped.v]
write_sdc > [file join $output_dir ${top_module}.sdc]
write_sdf -nonegchecks -recrem split > [file join $output_dir ${top_module}.sdf]

puts "Genus physical-aware synthesis finished."
