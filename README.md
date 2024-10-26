# KLK KLK

/Top_divisor_project
│
├── Top_divisor.sv
│   ├── parameter tamanyo = 32;  // Define el tamaño de los datos (32 bits)
│   ├── logic CLK, RSTa;         // Señales de reloj y reset
│   ├── Interface_if.sv          // Instancia de la interfaz para conectar el DUT
│   ├── Divisor_Algoritmico.sv   // Instancia del divisor (DUT)
│   ├── estimulos.sv             // Instancia del programa de estímulos
│   ├── always block             // Generación de la señal de reloj (CLK)
│   ├── initial block            // Reseteo inicial
│   └── $dumpfile, $dumpvars     // Configuración para volcado de valores (vcd)
│
├── Interface_if.sv
│   ├── parameter tamanyo = 32;  // Define el tamaño de los datos
│   ├── logic Start, Done;       // Señales de control
│   ├── logic Num, Den;          // Numerador y Denominador
│   ├── logic Coc, Res;          // Cociente y Residuo
│   ├── clocking md              // Clocking block para monitoreo
│   ├── clocking sd              // Clocking block para generación de estímulos
│   └── modports                 // Modports para monitor, test, y duv
│
├── Divisor_Algoritmico.sv
│   ├── // Lógica del divisor algorítmico
│   ├── // Recibe Num, Den y Start desde la interfaz
│   └── // Proporciona Coc, Res y Done como salida
│
├── estimulos.sv
│   ├── parameter tamanyo = 32;  // Define el tamaño de los datos
│   ├── logic num_rand, den_rand; // Números aleatorios para pruebas
│   ├── logic observado_Coc, observado_Res; // Valores observados
│   ├── logic target_Coc, target_Res;       // Valores esperados
│   ├── initial block                      // Inicialización y casos de prueba
│   ├── task realizar_prueba               // Realiza las pruebas de división
│   └── task scoreboard                    // Compara los resultados esperados y observados
│
├── test_cases
│   ├── Case1_Positive_Numerator_Positive_Denominator // Prueba con Numerador y Denominador positivos
│   ├── Case2_Positive_Numerator_Negative_Denominator // Prueba con Numerador positivo y Denominador negativo
│   ├── Case3_Negative_Numerator_Positive_Denominator // Prueba con Numerador negativo y Denominador positivo
│   └── Case4_Negative_Numerator_Negative_Denominator // Prueba con Numerador y Denominador negativos
│
└── Makefile
    ├── // Comandos para compilar y simular en ModelSim
    ├── // Incluye la compilación de Top_divisor.sv y la generación del archivo de volcado (vcd)
    └── // Comandos para ejecutar y verificar la simulación
