module Divisor_Algoritmico #(parameter tamanyo=32)(Interface_if.Duv bus) ; 

Divisor_Algoritmico_duv #(tamanyo) divisor_duv(
  .CLK   (bus.reloj),     
  .RSTa  (bus.reset),     
  .Start (bus.Start),
  .Num   (bus.Num),
  .Den   (bus.Den),   
  .Coc   (bus.Coc),
  .Res   (bus.Res), 
  .Done  (bus.Done)    
  );

endmodule

module Divisor_Algoritmico_duv
#(parameter tamanyo=32)           
(input CLK,
input RSTa,
input Start,
input logic [tamanyo-1:0] Num,
input logic [tamanyo-1:0] Den,

output logic [tamanyo-1:0] Coc,
output logic [tamanyo-1:0] Res,
output Done);

logic [tamanyo-1:0] CONT;
logic [tamanyo-1:0] ACCU;
logic [tamanyo-1:0] M;
logic [tamanyo-1:0] Q;
logic  SignNum;
logic  SignDen;
logic fin;
//vuestro código

typedef enum logic [1:0] {
    D0 = 2'b00,
    D1 = 2'b01,
    D2 = 2'b10,
    D3 = 2'b11
} state_t;

state_t state;

		
	always_ff @(posedge CLK or negedge RSTa) begin
        if (!RSTa) begin
            ACCU  <= '0;
            Q     <= '0;
            M     <= '0;
            CONT  <= '0;
            fin   <=  0;
            Coc   <= '0;
            Res   <= '0;
            state <= D0;
            SignNum <= 0;
            SignDen <= 0;
			end 
		else 
            case (state)
                D0: begin
                    fin <= 0;
                    if (Start) begin
                        assert (Den!=0) else $error("Ha ocurrido un error grave. El denominador no puede ser 0");
                        ACCU <= '0;
                        CONT <= tamanyo - 1;
                        SignNum <= Num[tamanyo - 1];
                        SignDen <= Den[tamanyo - 1];
                        Q <= (Num[tamanyo - 1] ? ~Num + 1 : Num); 
                        M <= (Den[tamanyo - 1] ? ~Den + 1 : Den); 
                        state <= D1;
						end
                    else 
                        state <= D0;
					end

                D1: begin
                    {ACCU,Q} <= {ACCU[tamanyo-2:0], Q, 1'b0};
                    state <= D2;
					end
                
                D2: begin
                    CONT <= CONT - 1;
                    if (ACCU >= M) begin
                        Q <= Q + 1;
                        ACCU <= ACCU - M;
                        end
                    if (CONT == 0) 
                        state <= D3;
                    else 
                        state <= D1;
					end

                D3: begin
                    fin <= 1;
                    Coc <= (SignNum ^ SignDen) ? (~Q + 1) : Q;
                    Res <= (SignNum) ? (~ACCU + 1) : ACCU;
                    state <= D0; 
					end

                default: state <= D0;
            endcase
		end
assign Done = fin;
endmodule




		