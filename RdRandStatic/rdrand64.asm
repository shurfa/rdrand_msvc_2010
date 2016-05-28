; rdrand64.asm provides 64-bit assembly implementations of functions which invoke RDRAND
; suitable for assembly with 64-bit MASM (ML64.EXE)
;
; Although this is 64-bit code, we refer to EAX rather than
; RAX, because the output is still a 32-bit value
;
; Author: Stephen Higgins
; Blog: http://blog.viathefalcon.net/
; Twitter: @viathefalcon
;

PUBLIC rdrandx64
.CODE
	ALIGN 8
rdrandx64 PROC FRAME
; bool rdrandx64(__deref_out unsigned* dest)
; ecx <= dest
	.endprolog

	db 00Fh, 0C7h, 0F0h	; Invoke RDRAND via its opcode [1], [2]
	jnc rdrand_err		; If no value is/was available, jump down
	mov [rcx], eax		; Move the random value from EAX into the destination address (received via RCX)
	mov eax, 1			; Set true into EAX
	ret					; Return with result in EAX

rdrand_err:
	mov eax, 0			; Set false into EAX
	ret					; Return with result in EAX

	ALIGN 8
rdrandx64 ENDP

rdrandx64_uniform PROC PUBLIC FRAME
; unsigned rdrandx64_uniform(__in unsigned bound)
; rcx = bound
	push rbp
	.pushreg rbp
    sub rsp, 08h
    .allocstack 08h
	mov rbp, rsp
	.setframe rbp, 0
	.endprolog

	db 00Fh, 0C7h, 0F0h		; Invoke RDRAND via its opcode [1], [2]
	jc rdrand_ok
	mov rax, rcx			; Set the result to be equal to the range to indicate the error
	jmp epilogue

rdrand_ok:
	; Push the generated value onto the FPU stack (via the local call stack)
	mov [rsp], rax
	fild qword ptr [rsp]

	; Push the denominator
	mov rax, 0FFFFFFFFh		; The maximum value returnable by RDRAND (32-bit)
	mov [rsp], rax
	fild qword ptr [rsp]
	fdiv					; Divide to obtain the scaling factor

	; Multiply by the bound
	dec rcx					; Decrement the bound such that the result never exceeds it
							; (and to spare us faffing about with the rounding mode)
	mov [rsp], rcx
	fild qword ptr [rsp]
	fmul

	; Get out the result
	fist dword ptr [rsp]
	mov eax, dword ptr [rsp]

epilogue:
	add rsp, 08h
	pop rbp
	ret

	ALIGN 8
rdrandx64_uniform ENDP
END

; [1] Because we don't specify a REX prefix, the instruction's output is 32-bit
; [2] The destination register is specified by the final (MOD R/M) byte:
;	  F0 = C0 | 30, C0 = Register addressed to EAX, c.f. http://www.c-jump.com/CIS77/CPU/x86/X77_0060_mod_reg_r_m_byte.htm