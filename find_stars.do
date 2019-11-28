
vlib work

vlog find_stars.v ram19200x3_2.v  draw_box.v clean_star.v master.v findTopandBottom.v find_LeftandRight.v vga_address_translator.v
vsim -L altera_mf_ver -L altera_mf find_stars_no_vga

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {resetn} 0 0ns, 1 {12 ns}

run 1500000 ns



