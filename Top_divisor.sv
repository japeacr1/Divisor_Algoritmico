`timescale 1ns / 1ps

module Top_divisor();
    parameter tamanyo = 32;
    logic CLK;
    logic RSTa;

    // Instanciacion de la interfaz
    Interface_if #(tamanyo) test_if(.reloj(CLK), .reset(RSTa));

    // Instanciacion del diseño (DUV)
//    Divisor_Algoritmico #(tamanyo) Duv (.bus(test_if));
	Divisor_Algoritmico_Seg #(tamanyo) Duv (.bus(test_if));

	// Instanciacion del diseño de referencia (Duv_ref)
	Divisor_Algoritmico_pruebas #(tamanyo) Duv_ref (.bus(test_if));

    // Instanciacion del programa de estimulos
    estimulos #(tamanyo) estim1(.testar(test_if),.monitorizar(test_if));

    // Generacion del reloj (CLK)
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
        $dumpvars(1, Top_divisor.Duv.divisor_seg_duv);
    end
endmodule

// Interfaz de interconerxion /////////////////////////////////////////////////////////////////////////////////////////
interface Interface_if #(parameter tamanyo = 32) (input bit reloj, input bit reset);
    logic Start;
    logic Done;
    logic signed [tamanyo-1:0] Num;
    logic signed [tamanyo-1:0] Den;
    logic signed [tamanyo-1:0] Coc;
    logic signed [tamanyo-1:0] Res;


	logic Done_ref;
    logic signed [tamanyo-1:0] Coc_ref,Res_ref;
    logic signed [tamanyo-1:0] Num_ref,Den_ref;
    // Clocking block para monitoreo 
    clocking md @(posedge reloj);
        input #1ns Num;
        input #1ns Den;
        input #1ns Coc;
        input #1ns Res;
        input #1ns Start;
        input #1ns Done;

		output #1ns Num_ref;
        output #1ns Den_ref;
        input #1ns Done_ref;
        input #1ns Coc_ref;
        input #1ns Res_ref;	
    endclocking: md;

    // Clocking block para generacion de estimulos 
    clocking sd @(posedge reloj);
        input #2ns Coc;
        input #2ns Res;
        input #2ns Done;
		output #2ns Num;
		output #2ns Den;
		output #2ns Start;

		input #2ns Done_ref;
        input #2ns Coc_ref;
        input #2ns Res_ref;	
        output #2ns Num_ref;
        output #2ns Den_ref;
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
    modport Duv_ref (
        input     reloj,
        input     reset,
        input     Start,
        input     Num_ref,
        input     Den_ref,
        output    Done_ref,
        output    Coc_ref,
        output    Res_ref
    );	
endinterface

// Paquete de verificacion//////////////////////////////////////////////////////////////////////////////////////////
package utilidades_verificacion;

    parameter tamanyo = 32;

    class RCSG;
        randc logic signed [tamanyo-1:0] num_rand;
        randc logic signed [tamanyo-1:0] den_rand;

        constraint den_valido { den_rand != 0; }
    	constraint num_constraint {
			num_rand inside {[-2147483647:2147483647]};
        	num_rand dist {
            	[-100 : 100] := 30,
            	[-1000 : -100] := 1, [100 : 1000] := 1,
            	[-10000 : -1000] := 1, [1000 : 10000] := 1,
            	[-100000 : -10000] := 1, [10000 : 100000] := 1,
            	[-1000000 : -100000] := 0, [100000 : 1000000] := 0,
				[-2147483647 : -1000001] := 0, [1000001 : 2147483647] := 0
			};
    	}

    	constraint den_constraint {
			den_rand inside {[-2147483647:2147483647]};
        	den_rand dist {
            	[-100 : 100] := 30,
            	[-1000 : -100] := 10, [100 : 1000] := 10,
            	[-10000 : -1000] := 10, [1000 : 10000] :=10,
            	[-100000 : -10000] := 5, [10000 : 100000] := 5,
            	[-1000000 : -100000] := 5, [100000 : 1000000] := 5,
				[-2147483647 : -1000001] := 5, [1000001 : 2147483647] := 5
        	};
    	}
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
	    	logic start_control = 1;         // Variable para evitar duplicados
	    	while (1) begin
	        	@(mports.md);
	        	if (mports.md.Start) 
		  			if (start_control) begin // Solo guardar si start_control es 1
	            		pretarget_coc = mports.md.Num / mports.md.Den;
	            		pretarget_res = mports.md.Num % mports.md.Den;
	            		cola_target_coc.push_front(pretarget_coc);
	            		cola_target_res.push_front(pretarget_res);
		    			start_control = 0;    // Cambia el estado para evitar duplicados
	            		end 
				else begin
                    start_control = 1;       // Reiniciar el flag cuando Start se desactiva
                end  
			end   
		endtask

		task monitor_input_ref;    
	    	logic start_control = 1;         // Variable para evitar duplicados
	    	while (1) begin
	        	@(mports.md);
	        	if (mports.md.Done_ref) 
		  			if (start_control) begin // Solo guardar si start_control es 1
						pretarget_coc = mports.md.Coc_ref;
						pretarget_res = mports.md.Res_ref;
	            		cola_target_coc.push_front(pretarget_coc);
	            		cola_target_res.push_front(pretarget_res);
		    			start_control = 0;    // Cambia el estado para evitar duplicados
	            		end 
				else begin
                    start_control = 1;       // Reiniciar el flag cuando Start se desactiva
                end  
			end   
		endtask		

		task monitor_output;
			bit assert_coc_passed;
    		bit assert_res_passed;
			while (1) begin
				@(mports.md);
				if (mports.md.Done) begin
					target_coc = cola_target_coc.pop_back();
					target_res = cola_target_res.pop_back();
					observado_Coc = mports.md.Coc;
					observado_Res = mports.md.Res;
					assert_coc_passed = (observado_Coc == target_coc);
					assert_res_passed = (observado_Res == target_res);
					display_info(mports.md.Num, mports.md.Den, mports.md.Num_ref, mports.md.Den_ref, pretarget_coc, pretarget_res, target_coc, target_res, observado_Coc, observado_Res, assert_coc_passed, assert_res_passed);
					assert (assert_coc_passed) else $error("Cociente incorrecto: Esperado %d, Observado %d", target_coc, observado_Coc);
					assert (assert_res_passed) else $error("Residuo incorrecto: Esperado %d, Observado %d", target_res, observado_Res);
				end
			end
		endtask

		task display_info(   //esto solo lo uso para verlo en vscode luego antes de entregar lo borrare
			input int Num, Den, Num_ref, Den_ref, pretarget_coc, pretarget_res,
			target_coc, target_res, observado_Coc, observado_Res,
			input bit assert_coc_passed, assert_res_passed
		);
			string green = "\033[32m";
			string red   = "\033[31m";
			string reset = "\033[0m";

			$display("|                                                                              |");
			$display("|Numeros asignados al duv -----> Num:  %-11d     , Den: %-11d      |", Num, Den);
			$display("|Numeros asignados al duv_ref -> Num:  %-11d     , Den: %-11d      |", Num_ref, Den_ref);
			$display("|                                                                              |");
			$display("|Guardamos ideal en la cola ---> Cociente:  %-11d, Residuo:  %-11d |", pretarget_coc, pretarget_res);
			$display("|Sacamos ideal de la cola -----> Cociente:  %-11d, Residuo:  %-11d |", target_coc, target_res);
			$display("|Valores a comparar -----------> ideal_Coc: %-11d, real_Coc: %-11d |", target_coc, observado_Coc);
			$display("|Valores a comparar -----------> ideal_Res: %-11d, real_Res: %-11d |", target_res, observado_Res);
			$display("|Assert------------------------> Cociente: %s%s%s      , Residuo: %s%s%s       |", assert_coc_passed ? green : red, assert_coc_passed ? "PASSED" : "FAILED", reset,
    																	   							     assert_res_passed ? green : red, assert_res_passed ? "PASSED" : "FAILED", reset);
		endtask
	
    endclass

    class environment;
        virtual Interface_if.test testar_ports;
        virtual Interface_if.monitor monitorizar_ports;

		// Covergroup para valores de Num	
		covergroup valores_num @(monitorizar_ports.md);
	  		zero: coverpoint monitorizar_ports.md.Num {
	     		bins zero[] = {0}; }
	 		rango_100: coverpoint monitorizar_ports.md.Num {
	     		bins rango[] = {[-100:100]}; }
	  		rango_100_a_1K: coverpoint monitorizar_ports.md.Num {
	     		bins rango[] = {[101:1000]}; }
	  		rango_neg_100_a_neg_1K: coverpoint monitorizar_ports.md.Num {
	     		bins rango[] = {[-1000:-101]}; }
	  		rango_1K_a_10K: coverpoint monitorizar_ports.md.Num {
	     		bins rango[] = {[1001:10000]}; }
	  		rango_10K_a_100K: coverpoint monitorizar_ports.md.Num {
	     		bins rango[] = {[10001:100000]}; }
	  		rango_100K_a_1M: coverpoint monitorizar_ports.md.Num {
	     		bins rango[] = {[100001:1000000]};}
	  		rango_neg_1K_a_neg_1M: coverpoint monitorizar_ports.md.Num {
	     		bins rango[] = {[-1000000:-1001]}; }
			rango_1M_a_max: coverpoint monitorizar_ports.md.Num {
				bins rango[] = {[1000001:(2**tamanyo-1)]}; }
			rango_neg_1M_a_min: coverpoint monitorizar_ports.md.Num {
				bins rango[] = {[-(2**tamanyo-1):-1000001]}; }
		endgroup

		// Covergroup para valores de Den
		covergroup valores_den @(monitorizar_ports.md);	
			zero: coverpoint monitorizar_ports.md.Den {
				bins zero[] = {0}; 
				illegal_bins zero1 = {0}; 
			}
			rango_100: coverpoint monitorizar_ports.md.Den {
				bins rango[] = {[-100:100]}; }
			rango_100_a_1K: coverpoint monitorizar_ports.md.Den {
				bins rango[] = {[101:1000]}; }
			rango_neg_100_a_neg_1K: coverpoint monitorizar_ports.md.Den {
				bins rango[] = {[-1000:-101]}; }
			rango_1K_a_10K: coverpoint monitorizar_ports.md.Den {
				bins rango[] = {[1001:10000]}; }
			rango_10K_a_100K: coverpoint monitorizar_ports.md.Den {
				bins rango[] = {[10001:100000]}; }
			rango_100K_a_1M: coverpoint monitorizar_ports.md.Den {
				bins rango[] = {[100001:1000000]};}
			rango_neg_1K_a_neg_1M: coverpoint monitorizar_ports.md.Den {
				bins rango[] = {[-1000000:-1001]}; }
			rango_1M_a_max: coverpoint monitorizar_ports.md.Den {
        		bins rango[] = {[1000001:(2**tamanyo-1)]}; }
			rango_neg_1M_a_min: coverpoint monitorizar_ports.md.Den {
				bins rango[] = {[-(2**tamanyo-1):-1000001]}; }
		endgroup

		// task para imprimir la cobertura
		task print_coverage();  //esto solo lo uso para verlo en vscode luego antes de entregar lo borrare
			$display("+------------------------------------------------------------------------------+");
			$display("|                                Coverage Report                               |");
			$display("+------------------------------------------------------------------------------+");
			$display("|                  Valores             Numerador       Denominador             |");
			$display("|                   total               %6.2f%%         %6.2f%%                |", valores_num.get_coverage(), valores_den.get_coverage());
			$display("|                     0                 %6.2f%%         %6.2f%%                |", valores_num.zero.get_coverage(), valores_den.zero.get_coverage());
			$display("|                [-100:100]             %6.2f%%         %6.2f%%                |", valores_num.rango_100.get_coverage(), valores_den.rango_100.get_coverage());
			$display("|                [101:1000]             %6.2f%%         %6.2f%%                |", valores_num.rango_100_a_1K.get_coverage(), valores_den.rango_100_a_1K.get_coverage());
			$display("|               [-1000:-101]            %6.2f%%         %6.2f%%                |", valores_num.rango_neg_100_a_neg_1K.get_coverage(), valores_den.rango_neg_100_a_neg_1K.get_coverage());
			$display("|               [1001:10000]            %6.2f%%         %6.2f%%                |", valores_num.rango_1K_a_10K.get_coverage(), valores_den.rango_1K_a_10K.get_coverage());
			$display("|              [10001:100000]           %6.2f%%         %6.2f%%                |", valores_num.rango_10K_a_100K.get_coverage(), valores_den.rango_10K_a_100K.get_coverage());
			$display("|             [100001:1000000]          %6.2f%%         %6.2f%%                |", valores_num.rango_100K_a_1M.get_coverage(), valores_den.rango_100K_a_1M.get_coverage());
			$display("|             [-1000000:-1001]          %6.2f%%         %6.2f%%                |", valores_num.rango_neg_1K_a_neg_1M.get_coverage(), valores_den.rango_neg_1K_a_neg_1M.get_coverage());
			$display("|          [1000001:2**tamanyo-1]       %6.2f%%         %6.2f%%                |", valores_num.rango_1M_a_max.get_coverage(), valores_den.rango_1M_a_max.get_coverage());
			$display("|        [-(2**tamanyo-1):-1000001]     %6.2f%%         %6.2f%%                |", valores_num.rango_neg_1M_a_min.get_coverage(), valores_den.rango_neg_1M_a_min.get_coverage());
			$display("+------------------------------------------------------------------------------+");
		endtask

		//declaraciones de objetos
		Scoreboard sb;
		RCSG RandInst;

		function new(virtual Interface_if.test ports, virtual Interface_if.monitor mports);
			begin
				testar_ports = ports;
				monitorizar_ports = mports;

				//instanciacion objetos
				RandInst = new();                    //construimos la clase de valores random
				sb = new(monitorizar_ports);     //construimos el scoreboard      
				valores_num = new();             // Instancia del covergroup
				valores_den = new();             // Instancia del covergroup
			end
		endfunction

        task muestrear;
            fork
				sb.monitor_input;
                //sb.monitor_input_ref;
                sb.monitor_output;
            join_none
        endtask

		task prueba_combinaciones;
			int num[4] = {100, 100, -200, -200};   // Valores de prueba para el Numerador
			int den[4] = { 50, -50,  150, -150};   // Valores de prueba para el Denominador
			string sign_num;
			string sign_den;
			$display("+------------------------------------------------------------------------------+");
			$display("|                          Pruebas combinacionales                             |");
			$display("+------------------------------------------------------------------------------+");
			for (int i = 0; i < 4; i++) begin
				testar_ports.sd.Num <= num[i];
				testar_ports.sd.Den <= den[i];

				monitorizar_ports.md.Num_ref <=  num[i];
                monitorizar_ports.md.Den_ref <=  den[i];

				sign_num = (num[i] > 0) ? "Pos" : "Neg";
				sign_den = (den[i] > 0) ? "Pos" : "Neg";	
				$display("|                                                                              |");
				$display("|Combinacion %s/%s:     Num =%11d, Den =%11d                   |",
							  sign_num, sign_den, testar_ports.sd.Num, testar_ports.sd.Den);

				// Inicia la operacion
				@(testar_ports.sd);
				testar_ports.sd.Start <= 1'b1;
				@(testar_ports.sd);
				#10 testar_ports.sd.Start <= 1'b0;
		
				// Espera a que la operacion termine
				@(negedge testar_ports.sd.Done);
			
			end
			$display("+------------------------------------------------------------------------------+");
		endtask

        task prueba_random;
	 		$display("                                                                                ");
         	$display("+------------------------------------------------------------------------------+");
  	 		$display("|                                Pruebas random                                |");
 	 		$display("+------------------------------------------------------------------------------+");
			for (int i = 0; i < 10; i++) begin
//		   while (valores_num.get_coverage()<10) begin
 
                assert (RandInst.randomize()) else $fatal("Randomization failed in iteration %d",i);
       			
                testar_ports.sd.Num <= RandInst.num_rand;
                testar_ports.sd.Den <= RandInst.den_rand;

                monitorizar_ports.md.Num_ref <= RandInst.num_rand;
                monitorizar_ports.md.Den_ref <= RandInst.den_rand;

                valores_num.sample();                  // Muestreo para la cobertura num    
                valores_den.sample();                  // Muestreo para la cobertura den    

				@(testar_ports.sd);
   				testar_ports.sd.Start <= 1'b1;     // Activa `Start` 
				@(testar_ports.sd);
    			#10 testar_ports.sd.Start <= 1'b0; // Baja `Start` para indicar solo un pulso

                @(negedge testar_ports.sd.Done);
				$display("|iteracion: %d                                                        |",  i);  
            end
			print_coverage();
        endtask

    endclass
	
endpackage

// Program para los estimulos//////////////////////////////////////////////////////////////////////////////
program estimulos #(parameter tamanyo = 32) (Interface_if.test testar, Interface_if.monitor monitorizar);
	utilidades_verificacion::environment casos = new(testar, monitorizar);
   
    initial begin
		$display("+------------------------------------------------------------------------------+");
        $display("|                             Iniciando pruebas...                             |");
		$display("+------------------------------------------------------------------------------+");
		$display("                                                                                ");
		casos.muestrear;
		casos.prueba_combinaciones;
        casos.prueba_random;
		$display("+------------------------------------------------------------------------------+");
		$display("|                               Pruebas acabadas                               |");
		$display("+------------------------------------------------------------------------------+");
        $stop;
    end
endprogram
