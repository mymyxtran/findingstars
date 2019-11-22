#this sim tests ..



vlib work



vlog find_LeftandRight.v ram3600x3_sq.v



vsim -L altera_mf_ver -L altera_mf test



log -r {/*}



add wave {/*}



force {clk} 0 0ns, 1 {10ns} -r 20ns


force {TopandBottomFound} 1 0ns, 0 {12 ns}



force {mostTop} 010001
force {mostBottom} 101110


force {midPix} 100101
run 25000 ns

