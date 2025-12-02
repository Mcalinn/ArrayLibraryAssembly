; array_lib.asm
; NASM x86-64 (Win64)
; Requires linking with C runtime (malloc/free)

default rel
extern malloc
extern free
extern printf

section .data
fmt_free_entry db "free_array entry: %p",10,0
fmt_free_exit  db "free_array exit: %p",10,0
fmt_resize_entry db "resize_array entry: old=%p new_cap=%u",10,0
fmt_resize_exit  db "resize_array exit: new=%p",10,0
fmt_min_dbg db "min_array dbg: size=%llu first=%u",10,0

section .text

; Detect output format to switch calling convention handling
%ifidni __OUTPUT_FORMAT__, win64
%define IS_WIN64 1
%else
%define IS_WIN64 0
%endif

; ---------------------------
; Exported functions
global new_array
global push_element
global remove_at
global insert_at
global sum_array
global free_array
global resize_array
global min_array
global max_array
global fill_array
global find_value
global min_array
global max_array
global copy_array
global sort_array

section .text

; ---------------------------
; new_array
; rdi = initial_capacity
; returns rax = pointer
new_array:
    push rbp
    mov rbp, rsp
%if IS_WIN64
    mov rdi, rcx
%endif
    mov rax, rdi
    test rax, rax
    jnz .have_cap
    mov rax, 4
.have_cap:
    mov rcx, rax
    shl rcx, 2
    add rcx, 16
%if IS_WIN64
    sub rsp, 32
    call malloc
    add rsp, 32
%else
    ; SysV: RDI = size for malloc
    mov rdi, rcx
    call malloc
%endif
    test rax, rax
    jz .done_new
    xor rdx, rdx
    mov [rax], rdx
    mov rdx, rcx
    sub rdx, 16
    shr rdx, 2
    mov [rax + 8], rdx
.done_new:
    pop rbp
    ret

; ---------------------------
; free_array
free_array:
%if IS_WIN64
    mov rdi, rcx
%endif
    test rdi, rdi
    jz .fret
    ; log entry
%if IS_WIN64
    lea rcx, [rel fmt_free_entry]
    mov rdx, rdi
    sub rsp, 32
    call printf
    add rsp, 32
%endif
    ; call free
%if IS_WIN64
    mov rcx, rdi
    sub rsp, 32
    call free
    add rsp, 32
%else
    ; RDI already holds the pointer
    call free
%endif
    ; log exit
%if IS_WIN64
    lea rcx, [rel fmt_free_exit]
    mov rdx, rdi
    sub rsp, 32
    call printf
    add rsp, 32
%endif
.fret:
    ret

; ---------------------------
; resize_array
; rdi = old array, rsi = new_capacity
; returns rax = new_ptr
resize_array:
    ; adapt Windows caller: RCX = old_array, RDX = new_capacity
%if IS_WIN64
    mov rdi, rcx
    mov rsi, rdx
%endif
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov r14, rdi
    mov r12, rsi
    ; log entry (old pointer in r14, new cap in r12)
%if IS_WIN64
    lea rcx, [rel fmt_resize_entry]
    mov rdx, r14
    mov r8d, r12d
    sub rsp, 40
    call printf
    add rsp, 40
%endif
    test r12, r12
    jnz .cap_ok
    mov r12, 4
.cap_ok:
    mov rax, r12
    shl rax, 2
    add rax, 16
%if IS_WIN64
    mov rcx, rax
    sub rsp, 32
    call malloc
    add rsp, 32
%else
    mov rdi, rax
    call malloc
%endif
    test rax, rax
    jz .oom
    mov r13, rax
    test rdi, rdi
    jz .init_new
    mov rbx, [rdi]
    mov rax, rbx
    cmp rax, r12
    cmova rax, r12
    lea rsi, [rdi + 16]
    lea rdi, [r13 + 16]
    mov rcx, rax
    test rcx, rcx
    jz .copy_done
.copy_loop:
    mov edx, [rsi]
    mov [rdi], edx
    add rsi, 4
    add rdi, 4
    dec rcx
    jnz .copy_loop
.copy_done:
    mov [r13], rax
    mov [r13 + 8], r12
%if IS_WIN64
    mov rcx, r14
    test rcx, rcx
    jz .finish
    sub rsp, 40
    call free
    add rsp, 40
%else
    mov rdi, r14
    test rdi, rdi
    jz .finish
    call free
%endif
.finish:
    mov rax, r13
    mov rdi, r14
    ; log exit (new pointer in r13)
%if IS_WIN64
    lea rcx, [rel fmt_resize_exit]
    mov rdx, r13
    sub rsp, 32
    call printf
    add rsp, 32
%endif
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.init_new:
    mov qword [r13], 0
    mov qword [r13 + 8], r12
    jmp .finish
.oom:
    xor rax, rax
    jmp .finish

; ---------------------------
; push_element
push_element:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
%if IS_WIN64
    mov rdi, rcx
    mov esi, edx
%endif
    mov r12, rdi
    mov rax, [r12]
    test rax, rax
    jz .need_new
    mov rbx, [rax]
    mov rcx, [rax + 8]
    cmp rbx, rcx
    jb .has_space
.need_new:
    mov rax, [r12]
    test rax, rax
    jz .alloc_init
    mov rcx, [rax + 8]
    test rcx, rcx
    jz .alloc_init
    shl rcx, 1
    jmp .do_resize
.alloc_init:
    mov rcx, 4
.do_resize:
    ; pass parameters for resize_array: RCX = old_array, RDX = new_capacity
