; array_lib.asm
; ============================================================================
; NASM x86-64 Dynamic Array Library
; 
; Supports: Windows (Win64 ABI) and Linux (SysV ABI)
; Auto-detection: %ifidni __OUTPUT_FORMAT__, win64
;
; MEMORY LAYOUT:
;   [ptr + 0]   = size (uint64_t) — current number of elements
;   [ptr + 8]   = capacity (uint64_t) — max elements before realloc
;   [ptr + 16]  = data[] — array of uint32_t elements
;
; KEY RULES:
;   1. Stack alignment: 16-byte alignment BEFORE any function call
;   2. Windows shadow space: 32 bytes before malloc/free/printf
;   3. Linux varargs: xor eax,eax before printf (# vector registers)
;   4. All pointer parameters use pointer-to-pointer (Array**) for push/insert/remove
;      so the caller's array_ptr can be updated if reallocation happens
;
; COMMON MISTAKES:
;   - Not aligning stack → crashes on malloc/free/printf
;   - Mixing RCX/RDI between platforms → ABI mismatch → segfault
;   - Not restoring clobbered registers (RBX, R12–R15) → corruption
;   - Off-by-one in loops or array indexing → buffer overflow
; ============================================================================

default rel
extern malloc
extern free
extern printf

section .data
; Format strings for diagnostic output (can be removed for release builds)
fmt_free_entry db "free_array entry: %p",10,0
fmt_free_exit  db "free_array exit: %p",10,0
fmt_resize_entry db "resize_array entry: old=%p new_cap=%u",10,0
fmt_resize_exit  db "resize_array exit: new=%p",10,0
fmt_min_result db "min_array result: %u",10,0
fmt_max_result db "max_array result: %u",10,0

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
; new_array(capacity)
; PURPOSE: Allocate a new array structure with given capacity
;
; WINDOWS ABI:
;   Input:  RCX = initial_capacity (uint64_t)
;   Output: RAX = Array* (pointer to allocated block) or 0 on malloc failure
;
; LINUX ABI:
;   Input:  RDI = initial_capacity
;   Output: RAX = Array* or 0 on failure
;
; BEHAVIOR:
;   - If capacity is 0, defaults to 4 elements
;   - Allocates: 16 bytes (metadata) + capacity * 4 bytes (data)
;   - Initializes: size = 0, capacity = requested_capacity
;
; ERROR CASES:
;   - malloc() fails → returns 0 (must check RAX before use!)
;
; POTENTIAL BUGS:
;   - If you change the multiplier (shl rcx, 2 = *4), check element size expectations
;   - Capacity overflow: very large capacity * 4 might exceed heap → malloc fails silently
; ---------------------------
new_array:
    push rbp
    mov rbp, rsp
%if IS_WIN64
    mov rdi, rcx            ; Convert Win64 parameter to RDI (shared logic below)
%endif
    mov rax, rdi
    test rax, rax           ; Check if capacity == 0
    jnz .have_cap
    mov rax, 4              ; Default capacity if 0
.have_cap:
    mov rcx, rax            ; RCX = capacity
    shl rcx, 2              ; RCX *= 4 (each element is uint32_t = 4 bytes)
    add rcx, 16             ; RCX += 16 (metadata: size + capacity)
                            ; Now RCX = total bytes needed
%if IS_WIN64
    sub rsp, 32             ; Windows: reserve shadow space
    call malloc             ; RCX = size_to_allocate
    add rsp, 32
%else
    ; Linux: RDI = size for malloc
    mov rdi, rcx
    call malloc             ; RDI = size_to_allocate
%endif
    test rax, rax           ; Check malloc success
    jz .done_new            ; If malloc failed (RAX=0), return 0
    
    ; Initialize metadata (only if malloc succeeded)
    xor rdx, rdx            ; RDX = 0
    mov [rax], rdx          ; array->size = 0
    mov rdx, rcx
    sub rdx, 16             ; RDX = (total_bytes - 16) = data_size
    shr rdx, 2              ; RDX = data_size / 4 = capacity (convert bytes to elements)
    mov [rax + 8], rdx      ; array->capacity = capacity
.done_new:
    ; RAX already contains result (pointer or 0)
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
; push_element(&ptr, value)
; PURPOSE: Add element to end; auto-resize if capacity full
;
; WINDOWS ABI:  RCX = &array_ptr (Array**), RDX = value (uint32_t)
; LINUX ABI:    RDI = &array_ptr (Array**), ESI = value (uint32_t)
;
; KEY: Takes POINTER-TO-POINTER so reallocation updates caller's pointer!
;      Without this, realloc would move buffer but caller wouldn't know.
;
; BEHAVIOR:
;   1. If array NULL or full (size == capacity), resize to capacity*2
;   2. Place value at data[size], increment size
;
; POTENTIAL BUGS:
;   - Off-by-one in loop: check cmp/jb boundaries
;   - Doubling strategy wastes memory on many small pushes
;   - Stack alignment issues if RSP not % 16 == 0 before malloc/resize calls
;
; ---------------------------
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
; remove_at(&ptr, index)
; PURPOSE: Delete element at given index; shift remaining elements left
;
; WINDOWS ABI:  RCX = &array_ptr (Array**), RDX = index (uint64_t)
; LINUX ABI:    RDI = &array_ptr (Array**), RSI = index
;
; BEHAVIOR:
;   1. Check if index >= size (ignore if true)
;   2. Shift elements [index+1 .. size-1] one position left
;   3. Decrement size
;
; SHIFTING PATTERN (important!):
;   for (i = index; i < size-1; i++)
;     data[i] = data[i+1]
;   
;   Off-by-one errors here cause:
;   - Duplicate elements
;   - Lost elements
;   - Buffer overrun
;
; POTENTIAL BUGS:
;   - Using 32-bit counter when size is 64-bit → only removes first 2^32 elements
;   - Not updating size → effectively memory leak (space never reused)
;   - Shifting backwards instead of forward → double-delete
;
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
; insert_at(&ptr, index, value)
; PURPOSE: Insert element at index; shift remaining elements right
;
; WINDOWS ABI:  RCX = &array_ptr (Array**), RDX = index (uint64_t), R8D = value (uint32_t)
; LINUX ABI:    RDI = &array_ptr (Array**), RSI = index, EDX = value
;
; BEHAVIOR:
;   1. If index > size, insert at end (append)
;   2. Resize if needed (same as push_element)
;   3. Shift elements [index .. size-1] one position RIGHT
;   4. Place value at data[index]
;   5. Increment size
;
; SHIFTING PATTERN (backward to avoid overwrite):
;   for (i = size-1; i >= index; i--)  // BACKWARD!
;     data[i+1] = data[i]
;
;   Must go BACKWARD, not forward, or else we overwrite our own data!
;
; POTENTIAL BUGS:
;   - Shifting forward instead of backward → data loss!
;   - Not clamping index to size → inserting "past the end" works but is confusing
;   - Off-by-one in shift loop boundaries
;
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
; sum_array(ptr)
; PURPOSE: Calculate sum of all elements
;
; WINDOWS ABI:  RCX = Array*
; LINUX ABI:    RDI = Array*
;
; RETURNS: RAX = sum (uint64_t)
;
; BEHAVIOR:
;   1. If NULL or empty, return 0
;   2. Iterate through all elements, accumulate sum in RAX
;
; POTENTIAL BUGS:
;   - Sum overflow: if elements are large, sum can wrap (uint64_t max ≈ 18e18)
;     No error checking → silent overflow!
;   - Size corruption: if size is garbage, loop might iterate past allocated buffer
;
; IMPROVEMENT IDEAS:
;   - Check for overflow and set error flag
;   - Add optional max sum parameter to detect bugs
;
; ---------------------------
sum_array:
sum_array:
    ; accept RCX as parameter (Windows ABI) and move to RDI for existing logic
%if IS_WIN64
    mov rdi, rcx
%endif
    xor rax, rax
    test rdi, rdi
    jz .sum_ret
    mov rcx, [rdi]          ; RCX = size
    lea rsi, [rdi + 16]     ; RSI = &data[0]
    test rcx, rcx
    jz .sum_ret
.sum_loop:
    mov edx, [rsi]          ; EDX = data[i]
    add rax, rdx            ; RAX += data[i]
    add rsi, 4
    dec rcx
    jnz .sum_loop
.sum_ret:
    ret

; ---------------------------
; min_array(ptr)
; PURPOSE: Find minimum element in array
;
; WINDOWS ABI:  RCX = Array*
; LINUX ABI:    RDI = Array*
;
; RETURNS: EAX = min value (uint32_t), or 0 if empty/NULL
;
; BEHAVIOR:
;   1. If NULL or empty, return 0 (AMBIGUOUS! Could also mean min value IS 0)
;   2. Load first element as initial min
;   3. Compare all other elements, keep smallest
;
; POTENTIAL BUGS:
;   - Return value 0 is ambiguous: could mean empty OR min is actually 0
;     Caller can't distinguish! Consider returning special value (-1) for empty
;   - Size corruption: if size is wrong, might iterate past buffer
;   - Comparison logic (jge): must be STRICTLY GREATER to avoid comparing with self
;
; IMPROVEMENT IDEAS:
;   - Return -1 or UINT_MAX for error cases
;   - Add optional error pointer parameter
;   - Consider alternative comparison (jle vs jge)
;
; ---------------------------
; min_array
; accepts RCX = Array* (Windows ABI) or RDI (Linux), returns value in RAX (32-bit in EAX)
min_array:
    push rbp
    mov rbp, rsp
%if IS_WIN64
    mov rdi, rcx
%endif
    xor eax, eax            ; EAX = 0 (default return)
    test rdi, rdi           ; Check if NULL
    jz .min_ret_zero
    mov rcx, [rdi]          ; RCX = size
    lea rsi, [rdi + 16]     ; RSI = &data[0]
    test rcx, rcx           ; Check if empty
    jz .min_ret_zero
    mov eax, [rsi]          ; EAX = data[0] (initial min)
    dec rcx                 ; RCX-- (we already processed first element)
    add rsi, 4              ; RSI = &data[1]
.min_loop:
    mov edx, [rsi]          ; EDX = data[i]
    cmp edx, eax            ; Compare with current min
    jge .min_nochange       ; If edx >= eax, keep current min
    mov eax, edx            ; Else update min
.min_nochange:
    add rsi, 4
    dec rcx
    jnz .min_loop
    ; log result
%if IS_WIN64
    push rax                    ; save result
    sub rsp, 32                 ; shadow space
    lea rcx, [rel fmt_min_result]
    mov edx, eax                ; result as second arg
    call printf
    add rsp, 32
    pop rax                     ; restore result
%else
    push rax                    ; save result
    mov esi, eax                ; result as second arg
    lea rdi, [rel fmt_min_result]
    xor eax, eax                ; printf varargs requirement
    call printf
    pop rax                     ; restore result
%endif
    pop rbp
    ret
.min_ret_zero:
    xor eax, eax
    pop rbp
    ret

; ---------------------------
; max_array(ptr)
; PURPOSE: Find maximum element in array
;
; WINDOWS ABI:  RCX = Array*
; LINUX ABI:    RDI = Array*
;
; RETURNS: EAX = max value (uint32_t), or 0 if empty/NULL
;
; BEHAVIOR:
;   Same as min_array but with reversed comparison:
;   - If edx <= eax, keep current max
;   - If edx > eax, update to new max
;
; POTENTIAL BUGS:
;   - Same as min_array: return 0 is ambiguous
;   - Comparison must be jle (less-or-equal) not jge
;     Wrong comparison → returns min instead of max!
;
; ---------------------------
; max_array
; accepts RCX = Array* (Windows ABI) or RDI (Linux), returns value in RAX (32-bit in EAX)
max_array:
    push rbp
    mov rbp, rsp
%if IS_WIN64
    mov rdi, rcx
%endif
    xor eax, eax            ; EAX = 0 (default return)
    test rdi, rdi           ; Check if NULL
    jz .max_ret_zero
    mov rcx, [rdi]          ; RCX = size
    lea rsi, [rdi + 16]     ; RSI = &data[0]
    test rcx, rcx           ; Check if empty
    jz .max_ret_zero
    mov eax, [rsi]          ; EAX = data[0] (initial max)
    dec rcx                 ; RCX-- (we already processed first element)
    add rsi, 4              ; RSI = &data[1]
.max_loop:
    mov edx, [rsi]          ; EDX = data[i]
    cmp edx, eax            ; Compare with current max
    jle .max_nochange       ; If edx <= eax, keep current max (different from min!)
    mov eax, edx            ; Else update max
.max_nochange:
    add rsi, 4
    dec rcx
    jnz .max_loop
    ; log result
%if IS_WIN64
    push rax                    ; save result
    sub rsp, 32                 ; shadow space
    lea rcx, [rel fmt_max_result]
    mov edx, eax                ; result as second arg
    call printf
    add rsp, 32
    pop rax                     ; restore result
%else
    push rax                    ; save result
    mov esi, eax                ; result as second arg
    lea rdi, [rel fmt_max_result]
    xor eax, eax                ; printf varargs requirement
    call printf
    pop rax                     ; restore result
%endif
    pop rbp
    ret
.max_ret_zero:
    xor eax, eax
    pop rbp
    ret
