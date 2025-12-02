global main
extern new_array
extern push_element
extern remove_at
extern insert_at
extern sum_array
extern free_array
extern min_array
extern max_array

section .data
array_ptr dq 0
msg_start db "[Linux] Start",10
len_start equ $ - msg_start
msg_new db "[Linux] After new_array",10
len_new equ $ - msg_new
msg_push1 db "[Linux] After push 1",10
len_push1 equ $ - msg_push1
msg_push2 db "[Linux] After push 2",10
len_push2 equ $ - msg_push2
msg_push3 db "[Linux] After push 3",10
len_push3 equ $ - msg_push3
msg_remove db "[Linux] After remove",10
len_remove equ $ - msg_remove
msg_insert db "[Linux] After insert",10
len_insert equ $ - msg_insert
msg_sum db "[Linux] After sum",10
len_sum equ $ - msg_sum
msg_min db "[Linux] After min",10
len_min equ $ - msg_min
msg_max db "[Linux] After max",10
len_max equ $ - msg_max
msg_free db "[Linux] After free",10
len_free equ $ - msg_free

section .text
main:
    push rbp
    mov rbp, rsp
    
    ; print start message
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    lea rsi, [rel msg_start]
    mov rdx, len_start
    syscall
    
    ; new_array(4)
    mov rdi, 4
    call new_array
    mov [rel array_ptr], rax

    ; print after new
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_new]
    mov rdx, len_new
    syscall

    ; push_element(&array_ptr, 10)
    lea rdi, [rel array_ptr]
    mov esi, 10
    call push_element
    
    ; print after push 1
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_push1]
    mov rdx, len_push1
    syscall
    
    ; push_element(&array_ptr, 20)
    lea rdi, [rel array_ptr]
    mov esi, 20
    call push_element
    
    ; print after push 2
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_push2]
    mov rdx, len_push2
    syscall
    
    ; push_element(&array_ptr, 30)
    lea rdi, [rel array_ptr]
    mov esi, 30
    call push_element

    ; print after push 3
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_push3]
    mov rdx, len_push3
    syscall

    ; remove_at(&array_ptr, 1)
    lea rdi, [rel array_ptr]
    mov rsi, 1
    call remove_at

    ; print after remove
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_remove]
    mov rdx, len_remove
    syscall

    ; insert_at(&array_ptr, 1, 25)
    lea rdi, [rel array_ptr]
    mov rsi, 1
    mov edx, 25
    call insert_at

    ; print after insert
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_insert]
    mov rdx, len_insert
    syscall

    ; sum_array(array_ptr)
    mov rdi, [rel array_ptr]
    call sum_array

    ; print after sum
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_sum]
    mov rdx, len_sum
    syscall

    ; min_array(array_ptr)
    mov rdi, [rel array_ptr]
    call min_array

    ; print after min
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_min]
    mov rdx, len_min
    syscall

    ; max_array(array_ptr)
    mov rdi, [rel array_ptr]
    call max_array

    ; print after max
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_max]
    mov rdx, len_max
    syscall

    ; free_array(array_ptr)
    mov rdi, [rel array_ptr]
    call free_array

    ; print after free
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_free]
    mov rdx, len_free
    syscall

    ; return 0
    xor eax, eax
    pop rbp
    ret
