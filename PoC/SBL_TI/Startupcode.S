/*
 *  Copyright (C) 2018-2021 Texas Instruments Incorporated
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *    Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 *    Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the
 *    distribution.
 *
 *    Neither the name of Texas Instruments Incorporated nor the names of
 *    its contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

//****************************************************************************
//* BOOT.S
//*
//* THIS IS THE INITAL BOOT ROUTINE FOR TMS470 C++ PROGRAMS.
//* IT MUST BE LINKED AND LOADED WITH ALL C++ PROGRAMS.
//*
//* THIS MODULE PERFORMS THE FOLLOWING ACTIONS:
//*   1) ALLOCATES THE STACK AND INITIALIZES THE STACK POINTER
//*   2) CALLS AUTO-INITIALIZATION ROUTINE
//*   3) CALLS THE FUNCTION MAIN TO START THE C++ PROGRAM
//*   4) CALLS THE STANDARD EXIT ROUTINE
//*
//* THIS MODULE DEFINES THE FOLLOWING GLOBAL SYMBOLS:
//*   1) __stack     STACK MEMORY AREA
//*   2) _c_int00    BOOT ROUTINE
//*

#define Region_32B  0b00100
#define Region_64B  0b00101
#define Region_128B 0b00110
#define Region_256B 0b00111
#define Region_512B 0b01000
#define Region_1K   0b01001
#define Region_2K   0b01010
#define Region_4K   0b01011
#define Region_8K   0b01100
#define Region_16K  0b01101
#define Region_32K  0b01110
#define Region_64K  0b01111
#define Region_128K 0b10000
#define Region_256K 0b10001
#define Region_512K 0b10010
#define Region_1M   0b10011
#define Region_2M   0b10100
#define Region_4M   0b10101
#define Region_8M   0b10110
#define Region_16M  0b10111
#define Region_32M  0b11000
#define Region_64M  0b11001
#define Region_128M 0b11010
#define Region_256M 0b11011
#define Region_512M 0b11100
#define Region_1G   0b11101
#define Region_2G   0b11110
#define Region_4G   0b11111

#define Region_Enable 0b1

#define Execute_Never 0x1000 // Bit 12


#define Normal_nShared 0x0B // Outer and Inner Write-Back, Write-Allocate
#define Device_nShared 0x10

#define Full_Access 0b011
#define Read_Only   0b110


#define MpuP_AP_ALL_BLOCK 	0		 /**< All accesses are blocked */
#define MpuP_AP_S_RW     	0x1 /**< Only RD+WR supervisor mode accesses are allowed  */
#define MpuP_AP_S_RW_U_R  	0x2 /**< RD+WR supervisor and RD only user mode accesses are allowed  */
#define MpuP_AP_ALL_RW    	0x3 /**< All RD+WR accesses are allowed */
#define MpuP_AP_S_R       	0x5 /**< Only RD supervisor mode accesses are allowed */
#define MpuP_AP_ALL_R     	0x6  /**< All RD accesses are allowed */
//****************************************************************************

        .global __stack
//***************************************************************
//* DEFINE THE SYSTEM MODE STACK (DEFAULT SIZE IS 512)
//***************************************************************
        .section ".stack","aw",%nobits
__stack: .zero 4

        .text
        .global _c_int00_sbl
        .type   _c_int00_sbl,%function
        .section ".text.boot","ax",%progbits
        .arm
        .align 2

_c_int00_sbl:
        // entry point for bootloader, if Core 1, then loop forever, else goto _c_int00
        MRC     p15, #0, r1, c0, c0, #5
        BFC     r1, #8, #24
        CMP     r1, #0
        BNE     _sblLoopForever
        LDR     r1, _c_int00_addr
        BLX     r1
_sblLoopForever:
        WFI
        B       _sblLoopForever

_c_int00_addr:  .long _c_int00

        .text
        .global _c_int00
        .type   _c_int00,%function
        .section ".text.boot","ax",%progbits
        .arm
        .align 2

