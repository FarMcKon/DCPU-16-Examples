#DCPU-16 Specification
* Copyright 2012 Mojang
* Version 1.1 (Check 0x10c.com for updated versions)
* Version 1.1-f (Check  https://github.com/FarMcKon/DCPU-16-Examples/blob/master/dcpu-16f.md for updated versions)

# Overview 
* 16 bit unsigned words
* 0x10000 words of ram
* 8 registers (A, B, C, X, Y, Z, I, J)
* program counter (PC)
* stack pointer (SP)
* overflow (O)
* Audio Out register (AO) -Series F only
* Audio In register (AI) -Series F only
* Factory burnt ROM per manufacturer (0x32 words)  -Series F only

This document covers the DCPU-16 series chip, including the audio extension added by McKon Cooperative Industries.

In this document, anything within [brackets] is shorthand for "the value of the RAM at the location of the value inside the brackets". For example, SP means stack pointer, but [SP] means the value of the RAM at the location the stack pointer is pointing at.

Whenever the CPU needs to read a word, it reads [PC], then increases PC by one. Shorthand for this is [PC++]. In some cases, the CPU will modify a value before reading it, in this case the shorthand is [++PC].

# DCPU-16 Instructions
Instructions are 1-3 words long and are fully defined by the first word.

## Basic OpCodes
In a basic instruction, the lower four bits of the first word of the instruction are the opcode, 
and the remaining twelve bits are split into two six bit values, called a and b.  In bits (with the least significant being last), a basic instruction has the format: bbbbbbaaaaaaoooo

A is always handled by the processor before b, and is the lower six bits.

###Values: (6 bits)
            0x00-0x07: register (A, B, C, X, Y, Z, I or J, in that order)
            0x08-0x0f: [register]
            0x10-0x17: [next word + register]
                 0x18: POP / [SP++]
                 0x19: PEEK / [SP]
                 0x1a: PUSH / [--SP]
                 0x1b: SP
                 0x1c: PC
                 0x1d: O
                 0x1e: [next word]
                 0x1f: next word (literal)
            0x20-0x3f: literal value 0x00-0x1f (literal)

* "next word" really means "[PC++]". These increase the word length of the instruction by 1. 
* If any instruction tries to assign a literal value, the assignment fails silently. Other than that, the instruction behaves as normal.
* All values that read a word (0x10-0x17, 0x1e, and 0x1f) take 1 cycle to look up. The rest take 0 cycles.
* By using 0x18, 0x19, 0x1a as POP, PEEK and PUSH, there's a reverse stack starting at memory location 0xffff. Example: "SET PUSH, 10", "SET X, POP"



###Basic opcodes: (4 bits)
        0x0: non-basic instruction - see below
        0x1: SET a, b - sets a to b
        0x2: ADD a, b - sets a to a+b, sets O to 0x0001 if there's an overflow, 0x0 otherwise
        0x3: SUB a, b - sets a to a-b, sets O to 0xffff if there's an underflow, 0x0 otherwise
        0x4: MUL a, b - sets a to a*b, sets O to ((a*b)>>16)&0xffff
        0x5: DIV a, b - sets a to a/b, sets O to ((a<<16)/b)&0xffff. if b==0, sets a and O to 0 instead.
        0x6: MOD a, b - sets a to a%b. if b==0, sets a to 0 instead.
        0x7: SHL a, b - sets a to a<<b, sets O to ((a<<b)>>16)&0xffff
        0x8: SHR a, b - sets a to a>>b, sets O to ((a<<16)>>b)&0xffff
        0x9: AND a, b - sets a to a&b
        0xa: BOR a, b - sets a to a|b
        0xb: XOR a, b - sets a to a^b
        0xc: IFE a, b - performs next instruction only if a==b
        0xd: IFN a, b - performs next instruction only if a!=b
        0xe: IFG a, b - performs next instruction only if a>b
        0xf: IFB a, b - performs next instruction only if (a&b)!=0
    
* SET, AND, BOR and XOR take 1 cycle, plus the cost of a and b
* ADD, SUB, MUL, SHR, and SHL take 2 cycles, plus the cost of a and b
* DIV and MOD take 3 cycles, plus the cost of a and b
* IFE, IFN, IFG, IFB take 2 cycles, plus the cost of a and b, plus 1 if the test fails
    

## Advanced OpCodes

Non-basic opcodes always have their lower four bits unset, have one value and a six bit opcode.
In binary, they have the format: aaaaaaoooooo0000
The value (a) is in the same six bit format as defined earlier.

###Non-basic opcodes: (6 bits)
			0x00: reserved for future expansion
                 0x01: JSR a - pushes the address of the next instruction to the stack, then sets PC to a
                 0x02: ROM read - read a value from factory burnt ROM to register I. Passed value is the location in ROM to read into register I 
                 0x03: Audio Output - Write register value to 2 channel audio output buffer. Channel a is bits 0x0F and channel b is 0xF0. Absloute values are not allowed. 
                 0x04: Audio Input - Read register value from a 2 channel audio output buffer. Channel a is bits 0x0F and channel b is 0xF0. Absloute values are not allowed. 
			0x04-0x3f: reserved
    
* JSR takes 2 cycles, plus the cost of a.
* ROM read takes 2 cycles
* Audio Output takes 2 cycles
* Audio Input takes 4 cycles

#FAQ:

Q: Why is there no JMP or RET?
A: They're not needed! "SET PC, <target>" is a one-instruction JMP.
   For small relative jumps in a single word, you can even do "ADD PC, <dist>" or "SUB PC, <dist>".
   For RET, simply do "SET PC, POP"
   
Q: How does the overflow (O) work?
A: O is set by certain instructions (see above), but never automatically read. You can use its value in instructions, however.
   For example, to do a 32 bit add of 0x12345678 and 0xaabbccdd, do this:
      SET [0x1000], 0x5678    ; low word
      SET [0x1001], 0x1234    ; high word
      ADD [0x1000], 0xccdd    ; add low words, sets O to either 0 or 1 (in this case 1)
      ADD [0x1001], O         ; add O to the high word
      ADD [0x1001], 0xaabb    ; add high words, sets O again (to 0, as 0xaabb+0x1235 is lower than 0x10000)

Q: How do I do 32 or 64 bit division using O?
A: This is left as an exercise for the reader.
     
Q: How about a quick example?
A: Sure! Here's some sample assembler, and a memory dump of the compiled code:

        ; Try some basic stuff
                      SET A, 0x30              ; 7c01 0030
                      SET [0x1000], 0x20       ; 7de1 1000 0020
                      SUB A, [0x1000]          ; 7803 1000
                      IFN A, 0x10              ; c00d 
                         SET PC, crash         ; 7dc1 001a [*]
                      
        ; Do a loopy thing
                      SET I, 10                ; a861
                      SET A, 0x2000            ; 7c01 2000
        :loop         SET [0x2000+I], [A]      ; 2161 2000
                      SUB I, 1                 ; 8463
                      IFN I, 0                 ; 806d
                         SET PC, loop          ; 7dc1 000d [*]
        
        ; Call a subroutine
                      SET X, 0x4               ; 9031
                      JSR testsub              ; 7c10 0018 [*]
                      SET PC, crash            ; 7dc1 001a [*]
        
        :testsub      SHL X, 4                 ; 9037
                      SET PC, POP              ; 61c1
                        
        ; Hang forever. X should now be 0x40 if everything went right.
        :crash        SET PC, crash            ; 7dc1 001a [*]
        
        ; [*]: Note that these can be one word shorter and one cycle faster by using the short form (0x00-0x1f) of literals,
        ;      but my assembler doesn't support short form labels yet.     

  Full memory dump:
  
        0000: 7c01 0030 7de1 1000 0020 7803 1000 c00d
        0008: 7dc1 001a a861 7c01 2000 2161 2000 8463
        0010: 806d 7dc1 000d 9031 7c10 0018 7dc1 001a
        0018: 9037 61c1 7dc1 001a 0000 0000 0000 0000
        
Q: What is the dcpu16f?
A) Shortly after the release of the DCPU-16,  McKon Cooperative Industries added 0x32 word ROM unit to their unauthorized copy of the DCPU-16 chip, as an option for customers purchasing chips in bulk, allowing them to pre-load the chip with custom data.  Only 31 of the 32 words were readable, the word at location 0x32 contained a mfg. batch number ID.  These were called the DCPU-M . Due to the surprising success of the chip, MKCI added a further unauthorized modification, containing a two channel audio output register, with 2 8-bit channels. While technically an audio input buffer is also specified, that feature never worked as advertised and was largly ignored by purchesers of the cuip. 

        
Q: How does ROM reading work?
A: ROM reads could only read to register I due to hardware limitations, by specifying a direct memory location. This is clearly a design flaw due to the inexperience of the design team, rather than a manufacutring or hardware limitation.  
  RROM 31 ; Read ROM location 31 to register I 
  RROM A;  illegal
  
Q: How does Audio Output buffer work?
A:  Channel A is mapped to bits 0xF0, channel B is mapped to bits 0x0F. upon writing the analog output on the channel is updated, requiring programs to self-manage interrupts and timing for proper audio output. 
SET A, 0xFF ; Load 0xFF into register A 
AUD_O A ; Write value of Register A to 2 channel Audio Output, Chan A set to F, Chan B set to F.


