#!/bin/bash



# Проверка наличия необходимых инструментов
command -v nasm >/dev/null 2>&1 || { echo "Nasm не найден"; exit 1; }
command -v gcc >/dev/null 2>&1 || { echo "GCC не найден"; exit 1; }

# Очистка старых файлов
cleanup() {
    echo "Очистка старых файлов..."
    rm -f *.o *.obj test_program test_program.exe
}

cleanup

# Функция сборки Windows
build_windows() {
    echo "Собираем Windows main"

    # Проверка файлов
    [[ ! -f main_windows.asm ]] && { echo "main_windows.asm не найден"; exit 1; }
    [[ ! -f array_lib.asm ]] && { echo "array_lib.asm не найден"; exit 1; }

    # Компиляция NASM
    # Assemble with debug info (use CodeView for win64)
    nasm -g -F cv8 -f win64 main_windows.asm -o main.obj || exit 1
    nasm -g -F cv8 -f win64 array_lib.asm -o array_lib.obj || exit 1

    # Link with debug info
    gcc -g main.obj array_lib.obj -o test_program.exe -lkernel32 -lmsvcrt || exit 1

    # Запуск программы
    echo "Запуск Windows программы:"
    ./test_program.exe
}

# Функция сборки Linux
build_linux() {
    echo "Собираем Linux main"

    [[ ! -f main_linux.asm ]] && { echo "main_linux.asm не найден"; exit 1; }
    [[ ! -f array_lib.asm ]] && { echo "array_lib.asm не найден"; exit 1; }

    nasm -g -F dwarf -f elf64 main_linux.asm -o main.o || exit 1
    nasm -g -F dwarf -f elf64 array_lib.asm -o array_lib.o || exit 1

    gcc -g main.o array_lib.o -o test_program || exit 1

    echo "Запуск Linux программы:"
    ./test_program
}

# Определение ОС
case "$OSTYPE" in
    linux-gnu*) build_linux ;;
    msys*|cygwin*) build_windows ;;
    *) echo "Неизвестная система: $OSTYPE"; exit 1 ;;
esac
