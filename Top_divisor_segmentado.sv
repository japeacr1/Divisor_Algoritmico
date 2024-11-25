`timescale 1ns/1ps
module Top_divisor_segmentado();
    parameter tamanyo = 32;
    logic CLK;
    logic RSTa;

    // InstanciaciÃ¯Â¿Â½n de la interface
    Interface_if #(tamanyo) test_if(.reloj(CLK),.reset(RSTa));

    // InstanciaciÃ¯Â¿Â½n del diseÃ¯Â¿Â½o (DUT)
    Divisor_Algoritmico_Seg Duv_seg (.bus_seg(test_if));

    // InstanciaciÃ¯Â¿Â½n del program
    estimulos #(tamanyo) estim1(test_if);

    // GeneraciÃ¯Â¿Â½n del reloj (CLK)
    always begin
        CLK = 1'b0; #5;
        CLK = 1'b1; #5;
    end 

   // Reseteo
    initial begin
	    RSTa = 1'b1;
        #10 RSTa = 1'b0;
        #10 RSTa = 1'b1;
    end

    // Volcado de valores para el visualizador
    initial begin
        $dumpfile("divisor.vcd");
        $dumpvars(1, Top_divisor_segmentado.Duv_seg.divisor_seg_duv);
    end

endmodule

interface  Interface_if #(parameter tamanyo = 32) (input bit reloj, input bit reset);
    logic Start;
    logic Done;
    logic signed [tamanyo-1:0] Num;
    logic signed [tamanyo-1:0] Den;
    logic signed [tamanyo-1:0] Coc;
    logic signed [tamanyo-1:0] Res;

    // Clocking block para monitoreo 
    clocking md @(posedge reloj);
		default input #1ns output #1ns;
        input  Num, Den, Coc, Res, Start, Done;
    endclocking: md;

 
    // Clocking block para generaciÃ¯Â¿Â½n de estÃ¯Â¿Â½mulos 
    clocking sd @(posedge reloj);
		default input #2ns output #2ns;
        input Coc, Res, Done;		
		output Num, Den, Start;
    endclocking: sd;
 
  modport monitor (clocking md);
  modport test (clocking sd);
  modport Duv_seg (
      input     reloj,
      input     reset,
      input     Start,
      input     Num,
      input     Den,
      output    Done,
      output    Coc,
      output    Res
	);

endinterface

// Programa para la instanciaciÃ¯Â¿Â½n de mÃ¯Â¿Â½dulos
program estimulos #(parameter tamanyo = 32)(Interface_if test_if);

    logic signed [tamanyo-1:0] num_rand, den_rand;
    logic signed [tamanyo-1:0] target_Coc, target_Res;
    logic signed [tamanyo-1:0] pretarget_Coc, pretarget_Res;
    logic signed [tamanyo-1:0] observado_Coc, observado_Res;

    // Colas para almacenar los valores esperados
    logic signed [tamanyo-1:0] target_Coc_cola[$];
    logic signed [tamanyo-1:0] target_Res_cola[$];

initial  begin
	$display("Iniciando simulacion...");
	test_if.Start = 1'b0;
	repeat (10) begin
	// Caso 1: Numerador y Denominador positivos
	num_rand = $urandom_range(0, 2**(tamanyo-1));
	den_rand = $urandom_range(1, 2**(tamanyo-1));
	In(num_rand, den_rand);
    
	// Caso 2: Numerador positivo y Denominador negativo
	num_rand = $urandom_range(0, 2**(tamanyo-1));
	den_rand = -$urandom_range(1, 2**(tamanyo-1));
	In(num_rand, den_rand);
	
	// Caso 3: Numerador negativo y Denominador positivo
	num_rand = -$urandom_range(0, 2**(tamanyo-1));
	den_rand = $urandom_range(1, 2**(tamanyo-1));
	In(num_rand, den_rand);
	
	// Caso 4: Numerador y Denominador negativos
	num_rand = -$urandom_range(0, 2**(tamanyo-1));
	den_rand = -$urandom_range(1, 2**(tamanyo-1));
	In(num_rand, den_rand);
	repeat(4) out();
        end
	$stop;
end

task In(input logic signed [tamanyo-1:0] num, input logic signed [tamanyo-1:0] den);
	   
	$display("input num: %0d, den: %0d", num, den);

	pretarget_Coc = (num / den);
	pretarget_Res = (num % den);

	// Almacenar valores esperados al frente de la cola
	target_Coc_cola.push_front(pretarget_Coc);
	target_Res_cola.push_front(pretarget_Res);

    @(posedge test_if.reloj);
    test_if.sd.Num <= num;
    test_if.sd.Den <= den;

    // Pulso Start
    test_if.sd.Start <= 1'b1;
    @(posedge test_if.reloj);
    @(posedge test_if.reloj);
    test_if.sd.Start <= 1'b0;


endtask
task out();
	// Esperar a que Done se active
   	@(posedge test_if.md.Done);
    // Llamar a la tarea scoreboard
	scoreboard();
endtask
// Tarea para comparar resultados
task scoreboard();

    if ((target_Coc_cola.size()>0) && (target_Res_cola.size()>0)) begin
        target_Coc = target_Coc_cola.pop_back();
	    target_Res = target_Res_cola.pop_back();
        
        observado_Coc = test_if.md.Coc;
        observado_Res = test_if.md.Res;
        $display("output coc: %0d, res: %0d", observado_Coc, observado_Res);

        // Aserciones para verificar resultados
        assert (observado_Coc == target_Coc) 
            else $error("Error en Coc: esperado %0d, recibido %0d", target_Coc, observado_Coc);
        assert (observado_Res == target_Res) 
            else $error("Error en Res: esperado %0d, recibido %0d", target_Res, observado_Res);   
    end
endtask

endprogram