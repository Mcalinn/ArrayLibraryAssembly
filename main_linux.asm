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

section .text
main:
    push rbp
    mov rbp, rsp
    
    ; new_array(4)
    mov rdi, 4
    call new_array
    mov [rel array_ptr], rax

    ; push_element(&array_ptr, 10)
    lea rdi, [rel array_ptr]
    mov esi, 10
    call push_element
    
    ; push_element(&array_ptr, 20)
    lea rdi, [rel array_ptr]
    mov esi, 20
    call push_element
    
    ; push_element(&array_ptr, 30)
    lea rdi, [rel array_ptr]
    mov esi, 30
    call push_element

    ; remove_at(&array_ptr, 1)
    lea rdi, [rel array_ptr]
    mov rsi, 1
    call remove_at

    ; insert_at(&array_ptr, 1, 25)
    lea rdi, [rel array_ptr]
    mov rsi, 1
    mov edx, 25
    call insert_at

    ; sum_array(array_ptr)
    mov rdi, [rel array_ptr]
    call sum_array

    ; min_array(array_ptr)
    mov rdi, [rel array_ptr]
    call min_array

    ; max_array(array_ptr)
    mov rdi, [rel array_ptr]
    call max_array

    ; free_array(array_ptr)
    mov rdi, [rel array_ptr]
    call free_array

    ; return 0
    xor eax, eax
    pop rbp
    ret
