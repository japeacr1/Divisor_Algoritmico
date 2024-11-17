module Divisor_Algoritmico_Seg #(parameter tamanyo=32)(Interface_if.Duv bus) ; 

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

localparam etapas = 2*tamanyo + 1;

logic [etapas-1:0][tamanyo-1:0] ACCU;
logic [etapas-1:0][tamanyo-1:0] M;
logic [etapas-1:0][tamanyo-1:0] Q;
logic [etapas-1:0] SignNum;
logic [etapas-1:0] SignDen;
logic [etapas-1:0] aux;

genvar i;
		
	always_ff @(posedge CLK or negedge RSTa) begin
        if (!RSTa) begin
            ACCU    [etapas-1] <= '0;
            Q       [etapas-1] <= '0;
            M       [etapas-1] <= '0;
            SignNum [etapas-1] <= '0;
            SignDen [etapas-1] <= '0;
            aux     [etapas-1] <= '0;
			end 
		else 
            begin
                if (Start) begin
                     ACCU [etapas-1] <= '0;
                     SignNum[etapas-1] <= Num[tamanyo-1];
                     SignDen[etapas-1] <= Den[tamanyo-1];
                     Q[etapas-1] <= (Num[tamanyo-1] ? ~Num + 1 : Num); 
                     M[etapas-1] <= (Den[tamanyo-1] ? ~Den + 1 : Den); 
					end
            end
    end
    generate
        for (i=(etapas-1); i>=0; i=i-1)
            begin
            always_ff @(posedge CLK or negedge RSTa)
                begin
                if (!RSTa)
                    begin
                        ACCU[i]    <= '0;
                        SignNum[i] <= '0;
                        SignDen[i] <= '0;
                        Q[i]       <= '0;
                        M[i]       <= '0;
                        aux[i]     <= '0;
                    end
                else
                    begin
                        aux[i] <= aux[i+1];
                        if (aux[i+1])
                            begin
                                SignNum[i] <= SignNum[i+1];
                                SignDen[i] <= SignDen[i+1];
                                M[i] <= M[i+1];
                                if (i%2 ==1'b1)
                                    {ACCU[i], Q[i]} <= {ACCU[i+1][tamanyo-2:0], Q[i+1], 1'b0};
                                else
                                    begin
                                    if (ACCU[i+1] >= M[i+1])
                                        begin
                                            ACCU[i] <= ACCU[i+1] - M[i+1];
                                            Q[i] <= Q[i+1] + 1;
                                        end
                                    else
                                        begin
                                        ACCU[i] <= ACCU[i+1];
                                        Q[i] <= Q[i+1];
                                        end
                                    end
                            end
                    end
                end
            end
    endgenerate
    assign Done = aux[0];
    assign Coc = (SignNum[0] ^ SignDen[0]) ? (~Q[0] + 1) : Q[0];
    assign Res = (SignNum[0]) ? (~ACCU[0] + 1) : ACCU[0];

endmodule




		