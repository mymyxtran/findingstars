#this sim makes sure that the top-level FSM is finding white stars correctly

vlib work

vlog find_stars.v ram19200x3_c.v  draw_box.v clean_star.v master.v findTopandBottom.v find_LeftandRight.v vga_adapter.v vga_address_translator.v vga_controller.v vga_pll.v

vsim -L altera_mf_ver -L altera_mf find_stars

log -r {/*}

add wave {/*}

force {clk} 0 0ns, 1 {10ns} -r 20ns
force {resetn} 0 0ns, 1 {12 ns}

run 100 ns