//***************************************************************
//* FUNCTION DEF: _c_int00
//***************************************************************
_c_int00:
			//----------------------------------------------------------------
		// Disable MPU and caches
		//----------------------------------------------------------------
		// Disable MPU and caches in case they were left enabled from an earlier run
		// This does not need to be done from a cold reset
        MRC     p15, 0, r0, c1, c0, 0       // Read SCTLR (System Control Register)
        BIC     r0, r0, #0x05               // Bit Clear - Disable MPU (M bit -bit 0) and data cache (C bit-Bit 2)
        BIC     r0, r0, #0x1000             // Disable instruction cache (I bit) -bit12
        DSB                                 // Data Synchronization Barrier - Ensure all previous loads/stores have completed
        MCR     p15, 0, r0, c1, c0, 0       // Write System Control Register
        ISB                                 // Instruction Synchronization Barrier - Ensure subsequent insts execute wrt new MPU settings

		//----------------------------------------------------------------
		// Disable Branch prediction
		//----------------------------------------------------------------

		// In the Cortex-R5, the Z-bit of the SCTLR does not control the program flow prediction.
		// Some control bits in the ACTLR control the program flow and prefetch features instead.
		// These are enabled by default, but are shown here for completeness.

        MRC     p15, 0, r0, c1, c0, 1       // Read ACTLR (Auxiliary Control Register)
        ORR     r0, r0, #(0x1 << 17)        // Logical OR - Enable RSDIS bit 17 to disable the return stack
        ORR     r0, r0, #(0x1 << 16)        // Clear Branch Prediction (BP) bit 15 and set BP bit 16:
        BIC     r0, r0, #(0x1 << 15)        // Branch always not taken and history table updates disabled
        MCR     p15, 0, r0, c1, c0, 1       // Write ACTLR
        ISB

		//----------------------------------------------------------------
		// Cache invalidation
		//----------------------------------------------------------------
        DSB                 				// Complete all outstanding explicit memory operations
        MOV     r0, #0
        MCR     p15, 0, r0, c7, c5, 0       // Invalidate entire instruction cache
        MCR     p15, 0, r0, c15, c5, 0      // Invalidate entire data cache

        //*------------------------------------------------------
        //* Disable FIQ and IRQ
        //*------------------------------------------------------
        mrs     r0, cpsr
        orr     r0, r0, #0xC0
        msr     cpsr_cf, r0

        #ifdef __ARM_FP
        //*------------------------------------------------------
        //* SETUP PRIVILEGED AND USER MODE ACCESS TO COPROCESSORS
        //* 10 AND 11, REQUIRED TO ENABLE NEON/VFP
        //* COPROCESSOR ACCESS CONTROL REG
        //* BITS [23:22] - CP11, [21:20] - CP10
        //* SET TO 0b11 TO ENABLE USER AND PRIV MODE ACCESS
        //*------------------------------------------------------
        MRC      p15,#0x0,r0,c1,c0,#2
        MOV      r3,#0xf00000
        ORR      r0,r0,r3
        MCR      p15,#0x0,r0,c1,c0,#2

        //*------------------------------------------------------
        // SET THE EN BIT, FPEXC[30] TO ENABLE NEON AND VFP
        //*------------------------------------------------------
        MOV      r0,#0x40000000
        FMXR     FPEXC,r0
        #endif

        //*------------------------------------------------------
        //* SET TO FIQ MODE
        //*------------------------------------------------------
        MRS     r0, cpsr
        BIC     r0, r0, #0x1F  // CLEAR MODES
        ORR     r0, r0, #0x11  // SET FIQ MODE
        MSR     cpsr_cf, r0

        //*------------------------------------------------------
        //* INITIALIZE THE FIQ MODE STACK
        //*------------------------------------------------------
        #if __TI_AVOID_EMBEDDED_CONSTANTS
        MOVW    sp, :lower16:__FIQ_STACK_END
        MOVT    sp, :upper16:__FIQ_STACK_END
        #else
        LDR     sp, c_FIQ_STACK_END
        #endif

        //*------------------------------------------------------
        //* SET TO IRQ MODE
        //*------------------------------------------------------
        MRS     r0, cpsr
        BIC     r0, r0, #0x1F  // CLEAR MODES
        ORR     r0, r0, #0x12  // SET IRQ MODE
        MSR     cpsr_cf, r0

        //*------------------------------------------------------
        //* INITIALIZE THE IRQ MODE STACK
        //*------------------------------------------------------
        #if __TI_AVOID_EMBEDDED_CONSTANTS
        MOVW    sp, :lower16:__IRQ_STACK_END
        MOVT    sp, :upper16:__IRQ_STACK_END
        #else
        LDR     sp, c_IRQ_STACK_END
        #endif

        //*------------------------------------------------------
        //* SET TO SVC MODE
        //*------------------------------------------------------
        MRS     r0, cpsr
        BIC     r0, r0, #0x1F  // CLEAR MODES
        ORR     r0, r0, #0x13  // SET SVC MODE
        MSR     cpsr_cf, r0

        //*------------------------------------------------------
        //* INITIALIZE THE SVC MODE STACK
        //*------------------------------------------------------
        #if __TI_AVOID_EMBEDDED_CONSTANTS
        MOVW    sp, :lower16:__SVC_STACK_END
        MOVT    sp, :upper16:__SVC_STACK_END
        #else
        LDR     sp, c_SVC_STACK_END
        #endif

        //*------------------------------------------------------
        //* SET TO ABORT MODE
        //*------------------------------------------------------
        MRS     r0, cpsr
        BIC     r0, r0, #0x1F  // CLEAR MODES
        ORR     r0, r0, #0x17  // SET ABORT MODE
        MSR     cpsr_cf, r0

        //*------------------------------------------------------
        //* INITIALIZE THE ABORT MODE STACK
        //*------------------------------------------------------
        #if __TI_AVOID_EMBEDDED_CONSTANTS
        MOVW    sp, :lower16:__ABORT_STACK_END
        MOVT    sp, :upper16:__ABORT_STACK_END
        #else
        LDR     sp, c_ABORT_STACK_END
        #endif

        //*------------------------------------------------------
        //* SET TO ABORT MODE
        //*------------------------------------------------------
        MRS     r0, cpsr
        BIC     r0, r0, #0x1F  // CLEAR MODES
        ORR     r0, r0, #0x1B  // SET ABORT MODE
        MSR     cpsr_cf, r0

        //*------------------------------------------------------
        //* INITIALIZE THE UNDEFINED MODE STACK
        //*------------------------------------------------------
        #if __TI_AVOID_EMBEDDED_CONSTANTS
        MOVW    sp, :lower16:__UNDEFINED_STACK_END
        MOVT    sp, :upper16:__UNDEFINED_STACK_END
        #else
        LDR     sp, c_UNDEFINED_STACK_END
        #endif

        //*------------------------------------------------------
        //* SET TO SYSTEM MODE
        //*------------------------------------------------------
        MRS     r0, cpsr
        BIC     r0, r0, #0x1F  // CLEAR MODES
        ORR     r0, r0, #0x1F  // SET SYSTEM MODE
        MSR     cpsr_cf, r0

        //*------------------------------------------------------
        //* INITIALIZE THE SYSTEM MODE STACK
        //*------------------------------------------------------
        #if __TI_AVOID_EMBEDDED_CONSTANTS
        MOVW    sp, :lower16:__STACK_END
        MOVT    sp, :upper16:__STACK_END
        #else
        LDR     sp, c_STACK_END
        #endif

