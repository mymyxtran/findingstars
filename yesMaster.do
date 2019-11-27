#this sim makes sure that the top-level FSM is finding white stars correctly

vlib work

vlog master.v ram36x3_1.v clean_star.v

vsim -L altera_mf_ver -L altera_mf  master

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {GO} 1 0ns, 0 {12 ns}
force {resetn} 0 0ns, 1 {13ns}
force {doneDraw} 0
force {doneClean} 0
force {topBottomFound} 0
force {leftFound} 0
force {rightFound} 0
force {xLeft} 001
force {xRight} 100
force {yTop} 011
force {yBottom} 101

run 2000 ns

force {goClean} 1 0ns, 0 {12 ns}

run 500 ns

