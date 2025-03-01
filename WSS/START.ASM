
		.model tiny, C
				
	INCLUDE COMPAT.INC
        INCLUDE PROLOGUE.MAC          ;; common prologue
	INCLUDE SOUNDRV.INC

IFNDEF  ISCOM
	IFNDEF  ISEXE
		ISCOM 	EQU 	1
		ISEXE	EQU	0
	ELSE
		ISCOM 	EQU 	0
	ENDIF
ENDIF

	.code
	.386
	assume es:nothing, ss:nothing

EXTRN SoundInterupt:NEAR

SUICIDE LABEL	byte		;; Where to delete ourselves from memory
hard	db	"Microsoft Windows Sound System not detected.",13,10,'$'
msg0	db	"Microsoft Windows Sound System DIGPAK Driver", 13,10
	db	" - Copyright (c) 1993, THE Audio Solution:v3.4",13,10,'$'
msg1	db	"The Sound Driver is already resident.",13,10,'$'
msg1a	db	"The Sound Driver is resident, through MIDPAK.",13,10,'$'
msg1b	db	"A Sound Driver cannot be loaded on top of MIDPAK.  Unload MIDPAK first.",13,10,'$'
msg2	db	"Unable to install Sound Driver interupt vector",13,10,'$'
msg3    db      "Invalid command line",13,10,'$'
msg4	db	"Sound Driver isn't in memory",13,10,'$'
msg5	db	"Sound Driver unloaded",13,10,'$'
msg5a	db	"Sound Driver can't be unloaded, unload MIDPAK first.",13,10,'$'
param   dw      4 dup(?)        ;; Used for parameter passing.
Installed	dw	0
	
	PUBLIC LoadSound
LoadSound Proc	near
	mov	ax,cs			;;
	mov	ds,ax			;; establish data segment
IF	ISEXE
	sub	ax,10h			;;
ENDIF
	mov	es,ax			;; point ES to PSP
	call	CheckIn
	mov	[Installed],ax		;; Save in installed flag.
	call	ParseCommandLine	;; Build a command line.
	cmp	[_argc],0
	je	NoArg
	cmp	[_argc],1
	jne	@@BC
	mov	bx,[_argv]
	mov	al,[bx]
	cmp	al,'u'
	je	ULOAD
	cmp	al,'U'
	je	ULOAD
@@BC:
	Message msg3			;; Invalid command line
        DOSTerminate

ULOAD:	mov	ax,[Installed]
	or	ax,ax
	jnz	DOU
	Message msg4			;; wasn't loaded.
	DOSTerminate			;; Terminate with message.
DOU:	cmp	ax,2
	jne	@@OKU
	Message msg5a
	DOSTerminate
@@OKU:
	CALLF	DeInstallInterupt
	Message msg5			;; Display message
	DOSTerminate			;; terminate

NoArg:	or	ax,ax			;; Already loaded?
	jz	@@DOLO			;; no->load it.
	cmp	ax,2
	jne	@@TEMP
	Message msg1a
	DOSTerminate
@@TEMP: cmp	ax,3
	jne	@@TEMPA
	jmp short @@DOLO
	Message msg1b
	DOSTerminate
@@TEMPA:
	Message msg1			;; message
	DOSTerminate			;;
@@DOLO: CALLF	InstallInterupt
	or	ax,ax			;; Was there an error?
	jz	@@HOP1			;; no->continue
	Message msg2			;; display the error message
	Message hard	; Hardware error message if there is one.
	DOSTerminate			;; exit to dos
@@HOP1:
;;; The Kernel is now installed.
;;; Announce the Kernel's presence.
	Message msg0
        DosTSR  SUICIDE         ;; Terminate ourselves bud.
LoadSound endp

        public InstallInterupt
InstallInterupt Proc	far
	IN_TSR
	call	HardwareInit	;; Initialize hardware.
	or	ax,ax		;; Error initializing hardware?
	jnz	@@OUT
	mov	[param],KINT		;; The interupt kernel is going into.
	mov	[param+2],offset SoundInterupt ;; offset of interupt routine
	mov	[param+4],cs		;; Our code segment.
	PushEA	param			;; push the address of the parameter list
	call	InstallINT		;; Install the interupt.
	add	sp,2			;; clean up stack
@@OUT:
	OUT_TSR
	ret
InstallInterupt	endp

        public DeInstallInterupt
DeInstallInterupt Proc	far
	IN_TSR
	mov	[param],KINT		;; Interupt requested to be unloaded.
	PushEA	param			;; pass parameter.
	call	UnLoad			;; Unload it
	add	sp,2			;; clean up stack
	OUT_TSR
	ret
DeInstallInterupt endp

CheckIn	Proc	near
	push	ds		; Save ds register.
	push	si
	mov	si,66h*4h	; get vector number
        xor     ax,ax           ; zero
        mov     ds,ax           ; point it there
	lds	si,ds:[si]	; get address of interupt vector
        or      si,si           ; zero?
        jz      @@CIOUT         ; exit if zero
        sub     si,6            ; point back to identifier
	cmp	word ptr [si],'IM'  ; Midi driver?
	jne	@@NEX
	cmp	word ptr [si+2],'ID'  ; full midi driver identity string?
	jne	@@NEX
;; Ok, a MIDI driver is loaded at this address.
	mov	ax,701h 	; Digitized Sound capabilities request.
	int	66h		; Request.
	or	ax,ax		; digitized sound driver available?
	jnz	@@INMID 	; yes, report that to the caller.
	mov	ax,3		; Not available, but mid pak is in!
	jmp short @@EXT 	; exit with return code.
@@INMID:
	mov	ax,2		; Sound driver resident, through MIDPAK.
	jmp short @@EXT
