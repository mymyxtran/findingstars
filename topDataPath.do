#this sim makes sure that the top-level FSM is finding white stars correctly

vlib work

vlog find_stars.v ram36x3_1.v

vsim -L altera_mf_ver -L altera_mf topDataPath

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {resetn} 0 0ns, 1 {12 ns}
force {countXEn} 0
force {countYEn} 0
force {wrEn} 0
force {pLoad} 0
force {xIn} 001
force {yIn} 100

run 30 ns

force {xCount} 101

run 50 ns

