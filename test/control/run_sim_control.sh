#! /bin/bash -f
sim_name="control"

# 1. Clean
rm -f *.vvp *.vcd

# 2. Compile
iverilog -g2012 -Wall -o $sim_name.vvp -f $sim_name.f

# 3. Run
vvp $sim_name.vvp

# # 4. View Waveform
# gtkwave tb_$sim_name.vcd &
