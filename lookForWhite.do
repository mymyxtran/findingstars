#this sim makes sure that the top-level FSM is finding white stars correctly

vlib work

vlog master.v ram36x3_1.v

vsim -L altera_mf_ver -L altera_mf  master

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {resetn} 0 0ns, 1 {12 ns}
force {doneDraw} 0
force {doneClean} 0
force {topBottomFound} 0
force {leftFound} 0
force {rightFound} 0

run 2000 ns

