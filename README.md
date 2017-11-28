# BYU_Senior_PYNQ_Project
## What is this?
This Senior project was to use the new development board, the PYNQ, produced by Digilent and Xilinx.
The project was to explore using partial reconfiguration to quickly change video hardware filters.
The PYNQ uses Ubuntu with an iPython notebook interface. 
The project was able to use the Python interface to change partial configurations and dynamically edit values in the filters through processor read and write commands.

## Release to Demo
An SD card image is available called proj.tar.xz for the 1.3 release
https://github.com/byuccl/BYU_Senior_PYNQ_Project/releases/tag/1.3

Extract the image from the tar file.
Then write it to a SD card.

You can use tools such as gparted to increase the parition to use the whole SD card.

Follow PYNQ docs to log in to the device.
http://pynq.readthedocs.io/en/latest/getting_started.html

If you go to the Video_PR folder, there are demos already created for you.
All the demos but the "Demo ALL!" include details about each filter and how it works.
If it can be dynamically changed this is included in the GUI.
The "Demo ALL!" provides an example of how quickly you can change between partial designs.


## Build and add to
dependencies:
* Vivado 2016.3 (WebPack License)
* +License for PartialReconfiguration
* The Pynq Board files must be copied over to to ../Vivado/data/boards/board_files

2017 BYU Senior ECEN PYNQ Video Project

* run /Pynq-Z1/bitstream/base.tcl from /Pynq-Z1/vivado/base/ (~2 hours)
* run /Pynq-Z1/vivado/Partial_Designs/build_static_design.tcl from /Pynq-Z1/vivado/Partial_Designs/ (~ 1 hour)
* run /Pynq-Z1/vivado/Partial_Designs/part_proj_gen.tcl from /Pynq-Z1/vivado/Partial_Designs/ (~4 hours)

The bitstreams are located in /Pynq-Z1/vivado/Partial_Designs/Bitstreams.
There is a full bitstream and a partial bitstream for each design.

* There is a shortcut, "pynq", on the pynq home folder to go to /usr/local/lib/python3.4/dist-packages/pynq/
* Move bitstreams into pynq/bitstream/ on the pynq
* Move /Pynq-Z1/Python into pynq/ on the pynq
* Move /Pynq-Z1/notebooks/Video_PR into ~/jupyter_notebooks/ on the pynq
