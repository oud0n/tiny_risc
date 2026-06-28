
from siliconcompiler import ASIC, Design
from siliconcompiler.targets import skywater130_demo

file_list = [
    "../src/regfile.sv",
]

design = Design("tiny_risc")
design.set_topmodule("tiny_risc", fileset='rtl')

design.add_idir("../src", fileset="rtl")

for file in file_list:
    design.add_file(file, fileset="rtl")

design.add_file("tiny_risc.sdc", fileset="sdc")

project = ASIC(design)
project.add_fileset(["rtl", "sdc"])

skywater130_demo(project)

# project.set("tool", "yosys", "task", "syn_asic", "script", "dft_setup.tcl")

project.run()
project.summary()
