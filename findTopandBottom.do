#this sim tests ..

vlib work

vlog findTopandBottom.v ram36x3_1.v

vsim -L altera_mf_ver -L altera_mf test

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {starFound} 1 0ns, 0 {12 ns}

force {xIn} 011
force {yIn} 010

run 500 ns

