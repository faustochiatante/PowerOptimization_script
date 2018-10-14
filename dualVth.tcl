proc dualVth {args} {
	set time_start [clock clicks -milliseconds]
	parse_proc_arguments -args $args results
	set savings $results(-savings)

	#calculate initial parameters
	set cdesign [get_design]
	set initial_leakPow [get_attribute $cdesign leakage_power]
	set curr_leakPow $initial_leakPow
	set final_leakPow [expr  $initial_leakPow - $savings * $initial_leakPow]

	#if savings=1 change all the cells
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
		#find out pins ordered per slack
		set LLcells [get_cells -filter "ref_name =~ HS65_LL*"]
		set numbof_cells [sizeof_collection $LLcells]
		set LLoutpins [get_pins -of_objects $LLcells -filter "direction == out"]
		set sortedpins [sort_collection $LLoutpins -descending max_slack]

		#save leakage for every LVT cell in the design
		foreach_in_collection cell $LLcells {
			set init_cell_leak([get_attribute $cell full_name]) [get_attribute $cell leakage_power]
		}
		
		#substitute design cells with HVT 
		foreach_in_collection cell [get_cells] {
			set altname [list]
			lappend altname "CORE65LPHVT"
			lappend altname [regsub -all {_LL} [get_attribute $cell ref_name] {_LH}]
			set altname [join $altname "/"]
			size_cell $cell $altname
			
		} 

		#save leakage for every HVT cell in the design
		foreach_in_collection cell $LLcells {
				set final_cell_leak([get_attribute $cell full_name]) [get_attribute $cell leakage_power]
		}

		#restore LVT
		foreach_in_collection cell [get_cells] {
			set altname [list]
			lappend altname "CORE65LPLVT"
			lappend altname [regsub -all {_LH} [get_attribute $cell ref_name] {_LL}]
			set altname [join $altname "/"]
			size_cell $cell $altname
		}

		set area_factor [expr $numbof_cells/200]
		if { $area_factor < 1 } { set area_factor 1 }
		#run the algorithm of substitution
		while { ($curr_leakPow > $final_leakPow) && ([sizeof_collection $sortedpins]!=0) } {
			set step [expr $area_factor * 15]
			set diff [expr $curr_leakPow-$final_leakPow]
			#puts $diff
			if { $diff < 5e-07 } {set step [expr $area_factor * 10] }
			if { $diff < 1.2e-07 } {set step [expr $area_factor * 5] }
			if { $diff < 6e-08 } { set step [expr $area_factor * 1] }
			if { $diff < 1e-08 } { set step 1 }
			while { ($step>0) && ($curr_leakPow > $final_leakPow) } {
				incr step -1
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
				set curr_leakPow [expr $curr_leakPow-$leak_cell_old+$leak_cell_new]
				set sortedpins [remove_from_collection $sortedpins $pin]
			}
			if { ($curr_leakPow > $final_leakPow) } {
				set sortedpins [sort_collection $sortedpins -descending max_slack]
			}
		}
	} else {
		#if savings=0 nothing to do
		set curr_leakPow $initial_leakPow
	}

	#puts "initial power: $initial_leakPow"
	#puts "final wanted power: $final_leakPow"
	#puts "current power: $curr_leakPow"
	#puts [expr $initial_leakPow-$curr_leakPow]

	set time_taken [expr ([clock clicks -milliseconds] - $time_start)/1000.0]
	puts "time: $time_taken s"
	#set curr_leakPow_true [expr $final_leakPow-[get_attribute -quiet $cdesign leakage_power]]
	#puts "precision leak: $curr_leakPow_true"
	#report_threshold_voltage_group
	#report_timing
	return
}

define_proc_attributes dualVth \
-info "Post-Synthesis Dual-Vth cell assignment" \
-define_args \
{
	{-savings "minimum % of leakage savings in range [0, 1]" lvt float required}
}
