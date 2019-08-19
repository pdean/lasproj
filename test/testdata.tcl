package require proj

set S "+proj=pipeline  +zone=56 +south +ellps=GRS80"
append S " +step +inv +proj=utm"
append S " +step +proj=vgridshift +grids=ausgeoid09.gtx"
append S " +step +proj=utm"
puts $S
set P [proj create $S] 

set emin 500000
set emax 504000
set nmin 6964000
set nmax 6968000

set ahd [open ahd.txt w]
set eht [open eht.txt w]

for {set i $emin} {$i <= $emax} {incr i 100} {
    for {set j $nmin} {$j <= $nmax} {incr j 100} {
	puts $ahd [format "%.3f %.3f %.3f" \
	    $i $j 0]
	puts $eht [format "%.3f %.3f %.3f" \
	       	{*}[proj inv $P [list $i $j 0]]]
    }
}

# vim: ft=tcl sw=4  

