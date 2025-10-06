#ifndef _CONFIG_H_
#define _CONFIG_H_

#define DELAY_Z_AND 1
#define DELAY_PC 1
#define DELAY_ADDERS 10
#define DELAY_MUXES 5
#define DELAY_ALU 20
#define DELAY_CONTROL 5
#define DELAY_MEMORY 50
#define DELAY_REGS 20
#define DELAY_REG_WR 5
#define DELAY_IMM_EXT 10


#define IMEM_SIZE 256
#define DMEM_SIZE 256


#define DEBUG_INFO 1
#define LOAD_USE_HAZARD 1
#define FORWARDING 1
#define BRANCH_FLUSH 1
#define INDETERMINADO 0xDEADBEEF
#define WRITEFIRST 1


#endif