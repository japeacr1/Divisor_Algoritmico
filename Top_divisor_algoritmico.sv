`timescale 1ns / 1ps

module Top_divisor_algoritmico();
    parameter tamanyo = 32;
    logic CLK;
    logic RSTa;

    // Instanciacion de la interfaz
    Interface_if #(tamanyo) test_if(.reloj(CLK), .reset(RSTa));

    // Instanciacion del diseÃ±o (DUV)
    Top_Duv #(tamanyo) Duv (.bus(test_if));

    // Instanciacion del diseÃ±o de referencia (Duv_ref)
    Top_pruebas #(tamanyo) Duv_ref (.bus_ref(test_if));

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
        $dumpvars(1, Top_divisor_algoritmico.Duv.divisor.Num);
	$dumpvars(1, Top_divisor_algoritmico.Duv.divisor.Den);
	$dumpvars(1, Top_divisor_algoritmico.Duv.divisor.Coc);
	$dumpvars(1, Top_divisor_algoritmico.Duv.divisor.Res);
	$dumpvars(1, Top_divisor_algoritmico.Duv.divisor.Done);
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
			while (1) begin
				@(mports.md);
				if (mports.md.Done) begin
					target_coc = cola_target_coc.pop_back();
					target_res = cola_target_res.pop_back();

					observado_Coc = mports.md.Coc;
					observado_Res = mports.md.Res;

					assert (observado_Coc == target_coc) else $error("Cociente incorrecto: Esperado %d, Observado %d", target_coc, observado_Coc);
					assert (observado_Res == target_res) else $error("Residuo incorrecto: Esperado %d, Observado %d", target_res, observado_Res);
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
			bins num_pos[50] = {[0 : 2147483647]};}
		num_negativo: coverpoint monitorizar_ports.md.Num {
			bins num_neg[50]  = {[-2147483648 : -1]};}
		den_positivo: coverpoint monitorizar_ports.md.Den {
			bins den_pos[50]  = {[1 : 2147483647]};}
		den_negativo: coverpoint monitorizar_ports.md.Den {
			bins den_neg[50]  = {[-2147483648 : -1]};}

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
		task print_coverage();  
			$display("+-----------------------------+");
			$display("|     Coverage Report         |");
			$display("+-----------------------------+");
			$display("| Valores       %6.2f%%       |", valores.get_coverage());
			$display("| num_pos       %6.2f%%       |", valores.num_positivo.get_coverage());
			$display("| den_pos       %6.2f%%       |", valores.den_positivo.get_coverage());
			$display("| num_neg       %6.2f%%       |", valores.num_negativo.get_coverage());
			$display("| den_neg       %6.2f%%       |", valores.den_negativo.get_coverage());
			$display("+                             +");
			$display("| num_pos_den_pos %6.2f%%     |", valores.positivos.get_coverage());
			$display("| num_neg_den_neg %6.2f%%     |", valores.negativos.get_coverage());
			$display("| num_neg_den_pos %6.2f%%     |", valores.neg_pos.get_coverage());
			$display("| num_pos_den_neg %6.2f%%     |", valores.pos_neg.get_coverage());
			$display("+-----------------------------+");
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task NumPos_DenPos;
			while (valores.positivos.get_coverage() < 100) begin
				$display("NumPos_DenPos: Current coverage = %0.2f%%", valores.positivos.get_coverage());
				
				// Configurar restricciones
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
			$display("NumPos_DenPos: Final coverage = %0.2f%%", valores.positivos.get_coverage());
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task NumNeg_DenPos;
			while (valores.neg_pos.get_coverage() < 100) begin
				$display("NumNeg_DenPos: Current coverage = %0.2f%%", valores.neg_pos.get_coverage());
				
				// Configurar restricciones
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
			$display("NumNeg_DenPos: Final coverage = %0.2f%%", valores.neg_pos.get_coverage());
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task NumPos_DenNeg;
			while (valores.pos_neg.get_coverage() < 100) begin
				$display("NumPos_DenNeg: Current coverage = %0.2f%%", valores.pos_neg.get_coverage());
				
				// Configurar restricciones
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
			$display("NumPos_DenNeg: Final coverage = %0.2f%%", valores.pos_neg.get_coverage());
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		task NumNeg_DenNeg;
			while (valores.negativos.get_coverage() < 100) begin
				$display("NumNeg_DenNeg: Current coverage = %0.2f%%", valores.negativos.get_coverage());

				// Configurar restricciones
				RandInst.num_pos.constraint_mode(0);
				RandInst.num_neg.constraint_mode(1);
				RandInst.den_pos.constraint_mode(0);
				RandInst.den_neg.constraint_mode(1);

				// Generar valores aleatorios
				assert (RandInst.randomize()) else $fatal("Error: Fallo en la generación de valores aleatorios");

				// Asignar valores generados a las señales de prueba
				testar_ports.sd.Num <= RandInst.num_rand;
				testar_ports.sd.Den <= RandInst.den_rand;

				// Muestreo para la cobertura
				valores.sample();

				// Iniciar la prueba
				@(testar_ports.sd);
				testar_ports.sd.Start <= 1'b1; // Activa Start 
				@(testar_ports.sd);
				#10 testar_ports.sd.Start <= 1'b0; // Baja Start para indicar solo un pulso

				// Esperar a que Done sea 0
				@(negedge testar_ports.sd.Done);
			end
			$display("NumNeg_DenNeg: Final coverage = %0.2f%%", valores.negativos.get_coverage());
		endtask
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	endclass
endpackage

// Program para los estimulos//////////////////////////////////////////////////////////////////////////////
program estimulos #(parameter tamanyo = 32) (Interface_if.test testar, Interface_if.monitor monitorizar);
    utilidades_verificacion::environment Test = new(testar, monitorizar);
   
    initial begin
        $display("+-----------------------------+");
        $display("|     Iniciando pruebas...    |");
        $display("+-----------------------------+");
        $display("                             ");

        Test.muestrear;
        Test.NumPos_DenPos;
		Test.NumNeg_DenNeg;
        Test.NumNeg_DenPos;
        Test.NumPos_DenNeg;

        Test.print_coverage();


        $display("+-----------------------------+");
        $display("|     Pruebas acabadas        |");
        $display("+-----------------------------+");
        $stop;
    end
endprogram