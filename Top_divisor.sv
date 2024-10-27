`timescale 1ns/1ps

// Módulo superior
module Top_divisor();
    parameter tamanyo = 32;
    logic CLK;
    logic RSTa;

    // Instanciación de la interfaz
    Interface_if #(tamanyo) test_if(.reloj(CLK), .reset(RSTa));

    // Instanciación del diseño (DUT)
    Divisor_Algoritmico Duv (.bus(test_if));

    // Instanciación del programa de estímulos
    estimulos #(tamanyo) estim1(.testar(test_if),.monitorizar(test_if));

    // Generación del reloj (CLK)
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
        $dumpvars(1, Top_divisor.Duv.divisor_duv.Coc);
        $dumpvars(1, Top_divisor.Duv.divisor_duv.Res);
    end
endmodule

// Definición de la interfaz/////////////////////////////////////////////////////////////////////////////////////////
interface Interface_if #(parameter tamanyo = 32) (input bit reloj, input bit reset);
    logic Start;
    logic Done;
    logic signed [tamanyo-1:0] Num;
    logic signed[tamanyo-1:0] Den;
    logic signed[tamanyo-1:0] Coc;
    logic signed[tamanyo-1:0] Res;

    // Clocking block para monitoreo 
    clocking md @(posedge reloj);
        input #1ns Num;
        input #1ns Den;
        input #1ns Coc;
        input #1ns Res;
        input #1ns Start;
        input #1ns Done;
    endclocking: md;

    // Clocking block para generación de estímulos 
    clocking sd @(posedge reloj);
        input  #2ns Coc;
        input  #2ns Res;
        input  #2ns Done;
        output #2ns Num;
        output #2ns Den;
        output #2ns Start;
    endclocking: sd;

    modport monitor (clocking md);
    modport test (clocking sd);
    modport duv (
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

// Paquete de verificación//////////////////////////////////////////////////////////////////////////////////////////
package utilidades_verificacion;
    parameter tamanyo = 32;

    class RCSG;
        rand logic signed [tamanyo-1:0] num_rand;
        rand logic signed [tamanyo-1:0] den_rand;
        constraint den_valido { den_rand != 0; }
    endclass

    class Scoreboard;
 	logic signed[tamanyo-1:0] cola_target_coc [$];
	logic signed[tamanyo-1:0] cola_target_res [$];
	logic signed[tamanyo-1:0] pretarget_coc, pretarget_res;
        logic signed[tamanyo-1:0] target_coc, target_res;
    	logic signed[tamanyo-1:0] observado_Coc, observado_Res;

        virtual Interface_if.monitor mports;

	

        function new(virtual Interface_if.monitor mpuertos);
            this.mports = mpuertos;
	   
        endfunction


	task monitor_input;    
	    logic start_control = 1;      // Variable para evitar duplicados
	    while (1) begin
	        @(mports.md);
	        if (mports.md.Start) 
		  if (start_control) begin // Solo guardar si start_control es 0
	            pretarget_coc = mports.md.Num / mports.md.Den;
	            pretarget_res = mports.md.Num % mports.md.Den;
	            cola_target_coc.push_front(pretarget_coc);
	            cola_target_res.push_front(pretarget_res);
//	            $display("Guardamos esto en la cola -Cociente: %d, Residuo: %d", pretarget_coc, pretarget_res);
		    start_control = 0;     // Cambia el estado para evitar duplicados
	            end 
		else begin
                       start_control = 1; // Reiniciar el flag cuando Start se desactiva
                     end  
		end   
	endtask
	
	task monitor_output;
	    while (1) begin
	        @(mports.md);
	        if (mports.md.Done) begin
                    target_coc = cola_target_coc.pop_back();
                    target_res = cola_target_res.pop_back();
              	    observado_Coc = mports.md.Coc;
              	    observado_Res = mports.md.Res;
//                  $display("Valores de la cola        -Cociente: %d, Residuo: %d", target_coc, target_res);
//	            $display("Num: %d, Den: %d, Esperado Coc: %d, Observado Coc: %d", mports.md.Num, mports.md.Den, target_coc, observado_Coc);
//	            $display("Num: %d, Den: %d, Esperado Res: %d, Observado Res: %d", mports.md.Num, mports.md.Den, target_res, observado_Res);
                    assert (observado_Coc == target_coc) else $error("Cociente incorrecto: Esperado %d, Observado %d", target_coc, observado_Coc);
                    assert (observado_Res == target_res) else $error("Residuo incorrecto: Esperado %d, Observado %d", target_res, observado_Res);
	        end
	    end
	endtask
	
    endclass


    class environment;

        virtual Interface_if.test testar_ports;
        virtual Interface_if.monitor monitorizar_ports;

	// Covergroup para valores de Num
	covergroup valores_num @(monitorizar_ports.md);
	
	    // Coverpoint para valores positivos pequeños
	    Num_Pos_small: coverpoint monitorizar_ports.md.Num {                
	        bins zero[] = {0};                                  // Captura el cero
	        bins range_1_to_100[] = {[1:100]};                   // Captura números del 1 al 100
	        bins range_101_to_1000[] = {[101:1000]};             // Captura números del 101 al 1000
	    }
	
	    // Coverpoint para valores positivos grandes
	    Num_Pos_Large: coverpoint monitorizar_ports.md.Num {                
	        bins range_1000_to_1M[] = {[1000:1000000]};          // Captura números entre 1000 y 1 millón
//	        bins range_1M_to_max[] = {[1000001:2147483647]};     // Captura números mayores que 1 millón
	    }
	
	    // Coverpoint para valores negativos pequeños
	    Num_Neg_Small: coverpoint monitorizar_ports.md.Num { 
	        bins range_neg_1000_to_neg_100[] = {[-1000:-100]};   // Captura números de -1000 a -100
	        bins range_neg_100_to_neg_1[] = {[-100:-1]};         // Captura números de -100 a -1
	    }
	// Coverpoint para valores negativos grandes
	    Num_Neg_Large: coverpoint monitorizar_ports.md.Num {                
	        bins range_neg_1000_to_neg_1M[] = {[-1000000:-1000]};  // Captura números entre  -1 millón y -1000
//	        bins range_neg_max_to_neg_1M[] = {[-2147483647:-1000001]};     // Captura números mayores que -1 millón
	    }

	endgroup

	// Covergroup para valores de Den
	covergroup valores_den @(monitorizar_ports.md);
	
	    // Coverpoint para valores positivos pequeños
	    Den_Pos_Small: coverpoint monitorizar_ports.md.Den {
	        illegal_bins zero[] = {0};                           // Considera el cero como valor ilegal
	        bins range_1_to_100[] = {[1:100]};                   // Captura números del 1 al 100
	        bins range_101_to_1000[] = {[101:1000]};             // Captura números del 101 al 1000
	    }
	
	    // Coverpoint para valores positivos grandes
	    Den_Pos_Large: coverpoint monitorizar_ports.md.Den {
	        bins range_1000_to_1M[] = {[1000:1000000]};          // Captura números entre 1000 y 1 millón
//	        bins range_1M_to_max[] = {[1000001:2147483647]};     // Captura números mayores que 1 millón
	    }
	
	    // Coverpoint para valores negativos pequeños
	    Den_Neg_Small: coverpoint monitorizar_ports.md.Den { 
	        bins range_neg_1000_to_neg_100[] = {[-1000:-100]};   // Captura números de -1000 a -100
	        bins range_neg_100_to_neg_1[] = {[-100:-1]};         // Captura números de -100 a -1
	    }
	// Coverpoint para valores negativos grandes
	    Den_Neg_Large: coverpoint monitorizar_ports.md.Den {                
	        bins range_neg_1000_to_neg_1M[] = {[-1000000:-1000]};  // Captura números entre  -1 millón y -1000
//	        bins range_neg_max_to_neg_1M[] = {[-2147483647:-1000001]};     // Captura números mayores que -1 millón
	    }
	
	endgroup

	

	//declaraciones de objetos
        Scoreboard sb;
        RCSG busInst;


        function new(virtual Interface_if.test ports, virtual Interface_if.monitor mports);
            begin
	    testar_ports = ports;
            monitorizar_ports = mports;

	    //instanciación objetos
	    busInst = new;               //construimos la clase de valores random
            sb = new(monitorizar_ports); //construimos el scoreboard      
   	    valores_num = new();             // Instancia del covergroup
	    valores_den = new();             // Instancia del covergroup
	    end
        endfunction

        task muestrear;
            fork
                sb.monitor_input;
                sb.monitor_output;
            join_none
        endtask

        task prueba_random;
   	 int max_iteraciones = 10000; // Define un límite
   	 int iteraciones = 0;
            while (iteraciones < max_iteraciones) begin
                assert (busInst.randomize()) else $fatal("Randomization failed");
//		$display("Num_rand: %0d, Den_rand: %0d", busInst.num_rand, busInst.den_rand);
                testar_ports.sd.Num <= busInst.num_rand;
                testar_ports.sd.Den <= busInst.den_rand;

                valores_num.sample();                  // Muestreo para la cobertura    
                valores_den.sample();                  // Muestreo para la cobertura    
		@(testar_ports.sd);

   		testar_ports.sd.Start <= 1'b1;     // Activa `Start` 
		@(testar_ports.sd);
    		#10 testar_ports.sd.Start <= 1'b0; // Baja `Start` para indicar solo un pulso

                @(negedge testar_ports.sd.Done);
		iteraciones++;
            end
        endtask


    endclass

endpackage

// Programa para la instanciación de módulos//////////////////////////////////////////////////////////////////////////////
program estimulos #(parameter tamanyo = 32) (Interface_if.test testar, Interface_if.monitor monitorizar);
    utilidades_verificacion::environment casos = new(testar, monitorizar);
   
    initial begin
        $display("Iniciando prueba aleatoria...");
	casos.muestrear;
        casos.prueba_random;
	$display("Prueba aleatoria acabada.  ;)");
        $stop;
    end
endprogram
