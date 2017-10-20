################################################################
# Brigham Young University Video Filtering Base Design
# 
# part_gen.tcl
# Version 1.0
# Last Modified: February 24, 2017
################################################################

proc part_gen {str} {
	cd Source/$str
	if {[catch {source $str.tcl} fid]} {
		open_project ./$str/$str.xpr
	}
	synth_design -mode out_of_context -flatten_hierarchy rebuilt -top Video_Box -part xc7z020clg400-1
	cd ../..
	write_checkpoint Synth/$str.dcp -force
	close_project
	
	open_checkpoint Checkpoint/static_route_design.dcp

	read_checkpoint -cell system_i/video/Video_PR_0/U0/Video_PR_v1_0_S_AXI_inst/Video_Box_0 Synth/$str.dcp

	opt_design
	place_design
	route_design

	write_checkpoint -force Implement/$str.dcp
	
	pr_verify -initial Implement/pass_route_design.dcp -additional Implement/$str.dcp
	
	write_bitstream -file Bitstreams/$str.bit -force

	close_project

}

part_gen 3x3_kernel_filter
part_gen box_blur
part_gen Gscale
part_gen img_overlay_256color
part_gen img_overlay_duotone
part_gen Invert
part_gen Lines
part_gen mirror
part_gen motion_blur
part_gen ponq
part_gen rgb
part_gen sobel_filter
part_gen text



