vlib work

vlog draw_box.v

vsim draw_box

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {goDraw} 1 0ns, 0 {12 ns}
force {xLeft} 001
force {xRight} 100
force {yTop} 011
force {yBottom} 101

run 1000 ns


