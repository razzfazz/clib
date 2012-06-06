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
// converter from one-hot to thermometer-style encoding
//==============================================================================

module c_one_hot_therm_conv
  (data_in, data_out);
   
   // number of input ports (i.e., decoded width)
   parameter num_ports = 8;
   
   // one-hot input data
   input [0:num_ports-1] data_in;
   
   // thermometer-style encoded output data
   output [0:num_ports-1] data_out;
   wire [0:num_ports-1]   data_out;
   
   generate
      
      if(num_ports == 1)
	assign data_out = data_in;
      else if(num_ports > 1)
	begin
	   
	   assign data_out[0] = data_in[0];
	   
	   genvar idx;
	   for(idx = 1; idx < num_ports; idx = idx + 1)
	     begin:idxs
		assign data_out[idx] = |data_in[0:idx];
	     end
	   
        end
      
   endgenerate
   
endmodule
