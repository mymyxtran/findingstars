#this sim tests ..

vlib work

vlog findTopandBottom.v ram3600x3_sq.v

vsim -L altera_mf_ver -L altera_mf test

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {starFound} 1 0ns, 0 {12 ns}

force {xIn} 11000 
force {yIn} 10001

run 2000 ns

