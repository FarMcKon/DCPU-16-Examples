 ; Do a loopy thing
	SET I, 10                ; a861
	SET A, 0x2000            ; 7c01 2000
:loop
	SET [0x2000+I], [A]      ; 2161 2000
	AUD_O A			 		  ; 0020 
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