%if IS_WIN64
    mov rdx, rcx
    mov rcx, [r12]
    sub rsp, 40
    call resize_array
    add rsp, 40
%else
    mov rsi, rcx
    mov rdi, [r12]
    call resize_array
%endif
    test rax, rax
    jz .oom
    mov [r12], rax
.has_space:
    mov rax, [r12]
    mov rbx, [rax]
    lea rdx, [rax + 16]
    mov dword [rdx + rbx*4], esi
    inc qword [rax]
    jmp .done_push
.oom:
    nop
.done_push:
    pop r12
    pop rbx
    pop rbp
    ret

; ---------------------------
; remove_at
remove_at:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
%if IS_WIN64
    mov rdi, rcx
    mov rsi, rdx
%endif
    mov r12, rdi
    mov rax, [r12]
    test rax, rax
    jz .done_rem
    mov rbx, [rax]
    mov rdx, rsi
    cmp rdx, rbx
    jae .done_rem
    lea rsi, [rax + 16]
    mov rcx, rdx
    mov r8, rbx
    dec r8
.shift_loop_r:
    cmp rcx, r8
    jg .set_size_r
    mov edx, [rsi + (rcx+1)*4]
    mov [rsi + rcx*4], edx
    inc rcx
    jmp .shift_loop_r
.set_size_r:
    dec qword [rax]
.done_rem:
    pop r12
    pop rbx
    pop rbp
    ret

; ---------------------------
; insert_at
insert_at:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
%if IS_WIN64
    mov r12, rcx
    mov r13, rdx
    mov ebx, r8d
%else
    mov r12, rdi
    mov r13, rsi
    mov ebx, edx
%endif
    mov rax, [r12]
    test rax, rax
    mov rax, [r12]
    test rax, rax
    jz .need_space_ins
    mov rcx, [rax]
    mov rdx, [rax + 8]
    cmp rcx, rdx
    jb .have_space_ins
.need_space_ins:
    mov rax, [r12]
    test rax, rax
    jz .alloc_init2
    mov rcx, [rax + 8]
    test rcx, rcx
    jz .alloc_init2
    shl rcx, 1
    jmp .do_resize2
.alloc_init2:
    mov rcx, 4
.do_resize2:
    ; pass parameters for resize_array: RCX = old_array, RDX = new_capacity
    mov rdx, rcx
    mov rcx, [r12]
    sub rsp, 40
    call resize_array
    add rsp, 40
    test rax, rax
    jz .oom_ins
    mov [r12], rax
.have_space_ins:
    mov rax, [r12]
    mov rcx, [rax]
    cmp r13, rcx
    jbe .ok_ins
    mov r13, rcx
.ok_ins:
    lea rdx, [rax + 16]
    test rcx, rcx
    jz .place_ins
    dec rcx
.shift_ins:
    cmp rcx, r13
    jb .place_ins
    mov edi, [rdx + rcx*4]
    mov [rdx + (rcx+1)*4], edi
    dec rcx
    jmp .shift_ins
.place_ins:
    mov dword [rdx + r13*4], ebx
    inc qword [rax]
    jmp .end_ins
.oom_ins:
    nop
.end_ins:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ---------------------------
; sum_array
sum_array:
sum_array:
    ; accept RCX as parameter (Windows ABI) and move to RDI for existing logic
%if IS_WIN64
    mov rdi, rcx
%endif
    xor rax, rax
    test rdi, rdi
    jz .sum_ret
    mov rcx, [rdi]
    lea rsi, [rdi + 16]
    test rcx, rcx
    jz .sum_ret
.sum_loop:
    mov edx, [rsi]
    add rax, rdx
    add rsi, 4
    dec rcx
    jnz .sum_loop
.sum_ret:
    ret

; ---------------------------
; min_array
; accepts RCX = Array* (Windows ABI), returns value in RAX (32-bit in EAX)
min_array:
%if IS_WIN64
    mov rdi, rcx
%endif
    xor eax, eax
    test rdi, rdi
    jz .min_ret_zero
    mov rcx, [rdi]
    lea rsi, [rdi + 16]
    test rcx, rcx
    jz .min_ret_zero
    mov eax, [rsi]
    ; debug print size and first element
    push rax            ; save first element (in eax)
    push rcx            ; save size
    sub rsp, 32         ; shadow space
    mov rdx, rcx        ; second arg: size
    mov r8d, eax        ; third arg: first element (32-bit)
    lea rcx, [rel fmt_min_dbg] ; format
    call printf
    add rsp, 32
    pop rcx             ; restore size
    pop rax             ; restore first element
    dec rcx
    add rsi, 4
.min_loop:
    mov edx, [rsi]
    cmp edx, eax
    jge .min_nochange
    mov eax, edx
.min_nochange:
    add rsi, 4
    dec rcx
    jnz .min_loop
    ret
.min_ret_zero:
    xor eax, eax
    ret

; ---------------------------
; max_array
; accepts RCX = Array* (Windows ABI), returns value in RAX (32-bit in EAX)
max_array:
%if IS_WIN64
    mov rdi, rcx
%endif
    xor eax, eax
    test rdi, rdi
    jz .max_ret_zero
    mov rcx, [rdi]
    lea rsi, [rdi + 16]
    test rcx, rcx
    jz .max_ret_zero
    mov eax, [rsi]
    dec rcx
    add rsi, 4
.max_loop:
    mov edx, [rsi]
    cmp edx, eax
    jle .max_nochange
    mov eax, edx
.max_nochange:
    add rsi, 4
    dec rcx
    jnz .max_loop
    ret
.max_ret_zero:
    xor eax, eax
    ret
