`timescale 1ns / 1ps

module Top_divisor_algoritmico();
    parameter tamanyo = 32;
    logic CLK;
    logic RSTa;

    // Instanciacion de la interfaz
    Interface_if #(tamanyo) test_if(.reloj(CLK), .reset(RSTa));

    // Instanciacion del diseño (DUV)
    Divisor_Algoritmico #(tamanyo) Duv (.bus(test_if));

    // Instanciacion del diseño de referencia (Duv_ref)
    Divisor_Algoritmico_pruebas #(tamanyo) Duv_ref (.bus_ref(test_if));

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
        $dumpvars(1, Top_divisor_algoritmico.Duv.divisor_duv.Num);
		$dumpvars(1, Top_divisor_algoritmico.Duv.divisor_duv.Den);
		$dumpvars(1, Top_divisor_algoritmico.Duv.divisor_duv.Coc);
		$dumpvars(1, Top_divisor_algoritmico.Duv.divisor_duv.Res);
		$dumpvars(1, Top_divisor_algoritmico.Duv.divisor_duv.Done);
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

    // Clocking block para monitoreo 
    clocking md @(posedge reloj);
		default input #1ns output #1ns;
        input   Start,Num, Den, Coc, Res, Done;
        input  Coc_ref,Res_ref, Done_ref;	
    endclocking: md;

    // Clocking block para generacion de estimulos 
    clocking sd @(posedge reloj);
		default input #2ns output #2ns;
        input Coc, Res, Done;	
		input  Coc_ref, Res_ref, Done_ref;	
		output Num, Den, Start;
    endclocking: sd;

	default clocking sd;

    modport monitor (clocking md);
    modport test (clocking sd);
    modport Duv (
        input     reloj,
        input     reset,
        input     Start,
        input     Num,
        input     Den,
        output    Coc,
        output    Res,
		output    Done
    );
    modport Duv_ref (
        input     reloj,
        input     reset,
        input     Start,
        input     Num,
        input     Den,
        output    Coc_ref,
        output    Res_ref,
		output    Done_ref
	);	
endinterface

// Paquete de verificacion//////////////////////////////////////////////////////////////////////////////////////////
package utilidades_verificacion;

    parameter tamanyo = 32;

    class RCSG;
        randc logic signed [tamanyo-1:0] num_rand;
        randc logic signed [tamanyo-1:0] den_rand;

        constraint den_valido { den_rand != 0; }
		constraint num_pos { num_rand inside {[0 : 2147483647]};  }
		constraint num_neg { num_rand inside {[-2147483647 : -1]};}
		constraint den_pos { den_rand inside {[1 : 2147483647]};  }
		constraint den_neg { den_rand inside {[-2147483647 : -1]};}
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
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task monitor_input;    
			logic start_control = 1;         // Variable para evitar duplicados
			while (1) begin
				@(mports.md);
				if (mports.md.Start) 
					if (start_control) begin // Solo guardar si start_control es 1
						pretarget_coc = $signed(mports.md.Num) / $signed(mports.md.Den);
						pretarget_res = $signed(mports.md.Num) % $signed(mports.md.Den);

						cola_target_coc.push_front(pretarget_coc);
						cola_target_res.push_front(pretarget_res);

						start_control = 0;    // Cambia el estado para evitar duplicados
						end 
				else begin
					start_control = 1;       // Reiniciar el flag cuando Start se desactiva
				end  
			end   
		endtask	
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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

					assert (assert_coc_passed) else $error("Cociente incorrecto: Esperado %d, Observado %d", target_coc, observado_Coc);
					assert (assert_res_passed) else $error("Residuo incorrecto: Esperado %d, Observado %d", target_res, observado_Res);
				end
			end
		endtask	
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	endclass

	class environment;
		virtual Interface_if.test testar_ports;
		virtual Interface_if.monitor monitorizar_ports;

		// Covergroup para valores de Num	
		covergroup valores @(monitorizar_ports.md);
		num_positivo: coverpoint monitorizar_ports.md.Num {
			wildcard bins num_pos[100] = {32'b0xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx};
		}
		num_negativo: coverpoint monitorizar_ports.md.Num {
			wildcard bins num_neg[100] = {32'b1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx};
		}
		den_positivo: coverpoint monitorizar_ports.md.Den {
			wildcard bins den_pos[100] = {32'b0xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx};
		}
		den_negativo: coverpoint monitorizar_ports.md.Den {
			wildcard bins den_neg[100] = {32'b1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx};
		}


			positivos: cross num_positivo, den_positivo;
			negativos: cross num_negativo, den_negativo;
			pos_neg:   cross num_positivo, den_negativo;
			neg_pos:   cross num_negativo, den_positivo;

		endgroup

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
				valores = new();             // Instancia del covergroup

				//inicializacion de las entradas
				testar_ports.sd.Start <= 1'b0;
		 		testar_ports.sd.Num <= 0;
		 		testar_ports.sd.Den <= 0;
			end
		endfunction

		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task muestrear;
			fork
				sb.monitor_input;
				sb.monitor_output;
			join_none
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task print_coverage();  //esto solo lo uso para verlo en vscode luego antes de entregar lo borrare
			$display("+------------------------------------------------------------------------------+");
			$display("|                                Coverage Report                               |");
			$display("+------------------------------------------------------------------------------+");
			$display("|                  Valores              %6.2f%%                                |", valores.get_coverage());
			$display("|                  num_pos              %6.2f%%                                |", valores.num_positivo.get_coverage());
			$display("|                  den_pos              %6.2f%%                                |", valores.den_positivo.get_coverage());
			$display("|                  num_neg              %6.2f%%                                |", valores.num_negativo.get_coverage());
			$display("|                  den_neg              %6.2f%%                                |", valores.den_negativo.get_coverage());
			$display("+------------------------------------------------------------------------------+");
			$display("|                  num_pos_den_pos      %6.2f%%                                |", valores.positivos.get_coverage());
			$display("|                  num_neg_den_pos      %6.2f%%                                |", valores.negativos.get_coverage());
			$display("|                  num_pos_den_neg      %6.2f%%                                |", valores.pos_neg.get_coverage());
			$display("|                  num_neg_den_neg      %6.2f%%                                |", valores.neg_pos.get_coverage());
			$display("+------------------------------------------------------------------------------+");
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task NumPos_DenPos;
			while (valores.positivos.get_coverage() < 20) begin
			RandInst.num_pos.constraint_mode(1);
			RandInst.num_neg.constraint_mode(0);
			RandInst.den_pos.constraint_mode(1);
			RandInst.den_neg.constraint_mode(0);

			assert (RandInst.randomize()) else $fatal("Error: Fallo en la generación de valores aleatorios");

			testar_ports.sd.Num <= RandInst.num_rand;
			testar_ports.sd.Den <= RandInst.den_rand;

			valores.sample(); // Muestreo para la cobertura num    

			@(testar_ports.sd);
			testar_ports.sd.Start <= 1'b1; // Activa Start 
			@(testar_ports.sd);
			#10 testar_ports.sd.Start <= 1'b0; // Baja Start para indicar solo un pulso

			@(negedge testar_ports.sd.Done); // Espera a que Done sea 0
			end
			print_coverage();
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task NumNeg_DenPos;
			while (valores.neg_pos.get_coverage() < 40) begin
			RandInst.num_pos.constraint_mode(0);
			RandInst.num_neg.constraint_mode(1);
			RandInst.den_pos.constraint_mode(1);
			RandInst.den_neg.constraint_mode(0);

			assert (RandInst.randomize()) else $fatal("Error: Fallo en la generación de valores aleatorios");

			testar_ports.sd.Num <= RandInst.num_rand;
			testar_ports.sd.Den <= RandInst.den_rand;

			valores.sample(); // Muestreo para la cobertura num    

			@(testar_ports.sd);
			testar_ports.sd.Start <= 1'b1; // Activa Start 
			@(testar_ports.sd);
			#10 testar_ports.sd.Start <= 1'b0; // Baja Start para indicar solo un pulso

			@(negedge testar_ports.sd.Done); // Espera a que Done sea 0
			end
			print_coverage();
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task NumPos_DenNeg;
			while (valores.pos_neg.get_coverage() < 60) begin
			RandInst.num_pos.constraint_mode(1);
			RandInst.num_neg.constraint_mode(0);
			RandInst.den_pos.constraint_mode(0);
			RandInst.den_neg.constraint_mode(1);

			assert (RandInst.randomize()) else $fatal("Error: Fallo en la generación de valores aleatorios");

			testar_ports.sd.Num <= RandInst.num_rand;
			testar_ports.sd.Den <= RandInst.den_rand;

			valores.sample(); // Muestreo para la cobertura num    

			@(testar_ports.sd);
			testar_ports.sd.Start <= 1'b1; // Activa Start 
			@(testar_ports.sd);
			#10 testar_ports.sd.Start <= 1'b0; // Baja Start para indicar solo un pulso

			@(negedge testar_ports.sd.Done); // Espera a que Done sea 0
			end
			print_coverage();
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task NumNeg_DenNeg;
			while (valores.negativos.get_coverage() < 80) begin
			RandInst.num_pos.constraint_mode(0);
			RandInst.num_neg.constraint_mode(1);
			RandInst.den_pos.constraint_mode(0);
			RandInst.den_neg.constraint_mode(1);

			assert (RandInst.randomize()) else $fatal("Error: Fallo en la generación de valores aleatorios");

			testar_ports.sd.Num <= RandInst.num_rand;
			testar_ports.sd.Den <= RandInst.den_rand;

			valores.sample(); // Muestreo para la cobertura num    

			@(testar_ports.sd);
			testar_ports.sd.Start <= 1'b1; // Activa Start 
			@(testar_ports.sd);
			#10 testar_ports.sd.Start <= 1'b0; // Baja Start para indicar solo un pulso

			@(negedge testar_ports.sd.Done); // Espera a que Done sea 0
			end
			print_coverage();
		endtask
	endclass
endpackage

// Program para los estimulos//////////////////////////////////////////////////////////////////////////////
program estimulos #(parameter tamanyo = 32) (Interface_if.test testar, Interface_if.monitor monitorizar);
	utilidades_verificacion::environment Test = new(testar, monitorizar);
   
	initial begin
		$display("+------------------------------------------------------------------------------+");
		$display("|                             Iniciando pruebas...                             |");
		$display("+------------------------------------------------------------------------------+");
		$display("                                                                                ");

		Test.muestrear;
		Test.NumPos_DenPos;
		Test.NumNeg_DenPos;
		Test.NumPos_DenNeg;
		Test.NumNeg_DenNeg;

		Test.print_coverage();

		$display("+------------------------------------------------------------------------------+");
		$display("|                               Pruebas acabadas                               |");
		$display("+------------------------------------------------------------------------------+");
		$stop;
	end
endprogram
