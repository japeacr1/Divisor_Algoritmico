// --------------------------------------------------------------------
// Universitat Politecnica de Valencia
// Escuela Tecnica Superior de Ingenieros de Telecomunicacion
// --------------------------------------------------------------------
// Integracion de Sistemas Digitales
// Curso 2022 - 2023
// --------------------------------------------------------------------
// Nombre del archivo: divisor_parallel.sv
//
// Descripcion: Este codigo SystemVerilog implementa un multiplicador
// de tamanyo parametrizable pero paralelo para que los alumnos puedan empezar a testear r�p�do
//
// --------------------------------------------------------------------
// Versi�n: V1.0 | Fecha Modificaci�n: 01/10/2022
//
// Autores: Rafael Gadea
// --------------------------------------------------------------------
module Top_Duv_ref #(parameter tamanyo=32)(Interface_if.Duv_ref bus_ref) ; 

Divisor_Algoritmico_pruebas #(tamanyo) divisor(
  .CLK   (bus_ref.reloj),     
  .RSTa  (bus_ref.reset),     
  .Start (bus_ref.Start),
  .Num   (bus_ref.Num),
  .Den   (bus_ref.Den),   
  .Coc   (bus_ref.Coc_ref),
  .Res   (bus_ref.Res_ref), 
  .Done  (bus_ref.Done_ref)    
  );

endmodule

module Divisor_Algoritmico_pruebas
#(parameter tamanyo=32)
(input CLK,
input RSTa,
input Start,
input logic [tamanyo-1:0] Num,
input logic [tamanyo-1:0] Den,

output logic [tamanyo-1:0] Coc,
output logic [tamanyo-1:0] Res,
output Done);


logic signed [tamanyo-1:0] Coc_temp;
logic signed [tamanyo-1:0] Res_temp;
logic signed [tamanyo-1:0] Coc_temp2;
logic signed [tamanyo-1:0] Res_temp2;
logic signed [tamanyo-1:0] Num_temp;
logic signed [tamanyo-1:0] Den_temp;
logic [2*tamanyo+1:0] END_MULT_aux;
logic [2*tamanyo+1:0] [tamanyo-1:0] Coc_aux;
logic [2*tamanyo+1:0] [tamanyo-1:0] Res_aux;

assign Coc_temp=$signed(Num)/$signed(Den);
assign Res_temp=$signed(Num)%$signed(Den);
always_ff @(posedge CLK, negedge RSTa)
if (!RSTa)
  begin
  END_MULT_aux<='0;
    Coc_aux<='0;
    Res_aux<='0;
  end
else 
    begin
      END_MULT_aux<={Start, END_MULT_aux[2*tamanyo+1:1]};
      Coc_temp2=Start?(Coc_temp):'0;
      Res_temp2=Start?(Res_temp):'0;
      Coc_aux<={Coc_temp2, Coc_aux[2*tamanyo+1:1]};
      Res_aux<={Res_temp2, Res_aux[2*tamanyo+1:1]};
    end



assign  Done=END_MULT_aux[0];
assign  Coc=Coc_aux[0];
assign  Res=Res_aux[0];

endmodule