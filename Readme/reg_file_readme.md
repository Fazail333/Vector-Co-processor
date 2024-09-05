# Vector Register File 

## Description

- Vector Resgister File (VRF) contains a set of vector registers (e.g., V0, V1, V2, ..., Vn) capable of holding vector elements. Each register can store multiple data elements, depending on the vector length (VLEN).

- The vector register file consist of **32 VLEN** bit vector registers.
- The granularity of the vector register file can be changed by tunnig the **LMUL** parameter

## Important Terminologies 

- ###  VELN
    - It is a implementation dependent parameter and indicates the number of bits of a single vector register.

- ### LMUL 
    - It is possible to tune the parameter LMUL to chage the granularity of the ***VRF*** e.g  setting ***LMUL*** to **2** means VRF will composed of  **16** ***"2 x VLEN"*** bit vector registers.
        