//----------------------------------------------------------------
// TCM Configuration
//----------------------------------------------------------------
// Cortex-R5 optionally provides two Tightly-Coupled Memory (TCM) blocks (ATCM and BTCM) for fast access to code or data.
// ATCM typically holds interrupt or exception code that must be accessed at high speed,
// without any potential delay resulting from a cache miss.
// BTCM typically holds a block of data for intensive processing, such as audio or video data.
// In the Cortex-R5 processor, both ATCM and BTCM support both instruction and data accesses.
		#ifdef TCM
        MRC     p15, 0, r0, c0, c0, 2       // Read TCM Type Register
        // r0 now contains ATCM & BTCM availability
        MRC     p15, 0, r0, c9, c1, 1       // Read ATCM Region Register
        // r0 now contains ATCM size in bits [6:2]
        MRC     p15, 0, r0, c9, c1, 0       // Read BTCM Region Register
        // r0 now contains BTCM size in bits [6:2]

        LDR     r0, =0x00000000      		// Set ATCM base address
        ORR     r0, r0, #1                  // Enable it
        MCR     p15, 0, r0, c9, c1, 1       // Write ATCM Region Register

        LDR     r0, =0x41010000      		// Set BTCM base address
        ORR     r0, r0, #1                  // Enable it
        MCR     p15, 0, r0, c9, c1, 0       // Write BTCM Region Register
		#endif
        //*------------------------------------------------------
        //* Call the __mpu_init hook function.
        //*------------------------------------------------------

        //BL      __mpu_init

        MOV     r1, #0
        MCR     p15, 0, r1, c6, c2, 0       // Set memory region number register
        ISB                                 // Ensure subsequent insts execute wrt this region
        LDR     r2, =0x00000000
        MCR     p15, 0, r2, c6, c1, 0       // Set region base address register
        LDR     r2, =0x0  |  (Region_2G << 1)  |  Region_Enable
        MCR     p15, 0, r2, c6, c1, 2       // Set region size & enable register
        LDR     r2, =0x0  | (Execute_Never) | ( (MpuP_AP_S_RW_U_R)  << 8)  |  (0x4)	//TEX-0,Sharable-1,Bufferable-0,Cacheble-0
        MCR     p15, 0, r2, c6, c1, 4       // Set region access control register

		// Region 1 - 0x00000000 - 0x00007FFF
        MOV     r1, #1
        MCR     p15, 0, r1, c6, c2, 0       // Set memory region number register
        ISB                                 // Ensure subsequent insts execute wrt this region
        LDR     r2, =0x00000000
        MCR     p15, 0, r2, c6, c1, 0       // Set region base address register
        LDR     r2, =0x0  |  (Region_32K << 1)  |  Region_Enable
        MCR     p15, 0, r2, c6, c1, 2       // Set region size & enable register
        LDR     r2, =0x0  | ( (MpuP_AP_S_RW_U_R)  << 8)  |  (0xB)	//TEX-1,Sharable-0,Bufferable-1,Cacheble-1
        MCR     p15, 0, r2, c6, c1, 4       // Set region access control register

        // Region 2 - 0x41010000 - 0x41017FFF
        MOV     r1, #2
        MCR     p15, 0, r1, c6, c2, 0       // Set memory region number register
        ISB                                 // Ensure subsequent insts execute wrt this region
        LDR     r2, =0x41010000
        MCR     p15, 0, r2, c6, c1, 0       // Set region base address register
        LDR     r2, =0x0  |  (Region_32K << 1)  |  Region_Enable
        MCR     p15, 0, r2, c6, c1, 2       // Set region size & enable register
        LDR     r2, =0x0  | ((MpuP_AP_S_RW_U_R)  << 8)  |  (0xB)	//TEX-1,Sharable-0,Bufferable-1,Cacheble-1
        MCR     p15, 0, r2, c6, c1, 4       // Set region access control register

		// Region 3 - 0x70000000 - 0x70200000
        MOV     r1, #3
        MCR     p15, 0, r1, c6, c2, 0       // Set memory region number register
        ISB                                 // Ensure subsequent insts execute wrt this region
        LDR     r2, =0x70000000
        MCR     p15, 0, r2, c6, c1, 0       // Set region base address register
        LDR     r2, =0x0  |  (Region_2M << 1)  |  Region_Enable
        MCR     p15, 0, r2, c6, c1, 2       // Set region size & enable register
        LDR     r2, =0x0  | ((MpuP_AP_S_RW_U_R)  << 8)  |  (0xB)	//TEX-1,Sharable-0,Bufferable-1,Cacheble-1
        MCR     p15, 0, r2, c6, c1, 4       // Set region access control register

        // Region 4 - 0x80000000 - 0xFFFFFFFF
        MOV     r1, #4
        MCR     p15, 0, r1, c6, c2, 0       // Set memory region number register
        ISB                                 // Ensure subsequent insts execute wrt this region
        LDR     r2, =0x80000000
        MCR     p15, 0, r2, c6, c1, 0       // Set region base address register
        LDR     r2, =0x0  |  (Region_2G << 1)  |  Region_Enable
        MCR     p15, 0, r2, c6, c1, 2       // Set region size & enable register
        LDR     r2, =0x0  | ((MpuP_AP_ALL_RW)  << 8)  |  (0xB)	//TEX-1,Sharable-0,Bufferable-1,Cacheble-1
        MCR     p15, 0, r2, c6, c1, 4       // Set region access control register

		//Backgroung region enable
        mrc     p15, #0, r0, c1, c0, #0  // read SCTLR register
        orr     r0, r0, #0x20000         // set bit 17 in r0
        mcr     p15, #0, r0, c1, c0, #0  // background region enabled

