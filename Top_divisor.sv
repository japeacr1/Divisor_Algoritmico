`timescale 1ns/1ps
interface DivInterface #(parameter tamanyo = 32) ();
    logic CLK;
    logic RSTa;
    logic Start;
    logic Done;
    logic [tamanyo-1:0] Num;
    logic [tamanyo-1:0] Den;
    logic [tamanyo-1:0] Coc;
    logic [tamanyo-1:0] Res;
endinterface

program estimulos (DivInterface div_if);
  parameter tamanyo = 32;
  logic [tamanyo-1:0] target_Coc;
  logic [tamanyo-1:0] target_Res;
  
  logic [tamanyo-1:0] num_rand;   
  logic [tamanyo-1:0] den_rand;
  
  
   // RSTa
  initial begin
    #100 div_if.RSTa = 1'b1;
    #100 div_if.RSTa = 1'b0;
    #100 div_if.RSTa = 1'b1;
  end


  // Inicialización general
  initial begin
    div_if.Start = 1'b0;
    repeat (20) begin
      // Generar números aleatorios para Numerador y Denominador
  	num_rand = $urandom_range(1, 2**(tamanyo-1));
  	den_rand = $urandom_range(1, 2**(tamanyo-1));
        operacion_division(num_rand, den_rand);
    end
  end

  // Operación básica para realizar la división
  task operacion_division;
    input [tamanyo-1:0] num;  // Numerador
    input [tamanyo-1:0] den;  // Denominador
  begin
    div_if.Start = 1'b0;
    repeat (3) @(posedge div_if.CLK);
    //div_if.Start = 1'b1;
    @(posedge div_if.CLK)
    div_if.Num = num;
    div_if.Den = den;
    
    // Calcular el cociente esperado para comparación
	 
     target_Coc = num / den;
	 
     target_Res = num % den;
    
    @(posedge div_if.CLK);
    div_if.Start = 1'b1;

    @(posedge div_if.CLK);
    div_if.Start = 1'b0;

    // Esperar hasta que Done se active
    @(posedge div_if.Done);
    
    @(posedge div_if.CLK);
    
    // Verificar si el cociente calculado coincide con el esperado
    assert (div_if.Coc == target_Coc) else $error("Error en la operación: la división de %0d / %0d debería dar %0d, pero se obtuvo %0d", num, den, target_Coc, div_if.Coc);
	 assert (div_if.Coc == target_Res) else $error("Error en la operación: la división de %0d / %0d debería dar %0d, pero se obtuvo %0d", num, den, target_Res, div_if.Coc);
  end
  endtask
  
endprogram



module Top_divisor();
parameter tamanyo = 32;
 DivInterface #(tamanyo) div_if();


//instanciación del disenyo                  
Divisor_Algoritmico i1 (
// port map - connection between master ports and signals/registers   
	.CLK(div_if.CLK),
	.RSTa(div_if.RSTa),
	.Start(div_if.Start),
	.Num(div_if.Num),
	.Den(div_if.Den),
	.Coc(div_if.Coc),
	.Res(div_if.Res),
	.Done(div_if.Done)
);

// CLK
always
begin
	div_if.CLK = 1'b0;
	div_if.CLK = #50 1'b1;
	#50;
end 



 //instanciacion del program  
  estimulos #(.tamanyo(tamanyo)) estim1 (div_if);  
  

//volcado de valores para el visualizados
  
initial begin
  $dumpfile("divisor.vcd");
  $dumpvars(1,Top_divisor);
end
  
endmodule