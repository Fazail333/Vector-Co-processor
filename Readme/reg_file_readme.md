# Vector Register File 

## Description

- Vector Resgister File (VRF) contains a set of vector registers (e.g., V0, V1, V2, ..., Vn) capable of holding vector elements. Each register can store multiple data elements, depending on the vector length (VLEN).

## Features

- The vector register file consist of **32 VLEN** bit vector registers.
- The granularity of the vector register file can be changed by tunnig the **LMUL** parameter

## Important Terminologies 

- ###  VELN
    - VLEN defines the total number of elements in a vector register that a vector instruction operates on. It represents the entire length of the vector to be processed.It is a implementation dependent parameter and indicates the number of bits of a single vector register.

- ### LMUL 
    - LMUL defines how many elements are processed per lane by multiplying the number of elements processed in each lane. It scales the number of vector elements assigned to the lanes for parallel processing.It is possible to tune the parameter LMUL to chage the granularity of the ***VRF*** e.g  setting ***LMUL*** to **2** means VRF will composed of  **16** ***"2 x VLEN"*** bit vector registers.

## Block Diagram 
The block digram of the vector register file in case of **LMUL = 1** as a result of which VRF consisting of **32 VLEN** bit vector registers and when **LMUL = 2** consisting of **16**  registers each having **2 x VLEN** bits.       

- ### LMUL = 1

    ![VRF_LMUL_1](/docs/regfile_docs/VRF_LMUL_1.png)
- ### LMUL = 2
    ![VRF_LMUL_2](/docs/regfile_docs/VRF_LMUL_2_.drawio.png)

## Pinout Diagram 
The pinout diagram of the vector register file is given below:

![VRF_Pinout](/docs/regfile_docs/vec_regfile_pinout.drawio.png)