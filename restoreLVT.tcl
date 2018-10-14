proc restoreLVT {} {
	foreach_in_collection cell [get_cells] {
		set cell_ref [get_attribute $cell ref_name]
		set altname [list]
		if { [regexp {.*_LH.*} $cell_ref] } {
			lappend altname "CORE65LPLVT"
			lappend altname [regsub -all {_LH} $cell_ref {_LL}]
			set altname [join $altname "/"]
			size_cell $cell $altname
		}
	}
}