//----------------------------------------------------------------
// Enable Branch prediction
//----------------------------------------------------------------

// In the Cortex-R5, the Z-bit of the SCTLR does not control the program flow prediction.
// Some control bits in the ACTLR control the program flow and prefetch features instead.
// These are enabled by default, but are shown here for completeness.

        MRC     p15, 0, r0, c1, c0, 1       // Read ACTLR
        BIC     r0, r0, #(0x1 << 17)        // Clear RSDIS bit 17 to enable return stack
        BIC     r0, r0, #(0x1 << 16)        // Clear BP bit 15 and BP bit 16:
        BIC     r0, r0, #(0x1 << 15)        // Normal operation, BP is taken from the global history table.
        MCR     p15, 0, r0, c1, c0, 1       // Write ACTLR
        ISB
		/*
		//----------------------------------------------------------------
		// Global Enable for Instruction and Data Caching
		//----------------------------------------------------------------
		MRC     p15, 0, r0, c1, c0, 0       // Read System Control Register
        ORR     r0, r0, #(0x1 << 12)        // enable I Cache
        ORR     r0, r0, #(0x1 << 2)         // enable D Cache
        MCR     p15, 0, r0, c1, c0, 0       // Write System Control Register
        ISB
		*/

        //*------------------------------------------------------
        //* Init .bss section to zero, this needs .bss to be
        //* defined as below in the linker command file.
        //*
        //* .bss:    {} palign(8)
        //* RUN_START(__BSS_START)
        //* RUN_END(__BSS_END)
        //*
        //* We do this after __mpu_init, since now cache is
        //* enabled and there memset speed will be optimal
        //*
        //* Perform all the required initializations when
        //* _system_pre_init() returns non-zero:
        //*   - Process BINIT Table
        //*   - Perform C auto initialization
        //*   - Call global constructors
        //*------------------------------------------------------
        BL      _system_pre_init
        CMP     R0, #0
        BEQ     bypass_auto_init
        BL      __TI_auto_init
