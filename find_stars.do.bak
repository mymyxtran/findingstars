#this sim makes sure that the top-level FSM is finding white stars correctly

vlib work

vlog find_stars.v ram36x3_1.v

vsim -L altera_mf_ver -L altera_mf state_machine1

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {resetn} 0 0ns, 1 {12 ns}
force {starFound} 0
force {endOfImg} 0
force {doneStarMap} 0
force {xMax} 0  0 ns, 1 {75 ns}
force {doneDraw} 0

run 100 ns

force {xMax} 0

run 20 ns


