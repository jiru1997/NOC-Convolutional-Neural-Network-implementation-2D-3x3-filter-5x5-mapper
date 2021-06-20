//-------------------------------------------------------------------------------------------------
// PE module 
// submodule : multipler adder split accumulator control
//-------------------------------------------------------------------------------------------------

`timescale 1ns/1fs
import SystemVerilogCSP::*;
import dataformat::*;
module PE
	#(parameter WIDTH = 5,
	parameter FILTER_WIDTH = 3,
	parameter IFMAP_WIDTH = 5,
	parameter DATA_WIDTH = 20,
	parameter VALID_DATA_WIDTH = 8,
	parameter FL = 2,
	parameter BL = 2,
	parameter PACKDELAY = 1)

	( input bit[WIDTH - 1:0] _index,
	  input bit[WIDTH - 1:0] _inner_index_x,
	  input bit[WIDTH - 1:0] _inner_index_y,
	  input bit[WIDTH - 1:0] _sum_index,
	  input bit[WIDTH - 1:0] _mem_index,
	  input bit[WIDTH - 1:0] _tot_pe_row,
	  input bit[WIDTH - 1:0] _tot_pe_col,
	  input bit[VALID_DATA_WIDTH - 1:0] _filter_pointer,
	  input bit[VALID_DATA_WIDTH - 1:0] _ifmap_pointer,
	  interface RouterToPE_in,
	  interface RouterToPE_out,
	  interface ccToPE);

    bit              beginflag;
    bit[WIDTH - 1:0] index;
    bit[WIDTH - 1:0] inner_index_x;                        
    bit[WIDTH - 1:0] inner_index_y; 
	bit[WIDTH - 1:0] sum_index;
	bit[WIDTH - 1:0] mem_index;
	bit[WIDTH - 1:0] tot_pe_row;
	bit[WIDTH - 1:0] tot_pe_col;
	bit[VALID_DATA_WIDTH - 1:0] final_result;               
	bit[DATA_WIDTH - 1:0] data_pass_memory;                 
    bit[DATA_WIDTH - 1:0] data_pass_add;                    
	bit[VALID_DATA_WIDTH - 1:0] flag;                     
    bit[VALID_DATA_WIDTH - 1:0] filter_pointer_memory;           
	bit[VALID_DATA_WIDTH - 1:0] ifmap_pointer_memory;            
	bit[FILTER_WIDTH - 1:0][VALID_DATA_WIDTH - 1:0] filter_data;     
	bit[IFMAP_WIDTH - 1:0][VALID_DATA_WIDTH - 1:0]  ifmap_data;       
    bit[FILTER_WIDTH-1:0] addr_in_filter;
	bit[IFMAP_WIDTH-1:0] addr_in_mapper;
	int i, j, filter_pointer, ifmap_pointer;

    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  Start ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  Done ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  PsumToAdder (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  SplitToPsum (); 
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  PEToMult_filter (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  PEToMult_mapper (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  MultToAdd (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  AcToAdd ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  ControlToAdd (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  AdderToSplit (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  ControlToSplit (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  SplitToAc ();  
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  ControlToAc ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  FilterAddr ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  IfmapAddr (); 
    
    multipler #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2))
    mp(.PEToMult_filter(PEToMult_filter), .PEToMult_mapper(PEToMult_mapper), .MultToAdder(MultToAdd));

    adder #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2))
    ad(.MultToAdder (MultToAdd), .AcToAdder(AcToAdd), .PsumToAdder(PsumToAdder), .ControlToAdder(ControlToAdd), .AdderToSplit(AdderToSplit));

    split #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2))
    sp(.AdderToSplit(AdderToSplit), .ControlToSplit(ControlToSplit), .SplitToPsum(SplitToPsum), .SplitToAc(SplitToAc));

    accumulator #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2))
    ac(.SplitToAc(SplitToAc), .ControlToAc(ControlToAc), .AcToAdder(AcToAdd));

    control #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2))
    cl(.FilterAddr(FilterAddr), .IfmapAddr(IfmapAddr), .ControlToAdd(ControlToAdd), .ControlToAc(ControlToAc), .ControlToSplit(ControlToSplit), .Start (Start), .Done (Done));

	always begin
	  IfmapAddr.Receive(addr_in_mapper);
	  #FL;
	  PEToMult_mapper.Send(ifmap_data[addr_in_mapper]);
	  #BL;
	end
	
	always begin
	  FilterAddr.Receive(addr_in_filter);
	  #FL;
	  PEToMult_filter.Send(filter_data[addr_in_filter]);
	  #BL;
	end	
	
	always begin
	  PsumToAdder.Send(0);
	end
	
	always begin
		for(integer j = 0; j < IFMAP_WIDTH - FILTER_WIDTH + 1; j = j + 1) begin
		  SplitToPsum.Receive(final_result);
		  data_pass_add = dataformater::packdata((inner_index_y - 1) * tot_pe_row + j, sum_index, 2, final_result);
		  # PACKDELAY;
		  RouterToPE_out.Send(data_pass_add);
		  # BL;
	    end
	end

	always begin
	  Done.Receive(flag);
	  #FL;
	  ccToPE.Send(beginflag);
	  #BL;
	  ccToPE.Receive(beginflag);
	  $stop();
	end 
	
	initial begin
	  #0.1;
	  index = _index;
 	  inner_index_x = _inner_index_x;
 	  inner_index_y = _inner_index_y;
	  sum_index = _sum_index;
	  mem_index = _mem_index;
	  tot_pe_row = _tot_pe_row;
	  tot_pe_col = _tot_pe_col;
	  filter_pointer_memory = _filter_pointer;
	  ifmap_pointer_memory = _ifmap_pointer;
	  filter_pointer = 0;
	  ifmap_pointer = 0;

	  ccToPE.Receive(beginflag);
	  #FL;
      if(inner_index_y == 1 || inner_index_x == tot_pe_col) begin

      	  if(inner_index_y == 1) begin
			  for(integer i = 0; i < FILTER_WIDTH; i = i + 1) begin
		        data_pass_memory = dataformater::packdata(index, mem_index, 2, filter_pointer_memory);
				#PACKDELAY;
			    RouterToPE_out.Send(data_pass_memory);
				#BL;
				RouterToPE_in.Receive(data_pass_memory);
				#FL;
			    filter_data[i] = dataformater::unpackdata(data_pass_memory);  
			    //$display("filter data: mem[%d]= %d",i, filter_data[i]);
	            filter_pointer_memory = filter_pointer_memory + 1;
			  end
		  end

		  for(integer i = 0; i < IFMAP_WIDTH; i = i + 1) begin
	        data_pass_memory = dataformater::packdata(index, mem_index, 1, ifmap_pointer_memory);
			#PACKDELAY;
		    RouterToPE_out.Send(data_pass_memory);
			#BL;
			RouterToPE_in.Receive(data_pass_memory);
			#FL;
		    ifmap_data[i] = dataformater::unpackdata(data_pass_memory);  
		    //$display("%m mapper data: mem[%d]= %d",i, ifmap_data[i]);
            ifmap_pointer_memory = ifmap_pointer_memory + 1;
		  end
		  
		  //boardcast filter data
		  if(inner_index_y == 1) begin
			  for(integer i = 1; i < tot_pe_col; i = i + 1) begin
			   for(integer j = 0; j < FILTER_WIDTH; j = j + 1) begin                                        
				data_pass_memory = dataformater::packdata(j, index + 2 * i, 2, filter_data[j]);
				#PACKDELAY;
				RouterToPE_out.Send(data_pass_memory);
				#BL;
			   end
			  end
		   end
		   else begin
			   for(i = 0; i < FILTER_WIDTH; i = i + 1) begin                                        
				RouterToPE_in.Receive(data_pass_memory);
			    filter_data[dataformater::getsendaddr(data_pass_memory)] = dataformater::unpackdata(data_pass_memory);  
				#PACKDELAY;
			    #FL;
			  end
		   end

		  //boardcast mapper data
		  for(integer i = 1; i <= inner_index_x - inner_index_y; i = i + 1) begin
			   for(integer j = 0; j < IFMAP_WIDTH; j = j + 1) begin                                        
				data_pass_memory = dataformater::packdata(j, index - 4 * i, 1, ifmap_data[j]);
				#PACKDELAY;
				RouterToPE_out.Send(data_pass_memory);
				#BL;
			   end
		  end
      end
      else begin
      	for(integer i = 0; i < FILTER_WIDTH + IFMAP_WIDTH; i = i + 1) begin
            RouterToPE_in.Receive(data_pass_memory);
            if(data_pass_memory[DATA_WIDTH - 1] == 0 && data_pass_memory[DATA_WIDTH - 2] == 1) begin
				ifmap_data[dataformater::getsendaddr(data_pass_memory)] = dataformater::unpackdata(data_pass_memory); 
				#PACKDELAY;
				//$display("%m mapper data: mem[%d]= %d",i, ifmap_data[i]);
            end
            else begin
            	filter_data[dataformater::getsendaddr(data_pass_memory)] = dataformater::unpackdata(data_pass_memory); 
				#PACKDELAY;
                //$display("%m filter data: mem[%d]= %d",i, filter_data[i]);
            end
      	end
      end
      //$display("%m filter_data is %d, %d, %d", filter_data[0], filter_data[1], filter_data[2]);
      //$display("%m mapper_data is %d, %d, %d, %d, %d", ifmap_data[0], ifmap_data[1], ifmap_data[2], ifmap_data[3], ifmap_data[4]);
	  Start.Send(1);
	  #BL;
	end
endmodule

//-------------------------------------------------------------------------------------------------
// control module 
// send filter and map address to PE module
//-------------------------------------------------------------------------------------------------
module control
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8,
	  parameter FILTER_WIDTH = 5,
	  parameter IFMAP_WIDTH = 7)

	( interface FilterAddr,
	  interface IfmapAddr,
	  interface ControlToAdd,
	  interface ControlToAc,
	  interface ControlToSplit,
	  interface Start,
	  interface Done );

    int i, j;
    logic [WIDTH-1:0] flag = 8'b00000000;
    logic [WIDTH-1:0] high = 8'b00000001;
    logic [WIDTH-1:0] low =  8'b00000000;

    always begin
    	wait(flag == 1);
	    for(i = 0; i < IFMAP_WIDTH - FILTER_WIDTH + 1; i = i + 1) begin
			ControlToAc.Send(high); 
            for(j = 0; j < FILTER_WIDTH; j = j + 1) begin
            	fork
	                ControlToSplit.Send(low);
					//低电平->数据传回accumulator
	                ControlToAdd.Send(high);
					//高电平->memory数据相加
	                FilterAddr.Send(j);
					//filter地址
	                IfmapAddr.Send(i + j);
					//ifmap地址
	                ControlToAc.Send(low);  
					//split->accumlator
	            join
	            #BL;
            end
            fork
               FilterAddr.Send(0);
	           IfmapAddr.Send(0);    //send two sudoaddress
	           ControlToAc.Send(low);
	           ControlToAdd.Send(low);
	           ControlToSplit.Send(high); 
            join
	    end
	    flag = 0;
	    Done.Send(high);
		#BL;
    end

    always begin
        Start.Receive(flag);
        #FL;
    end
endmodule

//-------------------------------------------------------------------------------------------------
// multipler module 
// get data from PE, do multiplication , send to adder module
//-------------------------------------------------------------------------------------------------
module multipler
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8)

	( interface PEToMult_filter,
	  interface PEToMult_mapper,
	  interface MultToAdder);

    logic [WIDTH-1:0] data_filter;
    logic [WIDTH-1:0] data_ifmap;

    always begin
	  fork 
		PEToMult_filter.Receive(data_filter);
		PEToMult_mapper.Receive(data_ifmap);
	  join
	  #FL;
	  MultToAdder.Send(data_filter * data_ifmap);
	  #BL;
    end
endmodule

//-------------------------------------------------------------------------------------------------
// adder module 
// receive data from accumulator multiplier and psum
//-------------------------------------------------------------------------------------------------
module adder
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8)

	( interface MultToAdder,
	  interface AcToAdder,
	  interface PsumToAdder,
	  interface ControlToAdder,
	  interface AdderToSplit);

    logic [WIDTH-1:0] data_mult;
    logic [WIDTH-1:0] data_ac;
    logic [WIDTH-1:0] data_psum;
    logic [WIDTH-1:0] contralData;

    always begin
    	fork
            ControlToAdder.Receive(contralData);    //control signal from control module
        	MultToAdder.Receive(data_mult);         //data from mult module
	        AcToAdder.Receive(data_ac);             //data from accumulator module
	        PsumToAdder.Receive(data_psum);       //data from psum
        join
    	# BL;
    	if(contralData == 1) begin
	    	AdderToSplit.Send(data_mult + data_ac);
        end
        else begin
	    	AdderToSplit.Send(data_ac + data_psum);
        end        	
	    # FL;
    end
endmodule

//-------------------------------------------------------------------------------------------------
// split module 
// receive data from control and send output to accumulator or psumout
//-------------------------------------------------------------------------------------------------
module split
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8)

	( interface AdderToSplit,
	  interface ControlToSplit,
	  interface SplitToPsum,
	  interface SplitToAc);

    logic [WIDTH-1:0] data_add;
    logic [WIDTH-1:0] contralData;

    always begin
    	fork 
    		AdderToSplit.Receive(data_add);
            ControlToSplit.Receive(contralData);
    	join
    	# BL;
    	if(contralData == 0) begin    //低电平->数据传回accumulator
	    	SplitToAc.Send(data_add);
        end
        else begin
	    	SplitToPsum.Send(data_add);
	    	SplitToAc.Send(data_add);
        end        	
	    # FL;
    end
endmodule

//-------------------------------------------------------------------------------------------------
// accumulator module 
// receive data from split and send to adder
//-------------------------------------------------------------------------------------------------
module accumulator
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8)

	( interface SplitToAc,
	  interface ControlToAc,
	  interface AcToAdder);

    logic [WIDTH-1:0] data_current;
    logic [WIDTH-1:0] controlData;
    logic [WIDTH-1:0] data_previous = 8'b00000000;

    always begin
    	ControlToAc.Receive(controlData);
    	# BL;
    	if(controlData == 0) begin
    		fork
	            SplitToAc.Receive(data_current);
		    	AcToAdder.Send(data_previous);
	        join
	        data_previous = data_current;
        end
        else begin
	    	data_previous = 8'b00000000;
        end        	
	    # FL;
    end
endmodule

