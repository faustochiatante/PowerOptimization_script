proc dualVthv1 {args} {
	set time_start [clock clicks -milliseconds]
	parse_proc_arguments -args $args results
	set savings $results(-savings)


	set cdesign [get_design]
	set initial_leakPow [get_attribute $cdesign leakage_power]
	set curr_leakPow $initial_leakPow
	set final_leakPow [expr  $initial_leakPow - $savings * $initial_leakPow]

	if { $savings==1 } then {
		foreach_in_collection cell [get_cells] {
			set altname [list]
			lappend altname "CORE65LPHVT"
			lappend altname [regsub -all {_LL} [get_attribute $cell ref_name] {_LH}]
			set altname [join $altname "/"]
			size_cell $cell $altname
		}
		set curr_leakPow [get_attribute -quiet $cdesign leakage_power]

	} elseif { $savings!=0 } then {
		set LLcells [get_cells -filter "ref_name =~ HS65_LL*"]
		set LLoutpins [get_pins -of_objects $LLcells -filter "direction == out"]
		set sortedpins [sort_collection $LLoutpins -descending max_slack]

		foreach_in_collection cell $LLcells {
			set init_cell_leak([get_attribute $cell full_name]) [get_attribute $cell leakage_power]
		}

		foreach_in_collection cell [get_cells] {
			set altname [list]
			lappend altname "CORE65LPHVT"
			lappend altname [regsub -all {_LL} [get_attribute $cell ref_name] {_LH}]
			set altname [join $altname "/"]
			size_cell $cell $altname
			
		} 

		foreach_in_collection cell $LLcells {
				set final_cell_leak([get_attribute $cell full_name]) [get_attribute $cell leakage_power]
			}

		foreach_in_collection cell [get_cells] {
			set altname [list]
			lappend altname "CORE65LPLVT"
			lappend altname [regsub -all {_LH} [get_attribute $cell ref_name] {_LL}]
			set altname [join $altname "/"]
			size_cell $cell $altname
		}



		while { ($curr_leakPow > $final_leakPow) && ([sizeof_collection $LLcells]!=0) } {
			
			#while { () && ($curr_leakPow >= $final_leakPow) } {
				
				set pin [index_collection $sortedpins 0]
				set cell [get_attribute $pin cell]
				set full_name [get_attribute $cell full_name]
				set leak_cell_old $init_cell_leak($full_name)
				set altname [list]
				lappend altname "CORE65LPHVT"
				lappend altname [regsub -all {_LL} [get_attribute $cell ref_name] {_LH}]
				set altname [join $altname "/"]
				size_cell $cell $altname
				set leak_cell_new $final_cell_leak($full_name)
			#}

			#set curr_leakPow [get_attribute -quiet $cdesign leakage_power]
			set curr_leakPow [expr $curr_leakPow-$leak_cell_old+$leak_cell_new]
			set LLoutpins [remove_from_collection $LLoutpins $pin]
			set sortedpins [sort_collection $LLoutpins -descending max_slack]
		}
	} else {
		set curr_leakPow $initial_leakPow
	}
	
	puts "initial power: $initial_leakPow"
	puts "final wanted power: $final_leakPow"
	puts "current power: $curr_leakPow"
	#puts [expr $initial_leakPow-$curr_leakPow]
	set time_taken [expr ([clock clicks -milliseconds] - $time_start)/1000.0]
	puts "time: $time_taken s"

	set curr_leakPow_true [expr $final_leakPow-[get_attribute -quiet $cdesign leakage_power]]
	puts "precision leak: $curr_leakPow_true"
	report_threshold_voltage_group
	report_timing
	return
}

define_proc_attributes dualVthv1 \
-info "Post-Synthesis Dual-Vth cell assignment" \
-define_args \
{
	{-savings "minimum % of leakage savings in range [0, 1]" lvt float required}
}
