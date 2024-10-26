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
	    
	    logic start_control = 0; // Variable para evitar duplicados
	    while (1) begin
	        @(mports.md);
	        if (mports.md.Start) 
		  if (!start_control) begin // Solo guardar si start_control es 0
	            pretarget_coc = mports.md.Num / mports.md.Den;
	            pretarget_res = mports.md.Num % mports.md.Den;
	            cola_target_coc.push_front(pretarget_coc);
	            cola_target_res.push_front(pretarget_res);
//	            $display("Guardamos esto en la cola - Cociente: %d, Residuo: %d", pretarget_coc, pretarget_res);
		    start_control = 1; // Cambia el estado para evitar duplicados
	            end 
		else begin
                        start_control = 0; // Reiniciar el flag cuando Start se desactiva
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
//	                $display("Valores de la cola - Cociente: %d, Residuo: %d", target_coc, target_res);
//	                $display("Num: %d, Den: %d, Esperado Coc: %d, Observado Coc: %d", mports.md.Num, mports.md.Den, target_coc, observado_Coc);
//	                $display("Num: %d, Den: %d, Esperado Res: %d, Observado Res: %d", mports.md.Num, mports.md.Den, target_res, observado_Res);
	                assert (observado_Coc == target_coc) else $error("Cociente incorrecto: Esperado %d, Observado %d", target_coc, observado_Coc);
	                assert (observado_Res == target_res) else $error("Residuo incorrecto: Esperado %d, Observado %d", target_res, observado_Res);
	        end
	    end
	endtask
	
    endclass


    class environment;

        virtual Interface_if.test testar_ports;
        virtual Interface_if.monitor monitorizar_ports;

        covergroup valores @(monitorizar_ports.md);
	    // Coverpoint para Num
	    cp1:coverpoint monitorizar_ports.md.Num { 
//	        bins entre_min_y_0[] = {[-2**(tamanyo-1):-1]};        // Captura todos los números negativos
	        bins zero[] = {0};                 	     // Captura el cero
	        bins entre_1_y_100[] = {[1:100]};      	     // Captura números del 1 al 100
//	        bins entre_100_y_max[] = {[101:2**(tamanyo-1)]};  // Captura números mayores que 100
//		ignore_bins ignorados[] = {[2**(tamanyo):$]};
	    }
	
	    // Coverpoint para Den
	    cp2:coverpoint monitorizar_ports.md.Den {
//	        bins entre_min_y_0[] = {[-2**(tamanyo-1):-1]};         // Captura todos los números negativos
	        illegal_bins zero[] = {0};                            // Captura el cero
	        bins entre_1_y_100[] = {[1:100]};                // Captura números del 1 al 100
//	        bins entre_100_y_max[] = {[101:2**(tamanyo-1)]};   // Captura números mayores que 100
//		ignore_bins ignorados[] = {[2**(tamanyo):$]};
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
   	    valores = new(); // Instancia del covergroup

	    end
        endfunction

        task muestrear;
            fork
                sb.monitor_input;
                sb.monitor_output;
            join_none
        endtask

        task prueba_random;
   	 int max_iteraciones = 100; // Define un límite
   	 int iteraciones = 0;
            while (iteraciones < max_iteraciones) begin
                assert (busInst.randomize()) else $fatal("Randomization failed");
//		$display("Num_rand: %0d, Den_rand: %0d", busInst.num_rand, busInst.den_rand);
                testar_ports.sd.Num <= busInst.num_rand;
                testar_ports.sd.Den <= busInst.den_rand;

                valores.sample(); // Muestreo para la cobertura    
         
		@(testar_ports.sd);

   		testar_ports.sd.Start <= 1'b1; // Activa `Start` 
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
	$display("Acabando prueba aleatoria...");
        $stop;
    end
endprogram
