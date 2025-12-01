global _start
extern new_array
extern push_element
extern remove_at
extern insert_at
extern sum_array
extern free_array

section .text
_start:
    mov rdi, 4
    call new_array
    mov rbx, rax

    mov rdi, rbx
    mov esi, 10
    call push_element
    mov rdi, rbx
    mov esi, 20
    call push_element
    mov rdi, rbx
    mov esi, 30
    call push_element

    mov rdi, rbx
    mov rsi, 1
    call remove_at

    mov rdi, rbx
    mov rsi, 1
    mov edx, 25
    call insert_at

    mov rdi, rbx
    call sum_array

    mov rdi, rbx
    call free_array

    mov rax, 60
    xor rdi, rdi
    syscall
