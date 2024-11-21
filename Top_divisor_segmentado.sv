`timescale 1ns/1ps
module Top_divisor_segmentado();
    parameter tamanyo = 32;
    logic CLK;
    logic RSTa;

    // Instanciaciï¿½n de la interface
    Interface_if #(tamanyo) test_if(.reloj(CLK),.reset(RSTa));

    // Instanciaciï¿½n del diseï¿½o (DUT)
    Divisor_Algoritmico_Seg Duv (.bus(test_if));

    // Instanciaciï¿½n del program
    estimulos #(tamanyo) estim1(test_if);

    // Generaciï¿½n del reloj (CLK)
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
        $dumpvars(1, Top_divisor_segmentado.Duv.divisor_seg_duv);
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

 
    // Clocking block para generaciï¿½n de estï¿½mulos 
    clocking sd @(posedge reloj);
		default input #2ns output #2ns;
        input Coc, Res, Done;		
		output Num, Den, Start;
    endclocking: sd;
 
  modport monitor (clocking md);
  modport test (clocking sd);
  modport Duv (
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

// Programa para la instanciaciï¿½n de mï¿½dulos
program estimulos #(parameter tamanyo = 32)(Interface_if test_if);

    logic signed [tamanyo-1:0] num_rand, den_rand;
    logic signed [tamanyo-1:0] target_Coc, target_Res;
    logic signed [tamanyo-1:0] pretarget_Coc, pretarget_Res;
    logic signed [tamanyo-1:0] observado_Coc, observado_Res;

    // Colas para almacenar los valores esperados
    logic signed [tamanyo-1:0] target_Coc_cola[$];
    logic signed [tamanyo-1:0] target_Res_cola[$];
    bit assert_coc_passed;
    bit assert_res_passed;

initial  begin
	$display("Iniciando simulaciï¿½n...");
	test_if.Start = 1'b0;
	repeat (10) begin
	// Caso 1: Numerador y Denominador positivos
	num_rand = $urandom_range(0, 2**(tamanyo-1));
	den_rand = $urandom_range(1, 2**(tamanyo-1));
	realizar_prueba(num_rand, den_rand);
    
	// Caso 2: Numerador positivo y Denominador negativo
	num_rand = $urandom_range(0, 2**(tamanyo-1));
	den_rand = -$urandom_range(1, 2**(tamanyo-1));
	realizar_prueba(num_rand, den_rand);
	
	// Caso 3: Numerador negativo y Denominador positivo
	num_rand = -$urandom_range(0, 2**(tamanyo-1));
	den_rand = $urandom_range(1, 2**(tamanyo-1));
	realizar_prueba(num_rand, den_rand);
	
	// Caso 4: Numerador y Denominador negativos
	num_rand = -$urandom_range(0, 2**(tamanyo-1));
	den_rand = -$urandom_range(1, 2**(tamanyo-1));
	realizar_prueba(num_rand, den_rand);
        end
	$stop;
end

task realizar_prueba(input logic signed [tamanyo-1:0] num, input logic signed [tamanyo-1:0] den);
	   
    $display("Testing num: %0d, den: %0d", num, den);

	pretarget_Coc = (num / den);
	pretarget_Res = (num % den);

    @(posedge test_if.reloj);
    test_if.sd.Num <= num;
    test_if.sd.Den <= den;

    // Pulso Start
    test_if.sd.Start <= 1'b1;
    @(posedge test_if.reloj);
    @(posedge test_if.reloj);
    test_if.sd.Start <= 1'b0;

	// Esperar a que Done se active
   	@(posedge test_if.md.Done);

    //pretarget_Coc = test_if.md.Coc_ref;
    //pretarget_Res = test_if.md.Res_ref;

	// Almacenar valores esperados al frente de la cola
	target_Coc_cola.push_front(pretarget_Coc);
	target_Res_cola.push_front(pretarget_Res);
    
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

        assert_coc_passed=(observado_Coc == target_Coc);
        assert_res_passed=(observado_Res == target_Res);

        display_info(num_rand, den_rand, pretarget_Coc, pretarget_Res, target_Coc, target_Res, observado_Coc, observado_Res, assert_coc_passed, assert_res_passed);
        // Aserciones para verificar resultados
        assert (assert_coc_passed) 
            else $error("Error en Coc: esperado %0d, recibido %0d", target_Coc, observado_Coc);
        assert (assert_res_passed) 
            else $error("Error en Res: esperado %0d, recibido %0d", target_Res, observado_Res);   
    end
endtask

    task display_info(   //esto solo lo uso para verlo en vscode luego antes de entregar lo borrare
    input int Num, Den, pretarget_coc, pretarget_res,
    target_coc, target_res, observado_Coc, observado_Res,
    input bit assert_coc_passed, assert_res_passed);
    automatic string green = "\033[32m";
    automatic string red   = "\033[31m";
    automatic string reset = "\033[0m";

    $display("|                                                                              |");
    $display("|Numeros asignados a las duv --> Num:  %-11d     , Den: %-11d      |", Num, Den);
    $display("|                                                                              |");
    $display("|Guardamos ideal en la cola ---> Cociente:  %-11d, Residuo:  %-11d |", pretarget_coc, pretarget_res);
    $display("|Sacamos ideal de la cola -----> Cociente:  %-11d, Residuo:  %-11d |", target_coc, target_res);
    $display("|Valores a comparar -----------> ideal_Coc: %-11d, real_Coc: %-11d |", target_coc, observado_Coc);
    $display("|Valores a comparar -----------> ideal_Res: %-11d, real_Res: %-11d |", target_res, observado_Res);
    $display("|Assert------------------------> Cociente: %s%s%s      , Residuo: %s%s%s       |", assert_coc_passed ? green : red, assert_coc_passed ? "PASSED" : "FAILED", reset,
                                                                                                    assert_res_passed ? green : red, assert_res_passed ? "PASSED" : "FAILED", reset);
endtask

endprogram
