#this sim tests ..



vlib work



vlog find_LeftandRight.v ram36x3_1.v



vsim -L altera_mf_ver -L altera_mf test



log -r {/*}



add wave {/*}



force {clk} 0 0ns, 1 {10ns} -r 20ns


force {TopandBottomFound} 1 0ns, 0 {12 ns}



force {mostTop} 010


force {mostBottom} 110


force {midPix} 011



run 500 ns

