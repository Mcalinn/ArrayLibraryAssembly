global main
extern new_array
extern push_element
extern remove_at
extern insert_at
extern sum_array
extern free_array
extern min_array
extern max_array
extern ExitProcess
extern puts
extern printf

section .data
array_ptr dq 0        ; Array* ptr, изначально NULL
min_tmp   dq 0        ; временное хранение значения min
msg_new db "after new",0
msg_push1 db "after push 1",0
msg_push2 db "after push 2",0
msg_push3 db "after push 3",0
msg_remove db "after remove",0
msg_insert db "after insert",0
msg_sum db "after sum",0
msg_free db "after free",0
fmt_minmax db "min=%d max=%d",10,0

section .text
main:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    ; -------------------------
    ; Создание нового массива с capacity = 4
    mov rcx, 4
    call new_array
    mov [rel array_ptr], rax   ; сохраняем указатель
    mov rcx, msg_new
    call puts

    ; -------------------------
    ; push_element(array_ptr, 10)
    lea rcx, [rel array_ptr]   ; адрес переменной Array*
    mov rdx, 10
    call push_element
    mov rcx, msg_push1
    call puts

    ; push_element(array_ptr, 20)
    lea rcx, [rel array_ptr]
    mov rdx, 20
    call push_element
    mov rcx, msg_push2
    call puts

    ; push_element(array_ptr, 30)
    lea rcx, [rel array_ptr]
    mov rdx, 30
    call push_element
    mov rcx, msg_push3
    call puts

    ; -------------------------
    ; remove_at(array_ptr, 1)
    lea rcx, [rel array_ptr]
    mov rdx, 1
    call remove_at
    mov rcx, msg_remove
    call puts

    ; -------------------------
    ; insert_at(array_ptr, 1, 25)
    lea rcx, [rel array_ptr]
    mov rdx, 1
    mov r8d, 25
    call insert_at
    mov rcx, msg_insert
    call puts

    ; -------------------------
    ; sum_array(array_ptr)
    mov rcx, [rel array_ptr]   ; передаём Array* в RCX
    call sum_array             ; сумма вернётся в RAX, можно использовать
    mov rcx, msg_sum
    call puts

    ; -------------------------
    ; min/max and print
    mov rcx, [rel array_ptr]
    call min_array               ; RAX = min
    mov [rel min_tmp], rax       ; сохранить min, т.к. RDX будет затерт в max_array
    mov rcx, [rel array_ptr]
    call max_array               ; RAX = max
    mov r8, rax                  ; второй аргумент printf (max)
    mov rdx, [rel min_tmp]       ; восстановить min в RDX (первый аргумент после format)
    lea rcx, [rel fmt_minmax]
    call printf

    ; -------------------------
    ; free_array(array_ptr)
    mov rcx, [rel array_ptr]
    call free_array
    mov rcx, msg_free
    call puts

    ; -------------------------
    ; Выход
    mov rcx, 0
    call ExitProcess
    ; In case ExitProcess returns (it shouldn't), restore stack
    add rsp, 32
    pop rbp
    ret
