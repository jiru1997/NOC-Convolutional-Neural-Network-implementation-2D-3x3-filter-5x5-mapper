//-------------------------------------------------------------------------------------------------
// control center module 
// control initialization of all PEs 
//-------------------------------------------------------------------------------------------------

`timescale 1ns/1ps
import SystemVerilogCSP::*;
import dataformat::*;

module add
  #(parameter WIDTH = 5,
  parameter tot_num = 9,
  parameter tot_time = 3,
  parameter DATA_WIDTH = 20,
  parameter FL = 2,
  parameter BL = 2,
  parameter PACKDELAY = 1)

  ( input bit[WIDTH - 1:0] _index,
    input bit[WIDTH - 1:0] _mem_index,
    interface ccToAdd,
    interface RouterToAdd_in,
    interface RouterToAdd_out);

  int times[int];
  int sum[int];
  int pointer, i;
  bit flag = 0;
  bit[WIDTH - 1:0] index;
  bit[WIDTH - 1:0] mem_index;
  bit[DATA_WIDTH - 1:0] data_pass_memory;               
  bit[DATA_WIDTH - 1:0] data_pass_PE;                   

  always begin
      RouterToAdd_in.Receive(data_pass_PE);
      sum[dataformater::getsendaddr(data_pass_PE)] += dataformater::unpackdata(data_pass_PE);
	  # PACKDELAY;
      times[dataformater::getsendaddr(data_pass_PE)] += 1;
	  # PACKDELAY;
      # FL;
  end

  always begin
    wait(times[pointer] == tot_time);
    data_pass_memory = dataformater::packdata(index, mem_index, 0, sum[pointer]);
	# PACKDELAY;
    pointer = pointer + 1;
    RouterToAdd_out.Send(data_pass_memory);
    # BL;
  end

  always begin
    wait(pointer == tot_num);
    ccToAdd.Send(flag);
	#BL;
    wait(1 == 0);
  end

  initial begin
    #0.1;
    pointer = 0;
    index = _index;
    mem_index = _mem_index;
    for(i = 0; i < tot_num; i = i + 1) begin
      times[i] = 0;
      sum[i] = 0;
    end
    ccToAdd.Receive(flag);
	#FL;
  end


endmodule