@@NEX:
	cmp	word ptr [si],454Bh ; equal?
        jne     @@CIOUT         ; exit if not equal
	cmp	word ptr [si+2],4E52h    ; equal?
        jne     @@CIOUT
@@OK:	mov	ax,1
@@EXT:
	pop	si
	pop	ds
	ret
@@CIOUT:xor	ax,ax		; Zero return code.
	jmp short @@EXT
CheckIn	endp

InstallINT Proc	 near C MYDATA:WORD
;; Usage: IntallINT(&parms)
;; offset 0: interupt
;;        2: offset of interupt code
;;        4: segment of interupt code
	PushCREGS
	mov	bx,[MYDATA]	; Get address of parameter table
        mov     ax,[bx]         ; get the interupt vector.
        mov     di,ax           ; save interupt vector into DI as well
        mov     si,[bx+2]       ; get offset
        mov     ds,[bx+4]       ; get segment.
        mov     ah,35h          ; Get interupt vector
        int     21h             ; Do DOS call to get vector.
	mov	ds:[si-10],bx	; Save the old offset.
	mov	ds:[si-8],es	; Save the old segment
        cld
        xor     ax,ax
        mov     es,ax
	ShiftL	di,2		;
        mov     ax,si           ; get offset.
        cli
        stosw
        mov     ax,ds           ; code segment
        stosw                   ; store it.
        sti
        xor     ax,ax           ; Success
	PopCREGS
	nope
	nope	
	ret
InstallINT endp

UnLoad  Proc	near C MYDATA:WORD
;; Usage: UnLoad(&vector)
;; Returns: AX = 0 success
;           AX nonzero, couldn't unload interupt vector.
	PushCREGS
	mov	ax,68Fh ; Stop sound playback!
	int	KINT	; Invoke interrupt.
	WaitSound
	mov	ax,692h ; Deinstall hardware vectors.
	int	KINT
	mov	bx,[MYDATA]	; get address of interupt vector
        mov     bx,[bx]         ; get the interupt vector.
        mov     dx,bx           ; put it into DX as well
	ShiftL	bx,2		;
        xor     ax,ax
        mov     ds,ax           ; Segment zero
	lds	si,ds:[bx]	; get address of interupt vector
        or      si,si           ; zero?
        jz      @@UOUT          ; exit if zero
	cmp	word ptr ds:[si-2],524Bh ;'KR' Is this a kernel installed interupt?
        push    ds              ; save DS
        mov     ax,dx           ; Get interupt vector.
        mov     ah,25h          ; Do DOS 25h set interupt vector.
	mov	dx,ds:[si-10]	 ; get old offset
	mov	ds,ds:[si-8]	; get old segment
        int     21h             ; set interupt vector.
        pop     ax              ; get back segment of program.
IF	ISEXE
        sub     ax,10h          ; point to program's PSP
ENDIF
        mov     es,ax
	push	es
	mov	es,[es:2Ch]	; Environment space.
	mov	ah,49h
	int	21h		; Free it up.
	pop	es
        mov     ah,49h          ; free memory.
        int     21h             ; free up the memory used by us.
@@EXIT: PopCREGS
	nope
	nope
        ret
@@UOUT: mov     ax,1
        jmp short @@EXIT
UnLoad 	endp

;; This procedure parses the command line and builds an array of
;; pointers to each argument.  Arguments are seperated by space's.
;; these spaces get replaced by zero bytes.
_argc	dw	 0	 ; The argument count
_argv	dw	16 dup(0) ; Up to 16 arguments.
command db	128 dup(?)

ParseCommandLine Proc	near
	mov	[_argc],0
	cmp	[byte ptr es:80h],2
	jb	@@END
	xor	cx,cx
	mov	cl,[es:80h]	; Get length.
	SwapSegs
	dec	cx		; Less one
	xlea	di,[command]
	mov	si,82h
	rep	movsb
	push	cs
	pop	ds
	xlea	di,[_argv]	; Argument list.
	xlea	si,[command]	; Start address.
@@SET:	inc	[_argc] 	; Increment argument counter.
	mov	ax,si		; Base argument addres.
	stosw
@@NEX:	lodsb			; Get characters until we hit space of eol
	cmp	al,32
	jne	@@NEX2
	mov	byte ptr ds:[si-1],0 ; Turn space into a zero byte.
	jmp short @@SET
@@NEX2:
	cmp	al,13
	je	@@END1
	or	al,al
	jnz	@@NEX		; Keep skipping to next arg.
@@END1: mov	byte ptr ds:[si-1],0	; Zero byte terminate last arg
@@END:
	ret
ParseCommandLine endp

EXTRN SYSCALL wssPresenceDetection:NEAR
EXTRN SYSCALL wssConfigureHardware:NEAR

;;************************************************************************
;; Unique harware init code.
;;************************************************************************
BINARY_COMPATIBLE  equ 1

place_on_stack	MACRO value
IFDEF BINARY_COMPATIBLE
		push	ax
		push	bp
		mov	bp, sp
		mov	WORD PTR [bp+2], value 	
		pop	bp
ELSE
		push value
ENDIF
	ENDM

HardwareInit Proc	near
        call    wssPresenceDetection
        or      ax, ax
        jnz     SHORT @@Configure
        mov     ax, 1
        jmp     SHORT @@NOKS      
@@Configure:
	place_on_stack 7	; irq
	place_on_stack 1	; dma
	place_on_stack 0	; far ptr to wss config	struc
	place_on_stack 0        ; wss config struc.
        call    wssConfigureHardware
@@OKS:	xor	ax,ax
@@NOKS:
	ret
HardwareInit endp

	end
