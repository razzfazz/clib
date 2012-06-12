// $Id$

/*
 Copyright (c) 2007-2011, Trustees of The Leland Stanford Junior University
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 Redistributions of source code must retain the above copyright notice, this 
 list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this
 list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

//==============================================================================
// prefix tree based round-robin arbiter
//==============================================================================

module c_prefix_arbiter
  (clk, reset, active, req_pr, gnt_pr, gnt, update);
   
`include "c_constants.v"
`include "c_functions.v"
   
   // number of input ports
   parameter num_ports = 32;
   
   // number of priority levels
   parameter num_priorities = 1;
   
   // perform masking between priorities
   parameter mask_priorities = 1;
   
   // store priorities in encoded form
   parameter encode_state = 1;
   
   // width of encoded arbiter state
   localparam state_width = clogb(num_ports);
   
   parameter reset_type = `RESET_TYPE_ASYNC;
   
   input clk;
   input reset;
   input active;
   
   // vector of requests
   input [0:num_priorities*num_ports-1] req_pr;
   
   // vector of grants
   output [0:num_priorities*num_ports-1] gnt_pr;
   wire [0:num_priorities*num_ports-1] 	 gnt_pr;
   
   // merged vector of grants
   output [0:num_ports-1] 		 gnt;
   wire [0:num_ports-1] 		 gnt;
   
   // update port priorities
   input 				 update;
   
   generate
      
      if(num_ports == 1)
	begin
	   
	   if(mask_priorities)
	     begin
		
		c_lod
		  #(.width(num_priorities),
		    .num_priorities(1))
		gnt_lod
		  (.data_in_pr(req_pr),
		   .data_out_pr(gnt_pr),
		   .data_out());
		
	     end
	   else
	     assign gnt_pr = req_pr;
	   
	   assign gnt = |req_pr;
	   
	end
      else if(num_ports > 1)
	begin
	   
	   wire [0:num_priorities*num_ports-1] gnt_intm_pr;
	   wire [0:num_ports-1] 	       gnt_intm;
	   
	   wire [0:num_ports-1] 	       prio_port;
	   
	   genvar 			       prio;
	   
	   for(prio = 0; prio < num_priorities; prio = prio + 1)
	     begin:prios
		
		wire [0:num_ports-1] req;
		assign req = req_pr[prio*num_ports:(prio+1)*num_ports-1];
		
		wire [0:num_ports-1] g_in;
		assign g_in = prio_port;
		
		wire [0:num_ports-1] p_in;
		assign p_in = ~{req[num_ports-1], req[0:num_ports-2]};
		
		wire [0:num_ports-1] g_out;
		wire [0:num_ports-1] p_out;
		c_prefix_net
		  #(.width(num_ports),
		    .enable_wraparound(1))
		g_out_pn
		  (.g_in(g_in),
		   .p_in(p_in),
		   .g_out(g_out),
		   .p_out(p_out));
		
		wire [0:num_ports-1] gnt;
		assign gnt = req & g_out;
		
		assign gnt_intm_pr[prio*num_ports:(prio+1)*num_ports-1] = gnt;
		
	     end
	   
	   if(encode_state)
	     begin
		
		wire [0:state_width-1] next_state;
		c_encode
		  #(.num_ports(num_ports),
		    .offset(1))
		next_state_enc
		  (.data_in(gnt),
		   .data_out(next_state));
		
		wire [0:state_width-1] state_s, state_q;
		assign state_s = update ? next_state : state_q;
		c_dff
		  #(.width(state_width),
		    .reset_type(reset_type))
		stateq
		  (.clk(clk),
		   .reset(reset),
		   .active(active),
		   .d(state_s),
		   .q(state_q));
		
		c_decode
		  #(.num_ports(num_ports))
		prio_port_dec
		  (.data_in(state_q),
		   .data_out(prio_port));
		
	     end
	   else
	     begin
		
		wire [0:num_ports-1] next_prio;
		assign next_prio = {gnt[num_ports-1], gnt[0:num_ports-2]};
		
		wire [0:num_ports-1] prio_s, prio_q;
		assign prio_s = update ? next_prio : prio_q;
		c_dff
		  #(.width(num_ports),
		    .reset_value({1'b1, {(num_ports-1){1'b0}}}),
		    .reset_type(reset_type))
		prioq
		  (.clk(clk),
		   .reset(reset),
		   .active(active),
		   .d(prio_s),
		   .q(prio_q));
		
		assign prio_port = prio_q;
		
	     end
	   
	   if(num_priorities == 1)
	     begin
		assign gnt_intm = gnt_intm_pr;
		assign gnt_pr = gnt_intm_pr;
		assign gnt = gnt_intm;
	     end
	   else if(num_priorities > 1)
	     begin
		
		wire [0:num_priorities-1] sel_pr;
		
		if(num_priorities == 2)
		  assign sel_pr
		    = {|req_pr[0:num_ports-1], ~|req_pr[0:num_ports-1]};
		else if(num_priorities > 2)
		  begin
		     
		     wire [0:num_priorities-1] valid_pr;
		     c_mat_mult
		       #(.dim1_width(num_priorities),
			 .dim2_width(num_ports),
			 .dim3_width(1),
			 .prod_op(`BINARY_OP_AND),
			 .sum_op(`BINARY_OP_OR))
		     valid_pr_mmult
		       (.input_a(req_pr),
			.input_b({num_ports{1'b1}}),
			.result(valid_pr));
		     
		     wire [0:num_priorities-1] any_req_pr;
		     assign any_req_pr = {valid_pr[0:num_priorities-2], 1'b1};
		     
		     c_lod
		       #(.width(num_priorities),
			 .num_priorities(1))
		     sel_pr_lod
		       (.data_in_pr(any_req_pr),
			.data_out_pr(sel_pr),
			.data_out());
		     
		  end
		
		c_select_1ofn
		  #(.num_ports(num_priorities),
		    .width(num_ports))
		gnt_intm_sel
		  (.select(sel_pr),
		   .data_in(gnt_intm_pr),
		   .data_out(gnt_intm));
		
		if(mask_priorities)
		  begin
		     
		     wire [0:num_priorities*num_ports-1] gnt_mask_pr;
		     c_mat_mult
		       #(.dim1_width(num_priorities),
			 .dim2_width(1),
			 .dim3_width(num_ports),
			 .prod_op(`BINARY_OP_AND),
			 .sum_op(`BINARY_OP_OR))
		     gnt_mask_pr_mmult
		       (.input_a(sel_pr),
			.input_b({num_ports{1'b1}}),
			.result(gnt_mask_pr));
		     
		     assign gnt_pr = gnt_intm_pr & gnt_mask_pr;
		     assign gnt = gnt_intm;
		     
		  end
		else
		  begin
		     
		     assign gnt_pr = gnt_intm_pr;
		     
		     c_binary_op
		       #(.num_ports(num_priorities),
			 .width(num_ports),
			 .op(`BINARY_OP_OR))
		     gnt_or
		       (.data_in(gnt_intm_pr),
			.data_out(gnt));
		     
		  end
		
	     end
	   
	end
      
   endgenerate
   
endmodule
