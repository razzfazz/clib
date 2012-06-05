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
// priority encoder (port 0 has highest priority)
//==============================================================================

module c_prio_enc
  (data_in, data_out);
   
`include "c_functions.v"
   
   // number of input ports (i.e., decoded width)
   parameter num_ports = 8;
   
   localparam width = clogb(num_ports);
   
   // one-hot input data
   input [0:num_ports-1] data_in;
   
   // binary encoded output data
   output [0:width-1] 	 data_out;
   wire [0:width-1] 	 data_out;
   
   wire [0:num_ports-1]  data_intm;
   c_lod
     #(.width(num_ports),
       .num_priorities(1))
   lod
     (.data_in_pr(data_in),
      .data_out_pr(data_intm),
      .data_out(),
      .mask_out());
   
   c_encode
     #(.num_ports(num_ports))
   enc
     (.data_in(data_intm),
      .data_out(data_out));
   
endmodule
