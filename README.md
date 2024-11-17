# Top Divisor
    +---------------------------------------------------------------+
    |                     Testbench Top Module                      |
    |                                                               |
    |    +-----------------------------------------------------+    |
    |    |                    Program estímulos                |    |
    |    |                                                     |    |
    |    |                                                     |    |
    |    |  +----------+  +---------+  +--------------------+  |    |
    |    |  |    GM    |  |  Queue  |  |     Scoreboard     |  |    |
    |    |  |Generador |  |Almacena |  | Compara salida duv |  |    |
    |    |  |ramdon de |->| valores |->| con los esperados  |  |    |
    |    |  |Num y Den |  | ideales |  |                    |  |    |
    |    |  +----------+  +---------+  +--------------------+  |    |
    |    |       |                               ↑             |    |
    |    |       |                               |             |    |
    |    |       |                               |             |    |
    |    |       |                               |             |    |
    |    |       ↓                               |             |    |
    |    |  +------------------+     +-----------------+       |    |
    |    |  |  modport_test    |     | modport_monitor |       |    |
    |    +--+------------------+-----+-----------------+-------+    |
    |                |                       ↑                      |
    |                |                       |                      |
    |                ↓                       |                      |
    |        +------------------------------------------------+     |
    |        |                 INTERFACE                      |     |
    |        +------------------------------------------------+     |
    |                ↑                ↑                ↑            |
    |                |                |                |            |
    |                ↓                |                ↓            |
    |     +-----+-------------+----+  |   +-+-----------------+-+   |
    |     |     | modport_duv |    |  |   | | modport_duv_ref | |   |
    |     |     +-------------+    |  |   | +-----------------+ |   |
    |     |                        |  |   |                     |   |
    |     |          DUV           |  |   |       DUV_ref       |   |
    |     | (Divisor Algorítmico)  |  |   | (Modelo referencia) |   |
    |     +------------------------+  |   +---------------------+   |
    |                           ______|______                       |
    |                          |             |                      |
    |                          |             |                      |
    |                      +-------+     +-------+                  |
    |                      | RESET |     | Clock |                  |
    |                      +-------+     +-------+                  |
    |                                                               |
    +---------------------------------------------------------------+


    
Clone the repository
```bash
git clone https://github.com/realhastalamuerte23/Divisor_Algoritmico.git
```
