package require proj
package require las

proc usage {} {
    puts stderr "Usage: lasproj ?options?\
            \n\t-help                   # print out this message\
            \n\t-i <file or wildcard>   # input file(s) (required)\
            \n\t-o <file>               # output file (only if one input file)\
            \n\t-odir <dir>             # output directory (must exist)\
            \n\t-odix <suffix>          # output file suffix\
            \n\t-olas                   # output .las files\
            \n\t-olaz                   # output .laz files\
            \n\t-proj <string>          # transform using custom proj string\
            \n\t-gda20                  # from gda94 to gda2020 using distortion grid\
            \n\t-ahd09                  # from eht to ausgeoid09 using gtx grid\
            \n\t-ahd20                  # from eht to ausgeoid2020 using gtx grid\
            \n\t-zone <num>             # utm zone number (required for grid transforms)\
            \n\t-hmt <name>             # name of terramodel helmert file\
            \n\t-inv                    # reverse direction of transform\
            \n\t"
    exit 1
}

proc main {} {
    global argc argv
    if {!$argc} usage
    while {[llength $argv]} {
        set opt [lindex $argv 0]
        if {![string match "-*" $opt]} break

        if {[string equal $opt "-help"]} {
            usage
        } elseif {[string equal $opt "-i"]} {
	    if {[llength $argv] < 2} usage
            set input  [lindex $argv 1]
            set argv [lrange $argv 2 end]
        } elseif {[string equal $opt "-o"]} {
	    if {[llength $argv] < 2} usage
            set output  [lindex $argv 1]
            set argv [lrange $argv 2 end]
        } elseif {[string equal $opt "-odir"]} {
	    if {[llength $argv] < 2} usage
            set odir  [lindex $argv 1]
            set argv [lrange $argv 2 end]
        } elseif {[string equal $opt "-odix"]} {
	    if {[llength $argv] < 2} usage
            set suffix  [lindex $argv 1]
            set argv [lrange $argv 2 end]
        } elseif {[string equal $opt "-olas"]} {
            set otype .las
            set argv [lrange $argv 1 end]
        } elseif {[string equal $opt "-olaz"]} {
            set otype .laz
            set argv [lrange $argv 1 end]
        } elseif {[string equal $opt "-proj"]} {
	    if {[llength $argv] < 2} usage
            set projtype proj
            set projstr  [lindex $argv 1]
            set argv [lrange $argv 2 end]
        } elseif {[string equal $opt "-gda20"]} {
            set projtype gda20
            set argv [lrange $argv 1 end]
        } elseif {[string equal $opt "-ahd09"]} {
            set projtype ahd09
            set argv [lrange $argv 1 end]
        } elseif {[string equal $opt "-ahd20"]} {
            set projtype ahd20
            set argv [lrange $argv 1 end]
        } elseif {[string equal $opt "-zone"]} {
	    if {[llength $argv] < 2} usage
            set zone  [lindex $argv 1]
            set argv [lrange $argv 2 end]
        } elseif {[string equal $opt "-hmt"]} {
	    if {[llength $argv] < 2} usage
            set projtype hmt
            set hmtfile  [lindex $argv 1]
            set argv [lrange $argv 2 end]
        } elseif {[string equal $opt "-inv"]} {
            set inv on
            set argv [lrange $argv 1 end]
        } else {
            puts "\nno option $opt!\n"
            usage
        }
    }
    if {[llength $argv]} {
        puts "garbage input $argv"
        usage
    }
    if {![info exists input]} {
        puts "\nno input file!\n"
        usage
    }
    set files [glob -nocomplain -type f $input]
    if {![llength $files]} {
        puts "\nno files match $input!\n"
        usage
    }
    if {[llength $files] > 1 && [info exists output]} {
        puts "\ncan't specify output file with multiple inputs!\n"
        usage
    }
    foreach f $files {
        set ext [file extension $f]
        if {!($ext eq ".las" || $ext eq ".laz")} {
            puts "\ncan't process $ext files!\n"
            usage
        }
    }
    if {[info exists odir]} {
        if {![file exists $odir]} {
            puts "\nno directory $odir!\n"
            usage
        }
    } else {
        set odir .
    }
    if {![info exists suffix]} {
        if {$odir eq "."} {
            set suffix _1
        } else {
            set suffix ""
        }
    }
   if {![info exists projtype]} {
        puts "\nno transformation!\n"
        usage
    }
    if {$projtype ne "hmt"} {
        if {![info exists zone]} {
            puts "\nneed to provide zone for $projtype\n"
            usage
        }
    }
    if {$projtype eq "ahd09"} {
        set S "+proj=pipeline  +zone=$zone +south +ellps=GRS80"
        append S " +step +inv +proj=utm"
        append S " +step +proj=vgridshift +grids=ausgeoid09.gtx"
        append S " +step +proj=utm"
        set P [proj create $S]
    }
    if {$projtype eq "ahd20"} {
        set S "+proj=pipeline  +zone=$zone +south +ellps=GRS80"
        append S " +step +inv +proj=utm"
        append S " +step +proj=vgridshift +grids=ausgeoid2020.gtx"
        append S " +step +proj=utm"
        set P [proj create $S]
    }
    if {$projtype eq "gda20"} {
        set S "+proj=pipeline  +zone=$zone +south +ellps=GRS80"
        append S " +step +inv +proj=utm"
        append S " +step +proj=hgridshift +grids=GDA94_GDA2020_conformal.gsb"
        append S " +step +proj=utm"
        set P [proj create $S]
    }
    if {$projtype eq "proj"} {
        set S $projstr
        set P [proj create $S]
    }
    if {$projtype eq "hmt"} {
        if {![file exists $hmtfile]} {
            puts "\ncannot find $hmtfile\n"
            usage
        }
        set hmt [open $hmtfile r]
        gets $hmt line
        close $hmt
        lassign [split $line ,] a b X0 Y0 x0 y0
        set x [expr {$x0-$a*$X0+$b*$Y0}]
        set y [expr {$y0-$b*$X0-$a*$Y0}]
        set s [expr {hypot($a,$b)}]
        set rad2sec [expr {3600*45/atan(1)}]
        set theta [expr {-$rad2sec*atan2($b,$a)}]
        set S +proj=helmert
        append S " +convention=coordinate_frame"
        append S " +x=$x +y=$y"
        append S " +s=$s +theta=$theta"
        set P [proj create $S]
    }
    if {[info exists inv]} {
        set dirn inv
    } else {
        set dirn fwd
    }

    puts "\n$S\n"

    if {[info exists output]} {
        set command "las $dirn $P $input $output"
        puts $command
        eval $command
    } else {
        foreach infile $files {
            if {![info exists otype]} {
                set otype [file ext $infile]
            }
            set outfile [file join $odir "[file root $infile]$suffix$otype"]
            set command "las $dirn $P $infile $outfile"
            puts $command
            eval $command
        }
    }
}

main

# vim: set sts=4 sw=4 tw=80 et ft=tcl:
