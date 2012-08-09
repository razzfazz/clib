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
// wavefront allocator variant which rotates inputs and outputs based on 
// priority
//==============================================================================

module c_wf_alloc_rot
  (clk, reset, active, req, gnt, update);
   
`include "c_functions.v"
`include "c_constants.v"
   
   // number of input/output ports
   // each input can bid for any combination of outputs
   parameter num_ports = 8;
   
   // when selecting next priority diagonal, skip diagonals without requests
   parameter skip_empty_diags = 0;
   
   // width required to select an individual port
   localparam port_idx_width = clogb(num_ports);
   
   parameter reset_type = `RESET_TYPE_ASYNC;
   
   input clk;
   input reset;
   input active;
   
   // request matrix
   input [0:num_ports*num_ports-1] req;
   
   // grant matrix
   output [0:num_ports*num_ports-1] gnt;
   wire [0:num_ports*num_ports-1] gnt;
   
   // update port priorities
   input update;
   
   wire [0:port_idx_width-1] 	  prio_next;
   
   wire [0:port_idx_width-1] 	  prio_s, prio_q;
   assign prio_s = update ? prio_next : prio_q;
   c_dff
     #(.width(port_idx_width),
       .reset_type(reset_type))
   prioq
     (.clk(clk),
      .reset(reset),
      .active(active),
      .d(prio_s),
      .q(prio_q));
   
   generate
      
      if(skip_empty_diags)
	begin
	   
	   wire [0:num_ports-1] req_on_diag;
	   c_diag_op
	     #(.width(num_ports),
	       .op(`BINARY_OP_OR))
	   req_on_diag_dop
	     (.data_in(req),
	      .data_out(req_on_diag));
	   
	   wire [0:num_ports-1] prio_port;
	   c_decode
	     #(.num_ports(num_ports))
	   prio_port_dec
	     (.data_in(prio_q),
	      .data_out(prio_port));
	   
	   wire [0:num_ports-1] first_diag;
	   c_prefix_arbiter_base
	     #(.num_ports(num_ports))
	   first_diag_pa
	     (.prio_port(prio_port),
	      .req(req_on_diag),
	      .gnt(first_diag));
	   
	   c_encode
	     #(.num_ports(num_ports),
	       .offset(1))
	   prio_next_enc
	     (.data_in(first_diag),
	      .data_out(prio_next));
	   
	end
      else
	begin
	   
	   c_incr
	     #(.width(port_idx_width),
	       .min_value(0),
	       .max_value(num_ports-1))
	   prio_next_incr
	     (.data_in(prio_q),
	      .data_out(prio_next));
	   
	end
      
      wire [0:num_ports*num_ports-1] y;
      
      genvar 			  row;
      for(row = 0; row < num_ports; row = row + 1)
	begin:rows
	   
	   wire [0:num_ports-1] 	req_row;
	   assign req_row = req[row*num_ports:(row+1)*num_ports-1];
	   
	   wire [0:port_idx_width-1] 	current_row;
	   assign current_row = row;
	   
	   wire [0:num_ports-1] 	req_tmp;
	   c_rotate
	     #(.width(num_ports),
	       .rotate_dir(`ROTATE_DIR_RIGHT))
	   req_tmp_rot
	     (.amount(current_row),
	      .data_in(req_row),
	      .data_out(req_tmp));
	   
	   wire [0:num_ports-1] 	req_in;
	   c_rotate
	     #(.width(num_ports),
	       .rotate_dir(`ROTATE_DIR_LEFT))
	   req_in_rot
	     (.amount(prio_q),
	      .data_in(req_tmp),
	      .data_out(req_in));
	   
	   wire [0:num_ports-1] 	x_in, y_in;
	   wire [0:num_ports] 		x_out, y_out;
	   
	   assign x_in = x_out[0:num_ports-1];
	   assign y_in = y[((row+num_ports)%num_ports)*num_ports:
			   ((row+num_ports)%num_ports+1)*num_ports-1];
	   
	   assign x_out = {1'b1, (~y_in | ~req_in) & x_in};
	   assign y_out = {1'b1, (~x_in | ~req_in) & y_in};
	   
	   wire [0:num_ports-1] 	gnt_out;
	   assign gnt_out = req_in & x_in & y_in;
	   
	   assign y[((row+num_ports+1)%num_ports)*num_ports:
		    ((row+num_ports+1)%num_ports+1)*num_ports-1]
		    = y_out[0:num_ports-1];
	   
	   wire [0:num_ports-1] 	gnt_tmp;
	   c_rotate
	     #(.width(num_ports),
	       .rotate_dir(`ROTATE_DIR_RIGHT))
	   gnt_tmp_rot
	     (.amount(prio_q),
	      .data_in(gnt_out),
	      .data_out(gnt_tmp));
	   
	   wire [0:num_ports-1] 	gnt_row;
	   c_rotate
	     #(.width(num_ports),
	       .rotate_dir(`ROTATE_DIR_LEFT))
	   gnt_row_rot
	     (.amount(current_row),
	      .data_in(gnt_tmp),
	      .data_out(gnt_row));
	   
	   assign gnt[row*num_ports:(row+1)*num_ports-1] = gnt_row;
	   
	end
      
   endgenerate
   
endmodule
