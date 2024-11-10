vlib work
vlog -cover bsc Divisor_Algoritmico.sv Top_divisor.sv
vsim -coverage Top_divisor
run -all
# coverage save -onexit coverage.ucdb