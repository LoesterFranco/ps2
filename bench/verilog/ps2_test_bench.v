//////////////////////////////////////////////////////////////////////
////                                                              ////
////  ps2_test_bench.v                                            ////
////                                                              ////
////  This file is part of the "ps2" project                      ////
////  http://www.opencores.org/cores/ps2/                         ////
////                                                              ////
////  Author(s):                                                  ////
////      - mihad@opencores.org                                   ////
////      - Miha Dolenc                                           ////
////                                                              ////
////  All additional information is avaliable in the README.txt   ////
////  file.                                                       ////
////                                                              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 Miha Dolenc, mihad@opencores.org          ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.2  2002/02/18 18:08:31  mihad
// One bug fixed
//
// Revision 1.1.1.1  2002/02/18 16:16:55  mihad
// Initial project import - working
//
//

`include "timescale.v"
`include "ps2_testbench_defines.v"
`include "ps2_defines.v"

`define KBD_STATUS_REG      32'h64
`define KBD_CNTL_REG        32'h64
`define KBD_DATA_REG        32'h60
/*
 * controller commands
 */
`define KBD_READ_MODE       32'h20
`define KBD_WRITE_MODE      32'h60
`define KBD_SELF_TEST       32'hAA
`define KBD_SELF_TEST2      32'hAB
`define KBD_CNTL_ENABLE     32'hAE
/*
 * keyboard commands
 */
`define KBD_ENABLE          32'hF4
`define KBD_DISABLE         32'hF5
`define KBD_RESET           32'hFF
/*
 * keyboard replies
 */
`define KBD_ACK             32'hFA
`define KBD_POR             32'hAA
/*
 * status register bits
 */
`define KBD_OBF             32'h01
`define KBD_IBF             32'h02
`define KBD_GTO             32'h40
`define KBD_PERR            32'h80
/*
 * keyboard controller mode register bits
 */
`define KBD_EKI             32'h01
`define KBD_SYS             32'h04
`define KBD_DMS             32'h20
`define KBD_KCC             32'h40
`define KBD_DISABLE_COMMAND 32'h10

module ps2_test_bench() ;

parameter [31:0] MAX_SEQUENCE_LENGTH = 10 ;
wire kbd_clk_cable  ;
wire kbd_data_cable ;

pullup(kbd_clk_cable)  ;
pullup(kbd_data_cable) ;

reg wb_clock ;
reg wb_reset ;

wire [7:0] received_char ;
wire       char_valid ;

`ifdef XILINX
    assign glbl.GSR = wb_reset ;
`endif
ps2_keyboard_model i_ps2_keyboard_model
(
    .kbd_clk_io  (kbd_clk_cable),
    .kbd_data_io (kbd_data_cable),
    .last_char_received_o (received_char),
    .char_valid_o (char_valid)
) ;

reg ok ;
reg error ;

integer watchdog_timer ;
reg     watchdog_reset ;
reg     watchdog_reset_previous ;

reg [7:0] normal_scancode_set2_mem [0:`PS2_NUM_OF_NORMAL_SCANCODES - 1] ;
reg [7:0] normal_scancode_set1_mem [0:`PS2_NUM_OF_NORMAL_SCANCODES - 1] ;
reg [7:0] extended_scancode_set2_mem [0:`PS2_NUM_OF_EXTENDED_SCANCODES - 1] ;
reg [7:0] extended_scancode_set1_mem [0:`PS2_NUM_OF_EXTENDED_SCANCODES - 1] ;

`define WB_PERIOD (1/`WB_FREQ)
initial
begin

    $readmemh("../../../bench/data/normal_scancodes_set2.hex", normal_scancode_set2_mem) ;
    $readmemh("../../../bench/data/normal_scancodes_set1.hex", normal_scancode_set1_mem) ;
    $readmemh("../../../bench/data/extended_scancodes_set2.hex", extended_scancode_set2_mem) ;
    $readmemh("../../../bench/data/extended_scancodes_set1.hex", extended_scancode_set1_mem) ;

    if ( ((`PS2_TIMER_5USEC_VALUE_PP * `WB_PERIOD) < 5000) || ((`PS2_TIMER_5USEC_VALUE_PP * `WB_PERIOD) > 6000) )
    begin
        $display("Warning! 5us timer max value is not defined correctly regarding to WISHBONE bus clock!") ;
        $stop ;
    end

    if ( ((`PS2_TIMER_60USEC_VALUE_PP * `WB_PERIOD) < 60000) || ((`PS2_TIMER_60USEC_VALUE_PP * `WB_PERIOD) > 61000) )
    begin
        $display("Warning! 60us timer max value is not defined correctly regarding to WISHBONE bus clock!") ;
        $stop ;
    end

    if ( (1 << `PS2_TIMER_5USEC_BITS_PP) < `PS2_TIMER_5USEC_VALUE_PP )
    begin
        $display("Warning! 5us timer max value is not defined correctly regarding to the length in bits of 5us timer!") ;
        $stop ;
    end

    if ( (1 << `PS2_TIMER_60USEC_BITS_PP) < `PS2_TIMER_60USEC_VALUE_PP )
    begin
        $display("Warning! 60us timer max value is not defined correctly regarding to the length in bits of 60us timer!") ;
        $stop ;
    end

    watchdog_timer = 32'h1000_0000 ;
    watchdog_reset = 0 ;
    watchdog_reset_previous = 0 ;

    wb_clock = 1'b1 ;
    wb_reset = 1'b1 ;

    #100 ;

    repeat ( 10 )
        @(posedge wb_clock) ;
    wb_reset <= 1'b0 ;

    @(posedge wb_clock) ;
    #1 initialize_controler ;

    test_scan_code_receiving ;

    test_normal_scancodes ;
  
    test_extended_scancodes ;

    test_print_screen_and_pause_scancodes ;

    test_keyboard_inhibit ;

    #400 $stop ;
end

always
    #(`WB_PERIOD / 2) wb_clock = !wb_clock ;