bypass_auto_init:

        //*------------------------------------------------------
        //* CALL APPLICATION
        //*------------------------------------------------------
        BL      main

        //*------------------------------------------------------
        //* IF APPLICATION DIDN'T CALL EXIT, CALL EXIT(1)
        //*------------------------------------------------------
        MOV     R0, #1
        BL      exit

        //*------------------------------------------------------
        //* DONE, LOOP FOREVER
        //*------------------------------------------------------
L1:     B       L1


//***************************************************************
//* CONSTANTS USED BY THIS MODULE
//***************************************************************
        #if !__TI_AVOID_EMBEDDED_CONSTANTS
c_STACK_END: .long __STACK_END
c_IRQ_STACK_END: .long __IRQ_STACK_END
c_FIQ_STACK_END: .long __FIQ_STACK_END
c_SVC_STACK_END: .long __SVC_STACK_END
c_ABORT_STACK_END: .long __ABORT_STACK_END
c_UNDEFINED_STACK_END: .long __UNDEFINED_STACK_END
        #endif

//******************************************************
//* UNDEFINED REFERENCES                               *
//******************************************************
        .global __STACK_END
        .global __FIQ_STACK_END
        .global __IRQ_STACK_END
        .global __SVC_STACK_END
        .global __ABORT_STACK_END
        .global __UNDEFINED_STACK_END
        .global _system_pre_init
        .global __TI_auto_init
        .global main
        .global exit
        .global __mpu_init
        .global __bss_init

        .end
