vlib work

vlog clean_star.v

vsim clean_star

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {resetn} 0 0ns, 1 {12 ns}
force {xLeft} 001
force {xRight} 100
force {yTop} 011
force {yBottom} 101
force {goClean} 1

run 1000 ns


