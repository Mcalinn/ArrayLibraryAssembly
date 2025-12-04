ifeq ($(OS),Windows_NT)
    NASM_FMT=win64
    MAIN=main_windows.asm
    OBJ_EXT=obj
    OUT=test_program.exe
else
    NASM_FMT=elf64
    MAIN=main_linux.asm
    OBJ_EXT=o
    OUT=test_program
endif

all:
	nasm -f $(NASM_FMT) $(MAIN) -o main.$(OBJ_EXT)
	nasm -f $(NASM_FMT) array_lib.asm -o array_lib.$(OBJ_EXT)
	gcc main.$(OBJ_EXT) array_lib.$(OBJ_EXT) -o $(OUT)
 