wire wb_cyc,
     wb_stb,
     wb_we,
     wb_ack,
     wb_rty,
     wb_int ;

wire [3:0] wb_sel ;

wire [31:0] wb_adr, wb_dat_m_s, wb_dat_s_m ;
     
ps2_sim_top 
i_ps2_top
(
    .wb_clk_i        (wb_clock),
    .wb_rst_i        (wb_reset),
    .wb_cyc_i        (wb_cyc),
    .wb_stb_i        (wb_stb),
    .wb_we_i         (wb_we),
    .wb_sel_i        (wb_sel),
    .wb_adr_i        (wb_adr),
    .wb_dat_i        (wb_dat_m_s),
    .wb_dat_o        (wb_dat_s_m),
    .wb_ack_o        (wb_ack),
 
    .wb_int_o        (wb_int),
 
    .ps2_kbd_clk_io  (kbd_clk_cable),
    .ps2_kbd_data_io (kbd_data_cable)
) ;

WB_MASTER_BEHAVIORAL i_wb_master
(
    .CLK_I    (wb_clock),
    .RST_I    (wb_reset),
    .TAG_I    (1'b0),
    .TAG_O    (),
    .ACK_I    (wb_ack),
    .ADR_O    (wb_adr),
    .CYC_O    (wb_cyc),
    .DAT_I    (wb_dat_s_m),
    .DAT_O    (wb_dat_m_s),
    .ERR_I    (1'b0),
    .RTY_I    (1'b0),
    .SEL_O    (wb_sel),
    .STB_O    (wb_stb),
    .WE_O     (wb_we),
    .CAB_O    ()
);

always@(posedge wb_clock)
begin
    if ( watchdog_timer === 0 )
    begin
        $display("Warning! Simulation watchdog timer has expired!") ;
        watchdog_timer = 32'hFFFF_FFFF ;
    end 
    else if ( watchdog_reset !== watchdog_reset_previous )
        watchdog_timer = 32'hFFFF_FFFF ;

    watchdog_reset_previous = watchdog_reset ;
    
end

task initialize_controler ;
    reg [7:0] data ;
    reg status ;
begin:main
    
    // simulate keyboard driver's behaviour 
    read_status_reg(data, status) ;
    if ( status !== 1 )
        disable main ;

    if ( data & `KBD_OBF )
        read_data_reg(data, status) ;

    if ( status !== 1 )
        disable main ;

    kbd_write(`KBD_CNTL_REG, `KBD_SELF_TEST, status) ;

    if ( status !== 1 )
        disable main ;

    // command sent - wait for commands output to be ready
    data = 0 ;
    while( status && !( data & `KBD_OBF ) )
        read_status_reg(data, status) ;

    if ( status !== 1 )
        disable main ;
  
    read_data_reg( data, status ) ;

    if ( status !== 1 )
        disable main ; 

    if ( data !== 8'h55 )
    begin
        $display("Error! Keyboard controler should respond to self test command with hard coded value 0x55! ") ;
        #400 $stop ;
    end  

    // perform self test 2
    kbd_write(`KBD_CNTL_REG, `KBD_SELF_TEST2, status) ;
 
    if ( status !== 1 )
        disable main ;
 
    // command sent - wait for commands output to be ready
    data = 0 ;
    while( status && !( data & `KBD_OBF ) )
        read_status_reg(data, status) ;
 
    if ( status !== 1 )
        disable main ;
 
    read_data_reg( data, status ) ;
 
    if ( status !== 1 )
        disable main ;
 
    if ( data !== 8'h00 )
    begin
        $display("Error! Keyboard controler should respond to self test command 2 with hard coded value 0x00! ") ;
        #400 $stop ;
    end
    
    kbd_write(`KBD_CNTL_REG, `KBD_CNTL_ENABLE, status);
 
    if ( status !== 1 )
        disable main ; 

    // send reset command to keyboard
    kbd_write(`KBD_DATA_REG, `KBD_RESET, status) ;

    if ( status !== 1 )
        disable main ;

    fork 
    begin
        // wait for keyboard to respond with acknowledge
        data = 0 ;
        while( status && !( data & `KBD_OBF ) )
            read_status_reg(data, status) ;
 
        if ( status !== 1 )
            disable main ;
 
        read_data_reg( data, status ) ;
 
        if ( status !== 1 )
            disable main ;
 
        if ( data !== `KBD_ACK )
        begin
            $display("Error! Expected character from keyboard was 0x%h, actualy received 0x%h!", `KBD_ACK, data ) ;
            #400 $stop ;
        end 

        // wait for keyboard to respond with BAT status
        data = 0 ;
        while( status && !( data & `KBD_OBF ) )
            read_status_reg(data, status) ;
 
        if ( status !== 1 )
            disable main ;
 
        read_data_reg( data, status ) ;
 
        if ( status !== 1 )
            disable main ;
 
        if ( data !== `KBD_POR )
        begin
            $display("Error! Expected character from keyboard was 0x%h, actualy received 0x%h!", `KBD_POR, data ) ;
            #400 $stop ;
        end

        // send disable command to keyboard
        kbd_write(`KBD_DATA_REG, `KBD_DISABLE, status) ;
 
        if ( status !== 1 )
            disable main ;

        // wait for keyboard to respond with acknowledge
        data = 0 ;
        while( status && !( data & `KBD_OBF ) )
            read_status_reg(data, status) ;
 
        if ( status !== 1 )
            disable main ;
 
        read_data_reg( data, status ) ;
 
        if ( status !== 1 )
            disable main ;
 
        if ( data !== `KBD_ACK )
        begin
            $display("Error! Expected character from keyboard was 0x%h, actualy received 0x%h!", `KBD_ACK, data ) ;
            #400 $stop ;
        end
                       
        kbd_write(`KBD_CNTL_REG, `KBD_WRITE_MODE, status);
        if ( status !== 1 )
            disable main ;
 
        kbd_write(`KBD_DATA_REG, `KBD_EKI|`KBD_SYS|`KBD_DMS|`KBD_KCC, status);
        if ( status !== 1 )
            disable main ;

        // send disable command to keyboard
        kbd_write(`KBD_DATA_REG, `KBD_ENABLE, status) ;
 
        if ( status !== 1 )
            disable main ;
 
        // wait for keyboard to respond with acknowledge
        data = 0 ;
        while( status && !( data & `KBD_OBF ) )
            read_status_reg(data, status) ;
 
        if ( status !== 1 )
            disable main ;
 
        read_data_reg( data, status ) ;
 
        if ( status !== 1 )
            disable main ;
 
        if ( data !== `KBD_ACK )
        begin
            $display("Error! Expected character from keyboard was 0x%h, actualy received 0x%h!", `KBD_ACK, data ) ;
            #400 $stop ;
        end 

        // now check if command byte is as expected
        kbd_write(`KBD_CNTL_REG, `KBD_READ_MODE, status);
        if ( status !== 1 )
            disable main ;

        data = 0 ;
        while( status && !( data & `KBD_OBF ) )
            read_status_reg(data, status) ;

        if ( status !== 1 )
            disable main ;

        read_data_reg(data, status) ;

        if ( status !== 1 )
            disable main ;

        if ( (data & (`KBD_EKI|`KBD_SYS|`KBD_DMS|`KBD_KCC)) !== (`KBD_EKI|`KBD_SYS|`KBD_DMS|`KBD_KCC)  )
        begin
            $display("Error! Read command byte returned wrong value!") ;
            #400 $stop ;
        end
    end
    begin
        @(char_valid) ;
        if ( received_char !== `KBD_RESET )
        begin
            $display("Error! Keyboard received invalid character/command") ;
            #400 $stop ; 
        end

        i_ps2_keyboard_model.kbd_send_char
        (
            `KBD_ACK, 
            ok,
            error
        ) ;    

        i_ps2_keyboard_model.kbd_send_char
        (
            `KBD_POR,
            ok,
            error
        ) ;

         @(char_valid) ;
        if ( received_char !== `KBD_DISABLE )
        begin
            $display("Error! Keyboard received invalid character/command") ;
            #400 $stop ;
        end
 
        i_ps2_keyboard_model.kbd_send_char
        (
            `KBD_ACK,
            ok,
            error
        ) ; 

        @(char_valid) ;
        if ( received_char !== `KBD_ENABLE )
        begin
            $display("Error! Keyboard received invalid character/command") ;
            #400 $stop ;
        end
 
        i_ps2_keyboard_model.kbd_send_char
        (
            `KBD_ACK,
            ok,
            error
        ) ;
        
    end
    join

    watchdog_reset = !watchdog_reset ;

end
endtask // initialize_controler 

task read_data_reg ;
    output [7:0] return_byte_o ;
    output ok_o ;
    reg `READ_STIM_TYPE    read_data ;
    reg `READ_RETURN_TYPE  read_status ;
    reg `WB_TRANSFER_FLAGS flags ;
begin
    ok_o = 1 ;
    flags`WB_TRANSFER_SIZE     = 1 ;
    flags`WB_TRANSFER_AUTO_RTY = 0 ;
    flags`WB_TRANSFER_CAB      = 0 ;
    flags`INIT_WAITS           = 0 ;
    flags`SUBSEQ_WAITS         = 0 ;

    read_data`READ_ADDRESS = `KBD_DATA_REG ;
    read_data`READ_SEL     = 4'h8 ;

    read_status = 0 ;

    i_wb_master.wb_single_read( read_data, flags, read_status ) ;

    if ( read_status`CYC_ACK !== 1'b1 )
    begin
        $display("Error! Keyboard controler didn't acknowledge single read access!") ;
        #400 $stop ;
        ok_o = 0 ;
    end
    else
        return_byte_o = read_status`READ_DATA ;

end 
endtask //read_data_reg

task read_status_reg ;
    output [7:0] return_byte_o ;
    output ok_o ;
    reg `READ_STIM_TYPE    read_data ;
    reg `READ_RETURN_TYPE  read_status ;
    reg `WB_TRANSFER_FLAGS flags ;
begin
    ok_o = 1 ;
    flags`WB_TRANSFER_SIZE     = 1 ;
    flags`WB_TRANSFER_AUTO_RTY = 0 ;
    flags`WB_TRANSFER_CAB      = 0 ;
    flags`INIT_WAITS           = 0 ;
    flags`SUBSEQ_WAITS         = 0 ;
 
    read_data`READ_ADDRESS = `KBD_STATUS_REG ;
    read_data`READ_SEL     = 4'h8 ;
 
    read_status = 0 ;
 
    i_wb_master.wb_single_read( read_data, flags, read_status ) ;
 
    if ( read_status`CYC_ACK !== 1'b1 )
    begin
        $display("Error! Keyboard controler didn't acknowledge single read access!") ;
        #400 $stop ;
        ok_o = 0 ;
    end
    else
        return_byte_o = read_status`READ_DATA ;

end
endtask // read_status_reg

task kbd_write ;
    input [31:0] address_i ;
    input [31:0] data_i ;
    output ok_o ;

    reg `WRITE_STIM_TYPE   write_data ;
    reg `WRITE_RETURN_TYPE write_status ;
    reg `WB_TRANSFER_FLAGS flags ;
    reg [7:0] kbd_status ;
begin:main
    ok_o = 1 ;
    flags`WB_TRANSFER_SIZE     = 1 ;
    flags`WB_TRANSFER_AUTO_RTY = 0 ;
    flags`WB_TRANSFER_CAB      = 0 ;
    flags`INIT_WAITS           = 0 ;
    flags`SUBSEQ_WAITS         = 0 ;

    write_data`WRITE_ADDRESS = address_i ;
    write_data`WRITE_DATA    = data_i ;    
    write_data`WRITE_SEL     = 4'h8 ;

    read_status_reg(kbd_status, ok_o) ;

    while( ok_o && ( kbd_status & `KBD_IBF ))
    begin
        read_status_reg(kbd_status, ok_o) ;
    end

    if ( ok_o !== 1 )
        disable main ;

    i_wb_master.wb_single_write( write_data, flags, write_status ) ;

    if ( write_status`CYC_ACK !== 1 )
    begin
        $display("Error! Keyboard controller didn't acknowledge single write access") ;
        #400 $stop ;
        ok_o = 0 ;
    end
end 
endtask // kbd_write

task test_scan_code_receiving ;
    reg ok_keyboard ;
    reg ok_controler ;
    reg ok ;
    reg [7:0] data ;
    reg [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] keyboard_sequence ;
    reg [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] controler_sequence ;
begin:main
    // prepare character sequence to send from keyboard to controler
    // L SHIFT make
    keyboard_sequence[7:0]   = 8'h12 ;
    // A make
    keyboard_sequence[15:8]  = 8'h1C ;
    // A break
    keyboard_sequence[23:16] = 8'hF0 ;
    keyboard_sequence[31:24] = 8'h1C ;
    // L SHIFT break
    keyboard_sequence[39:32] = 8'hF0 ;
    keyboard_sequence[47:40] = 8'h12 ;

    // prepare character sequence as it is received in scan code set 1 through the controler
    // L SHIFT make
    controler_sequence[7:0]   = 8'h2A ;
    // A make
    controler_sequence[15:8]  = 8'h1E ;
    // A break
    controler_sequence[23:16] = 8'h9E ;
    // L SHIFT break
    controler_sequence[31:24] = 8'hAA ;

    fork
    begin
        send_sequence( keyboard_sequence, 6, ok_keyboard ) ;
        if ( ok_keyboard !== 1 )
            disable main ;
    end
    begin
        receive_sequence( controler_sequence, 4, ok_controler ) ;

        if ( ok_controler !== 1 )
            disable main ;
    end
    join

    // test same thing with translation disabled!
    kbd_write(`KBD_CNTL_REG, `KBD_WRITE_MODE, ok);
    if ( ok !== 1 )
        disable main ;
 
    kbd_write(`KBD_DATA_REG, `KBD_EKI|`KBD_SYS|`KBD_DMS, ok);
    if ( ok !== 1 )
        disable main ; 

    // since translation is disabled, controler sequence is the same as keyboard sequence
    controler_sequence = keyboard_sequence ;

    fork
    begin

        send_sequence( keyboard_sequence, 6, ok_keyboard ) ;
        if ( ok_keyboard !== 1 )
            disable main ;
         
    end
    begin
        receive_sequence( controler_sequence, 6, ok_controler ) ;
        if ( ok_controler !== 1 )
            disable main ;
    end
    join

    // turn translation on again
    kbd_write(`KBD_CNTL_REG, `KBD_WRITE_MODE, ok);
    if ( ok !== 1 )
        disable main ;
 
    kbd_write(`KBD_DATA_REG, `KBD_EKI|`KBD_SYS|`KBD_DMS|`KBD_KCC, ok);
    if ( ok !== 1 )
        disable main ;

    // test extended character receiving - rctrl + s combination
    // prepare sequence to send from keyboard to controler
    // R CTRL make
    keyboard_sequence[7:0]   = 8'hE0 ;
    keyboard_sequence[15:8]  = 8'h14 ;
    // S make
    keyboard_sequence[23:16] = 8'h1B ;
    // S break
    keyboard_sequence[31:24] = 8'hF0 ;
    keyboard_sequence[39:32] = 8'h1B ;
    // R CTRL break
    keyboard_sequence[47:40] = 8'hE0 ;
    keyboard_sequence[55:48] = 8'hF0 ;
    keyboard_sequence[63:56] = 8'h14 ;

    // prepare sequence that should be received from the controler
    // R CTRL make
    controler_sequence[7:0]   = 8'hE0 ;
    controler_sequence[15:8]  = 8'h1D ;
    // S make
    controler_sequence[23:16] = 8'h1F ;
    // S break
    controler_sequence[31:24] = 8'h9F ;
    // R CTRL break
    controler_sequence[39:32] = 8'hE0 ;
    controler_sequence[47:40] = 8'h9D ;

    fork
    begin
        send_sequence( keyboard_sequence, 8, ok_keyboard ) ;
        if ( ok_keyboard !== 1 )
            disable main ;
    end
    begin
 
        receive_sequence( controler_sequence, 6, ok_controler ) ;
 
        if ( ok_controler !== 1 )
            disable main ;       
    end
    join

     // test same thing with translation disabled!
    kbd_write(`KBD_CNTL_REG, `KBD_WRITE_MODE, ok);
    if ( ok !== 1 )
        disable main ;
 
    kbd_write(`KBD_DATA_REG, `KBD_EKI|`KBD_SYS|`KBD_DMS, ok);
    if ( ok !== 1 )
        disable main ;
 
    // since translation is disabled, controler sequence is the same as keyboard sequence
    controler_sequence = keyboard_sequence ; 

    fork
    begin
        send_sequence( keyboard_sequence, 8, ok_keyboard ) ;
        if ( ok_keyboard !== 1 )
            disable main ;
    end
    begin
 
        receive_sequence( controler_sequence, 8, ok_controler ) ;
 
        if ( ok_controler !== 1 )
            disable main ;
    end
    join

    watchdog_reset = !watchdog_reset ;
end
endtask // test_scan_code_receiving

task test_normal_scancodes ;
    reg ok ;
    reg ok_keyboard ;
    reg ok_controler ;
    integer i ;
    reg [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] keyboard_sequence ;
    reg [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] controler_sequence ; 
begin:main
    // turn translation on
    kbd_write(`KBD_CNTL_REG, `KBD_WRITE_MODE, ok);
    if ( ok !== 1 )
        disable main ;
 
    kbd_write(`KBD_DATA_REG, `KBD_EKI|`KBD_SYS|`KBD_DMS|`KBD_KCC, ok);
    if ( ok !== 1 )
        disable main ;

    for ( i = 0 ; i < `PS2_NUM_OF_NORMAL_SCANCODES ; i = i + 1 )
    begin
        keyboard_sequence[7:0]   = normal_scancode_set2_mem[i] ;
        keyboard_sequence[15:8]  = 8'hF0 ;
        keyboard_sequence[23:16] = normal_scancode_set2_mem[i] ;

        controler_sequence[7:0]  = normal_scancode_set1_mem[i] ;
        controler_sequence[15:8] = normal_scancode_set1_mem[i] | 8'h80 ;
        fork
        begin
            send_sequence( keyboard_sequence, 3, ok_keyboard ) ;
            if ( ok_keyboard !== 1 )
                disable main ;
        end
        begin
            receive_sequence( controler_sequence, 2, ok_controler ) ;
            if ( ok_controler !== 1 )
                disable main ;
        end
        join
    end

    watchdog_reset = !watchdog_reset ;
    
end
endtask // test_normal_scancodes

task test_extended_scancodes ;
    reg ok ;
    reg ok_keyboard ;
    reg ok_controler ;
    integer i ;
    reg [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] keyboard_sequence ;
    reg [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] controler_sequence ;
begin:main
    // turn translation on
    kbd_write(`KBD_CNTL_REG, `KBD_WRITE_MODE, ok);
    if ( ok !== 1 )
        disable main ;
 
    kbd_write(`KBD_DATA_REG, `KBD_EKI|`KBD_SYS|`KBD_DMS|`KBD_KCC, ok);
    if ( ok !== 1 )
        disable main ;
 
    for ( i = 0 ; i < `PS2_NUM_OF_EXTENDED_SCANCODES ; i = i + 1 )
    begin
        keyboard_sequence[7:0]   = 8'hE0 ;
        keyboard_sequence[15:8]  = extended_scancode_set2_mem[i] ;
        keyboard_sequence[23:16] = 8'hE0 ;
        keyboard_sequence[31:24] = 8'hF0 ;
        keyboard_sequence[39:32] = extended_scancode_set2_mem[i] ;
 
        controler_sequence[7:0]   = 8'hE0 ;
        controler_sequence[15:8]  = extended_scancode_set1_mem[i] ;
        controler_sequence[23:16] = 8'hE0 ;
        controler_sequence[31:24] = extended_scancode_set1_mem[i] | 8'h80 ;
        fork
        begin
            send_sequence( keyboard_sequence, 5, ok_keyboard ) ;
            if ( ok_keyboard !== 1 )
                disable main ;
        end
        begin
            receive_sequence( controler_sequence, 4, ok_controler ) ;
            if ( ok_controler !== 1 )
                disable main ;
        end
        join
    end
 
    watchdog_reset = !watchdog_reset ;
 
end
endtask // test_extended_scancodes

task return_scan_code_on_irq ;
    output [7:0] scan_code_o ;
    output       ok_o ;
    reg    [7:0] temp_data ;
begin:main
    wait ( wb_int === 1 ) ;
    read_status_reg( temp_data, ok_o ) ;
 
    if ( ok_o !== 1'b1 )
        disable main ;
 
    if ( !( temp_data & `KBD_OBF ) )
    begin
        $display("Error! Interrupt received from keyboard controler when OBF status not set!") ;
        #400 $stop ;
    end
 
    read_data_reg( temp_data, ok_o ) ;
 
    if ( ok_o !== 1'b1 )
        disable main ;

    scan_code_o = temp_data ;
end
endtask // return_scan_code_on_irq

task send_sequence ;
    input [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] sequence_i ;
    input [31:0] num_of_chars_i ;
    output ok_o ;
    reg [7:0] current_char ;
    integer i ;
    reg ok ;
    reg error ;
begin:main

    error = 0 ;
    ok_o  = 1 ;
    ok    = 0 ;

    for( i = 0 ; i < num_of_chars_i ; i = i + 1 ) 
    begin
        current_char = sequence_i[7:0] ;
        
        sequence_i = sequence_i >> 8 ;
        ok = 0 ;
        error = 0 ;
        while ( (ok !== 1) && (error === 0) )
        begin
            i_ps2_keyboard_model.kbd_send_char
            (
                current_char,
                ok,
                error
            ) ; 
        end

        if ( error )
        begin
            $display("Time %t", $time) ;
            $display("Keyboard model signaled an error!") ;
            ok_o = 0 ;
            disable main ;
        end
    end
end
endtask // send_sequence

task receive_sequence ;
    input [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] sequence_i ;
    input [31:0] num_of_chars_i ;
    output ok_o ;
    reg [7:0] current_char ;
    reg [7:0] data ;
    integer i ;
begin:main
 
    ok_o  = 1 ;
 
    for( i = 0 ; i < num_of_chars_i ; i = i + 1 )
    begin
        current_char = sequence_i[7:0] ;
 
        sequence_i = sequence_i >> 8 ;

        return_scan_code_on_irq( data, ok_o ) ;

        if ( ok_o !== 1 )
            disable main ; 

        if ( data !== current_char )
        begin
            $display("Time %t", $time) ;
            $display("Error! Character received was wrong!") ;
            $display("Expected character: %h, received %h ", current_char, data ) ;
        end
    end
end
endtask // receive_seqence

task test_keyboard_inhibit ;
    reg ok_controler ;
    reg ok_keyboard ;
    reg error ;
    reg [7:0] data ;
begin:main
    // first test, if keyboard stays inhibited after character is received, but not read from the controler
    i_ps2_keyboard_model.kbd_send_char
    (
        8'hE0,
        ok_keyboard,
        error
    ) ;

    if ( error )
    begin
        $display("Error! Keyboard signaled an error while sending character!") ;
        disable main ;
    end

    if ( !ok_keyboard )
    begin
        $display("Something is wrong! Keyboard wasn't able to send a character!") ;
        disable main ;
    end

    // wait 5 us to see, if keyboard is inhibited
    #5000 ;

    // now check, if clock line is low!
    if ( kbd_clk_cable !== 0 )
    begin
        $display("Error! Keyboard wasn't inhibited when output buffer was filled!") ;
        disable main ;
    end

    // now read the character from input buffer and check if clock was released
    return_scan_code_on_irq( data, ok_controler ) ;
    if ( ok_controler !== 1'b1 )
        disable main ;

    if ( data !== 8'hE0 )
    begin
        $display("Time %t", $time) ;
        $display("Error! Character read from controler not as expected!") ;
    end

    fork
    begin
        repeat(10)
            @(posedge wb_clock) ;

        if ( kbd_clk_cable !== 1 )
        begin
            $display("Error! Keyboard wasn't released from inhibited state when output buffer was read!") ;
            disable main ;
        end
    end
    begin
        i_ps2_keyboard_model.kbd_send_char
        (
            8'h1C,
            ok_keyboard,
            error
        ) ;
        if ( !ok_keyboard )
        begin
            $display("Something is wrong! Keyboard wasn't able to send a character!") ;
            disable main ;
        end
    end
    begin
        return_scan_code_on_irq( data, ok_controler ) ;
        if ( ok_controler !== 1'b1 )
            disable main ;
 
        if ( data !== 8'h1E )
        begin
            $display("Time %t", $time) ;
            $display("Error! Character read from controler not as expected!") ;
        end
    end
    join

    // disable keyboard controler
    kbd_write( `KBD_CNTL_REG, `KBD_WRITE_MODE, ok_controler ) ;
    if ( ok_controler !== 1 )
        disable main ;

    kbd_write(`KBD_DATA_REG, `KBD_EKI|`KBD_SYS|`KBD_DMS|`KBD_KCC | `KBD_DISABLE_COMMAND, ok_controler); 

    if ( ok_controler !== 1 )
        disable main ;

    repeat( 5 )
        @(posedge wb_clock) ;

    // now check, if clock line is low!
    if ( kbd_clk_cable !== 0 )
    begin
        $display("Error! Keyboard wasn't inhibited when keyboard controler was disabled!") ;
        disable main ;
    end

    // send character and enable keyboard controler at the same time
    fork
    begin
        i_ps2_keyboard_model.kbd_send_char
        (
            8'hE0,
            ok_keyboard,
            error
        ) ;
 
        if ( !ok_keyboard )
        begin
            $display("Something is wrong! Keyboard wasn't able to send a character!") ;
            disable main ;
        end    
    end
    begin
        // enable keyboard controler
        kbd_write( `KBD_CNTL_REG, `KBD_WRITE_MODE, ok_controler ) ;
        if ( ok_controler !== 1 )
            disable main ;
 
        kbd_write(`KBD_DATA_REG, `KBD_EKI|`KBD_SYS|`KBD_DMS|`KBD_KCC, ok_controler);
        if ( ok_controler !== 1 )
            disable main ;
    end
    begin
        return_scan_code_on_irq( data, ok_controler ) ;
        if ( ok_controler !== 1'b1 )
            disable main ;
 
        if ( data !== 8'hE0 )
        begin
            $display("Time %t", $time) ;
            $display("Error! Character read from controler not as expected!") ;
        end
    end
    join

    // do D2 command, that copies parameter in input buffer to output buffer
    kbd_write( `KBD_CNTL_REG, 32'hD2, ok_controler ) ;
    if ( ok_controler !== 1 )
        disable main ;

    kbd_write(`KBD_DATA_REG, 32'h5555_5555, ok_controler) ;

    if ( ok_controler !== 1 )
        disable main ;

    return_scan_code_on_irq( data, ok_controler ) ;
    if ( ok_controler !== 1 )
        disable main ;

    if ( data !== 8'h55 ) 
    begin
        $display("Error! D2 command doesn't work properly") ;
    end

end
endtask // test_keyboard_inhibit

task test_print_screen_and_pause_scancodes ;
    reg ok ;
    reg ok_keyboard ;
    reg ok_controler ;
    integer i ;
    reg [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] keyboard_sequence ;
    reg [(MAX_SEQUENCE_LENGTH*8 - 1) : 0] controler_sequence ;
begin:main
    // turn translation on
    kbd_write(`KBD_CNTL_REG, `KBD_WRITE_MODE, ok);
    if ( ok !== 1 )
        disable main ;
 
    kbd_write(`KBD_DATA_REG, `KBD_EKI|`KBD_SYS|`KBD_DMS|`KBD_KCC, ok);
    if ( ok !== 1 )
        disable main ; 

    // prepare character sequence to send from keyboard to controler - pause
    keyboard_sequence[7:0]   = 8'hE1 ;
    keyboard_sequence[15:8]  = 8'h14 ;
    keyboard_sequence[23:16] = 8'h77 ;
    keyboard_sequence[31:24] = 8'hE1 ;
    keyboard_sequence[39:32] = 8'hF0 ;
    keyboard_sequence[47:40] = 8'h14 ;
    keyboard_sequence[55:48] = 8'hF0 ;
    keyboard_sequence[63:56] = 8'h77 ;
 
    // prepare character sequence as it is received in scan code set 1 through the controler
    controler_sequence[7:0]   = 8'hE1 ;
    controler_sequence[15:8]  = 8'h1D ;
    controler_sequence[23:16] = 8'h45 ;
    controler_sequence[31:24] = 8'hE1 ;
    controler_sequence[39:32] = 8'h9D ;
    controler_sequence[47:40] = 8'hC5 ;

    fork
    begin
        send_sequence( keyboard_sequence, 8, ok_keyboard ) ;
        if ( ok_keyboard !== 1 )
            disable main ;
    end
    begin
        receive_sequence( controler_sequence, 6, ok_controler ) ;
        if ( ok_controler !== 1 )
            disable main ;
    end
    join

    // prepare character sequence to send from keyboard to controler - make print screen
    keyboard_sequence[7:0]   = 8'hE0 ;
    keyboard_sequence[15:8]  = 8'h12 ;
    keyboard_sequence[23:16] = 8'hE0 ;
    keyboard_sequence[31:24] = 8'h7C ;
 
    // prepare character sequence as it is received in scan code set 1 through the controler
    controler_sequence[7:0]   = 8'hE0 ;
    controler_sequence[15:8]  = 8'h2A ;
    controler_sequence[23:16] = 8'hE0 ;
    controler_sequence[31:24] = 8'h37 ;

    fork
    begin
        send_sequence( keyboard_sequence, 4, ok_keyboard ) ;
        if ( ok_keyboard !== 1 )
            disable main ;
    end
    begin
        receive_sequence( controler_sequence, 4, ok_controler ) ;
        if ( ok_controler !== 1 )
            disable main ;
    end
    join

    // prepare character sequence to send from keyboard to controler - break print screen
    keyboard_sequence[7:0]   = 8'hE0 ;
    keyboard_sequence[15:8]  = 8'hF0 ;
    keyboard_sequence[23:16] = 8'h7C ;
    keyboard_sequence[31:24] = 8'hE0 ;
    keyboard_sequence[39:32] = 8'hF0 ;
    keyboard_sequence[47:40] = 8'h12 ;
 
    // prepare character sequence as it is received in scan code set 1 through the controler
    controler_sequence[7:0]   = 8'hE0 ;
    controler_sequence[15:8]  = 8'hB7 ;
    controler_sequence[23:16] = 8'hE0 ;
    controler_sequence[31:24] = 8'hAA ;

    fork
    begin
        send_sequence( keyboard_sequence, 6, ok_keyboard ) ;
        if ( ok_keyboard !== 1 )
            disable main ;
    end
    begin
        receive_sequence( controler_sequence, 4, ok_controler ) ;
        if ( ok_controler !== 1 )
            disable main ;
    end
    join
end
endtask // test_print_screen_and_pause_scancodes

endmodule // ps2_test_bench
