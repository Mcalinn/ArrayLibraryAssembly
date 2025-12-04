# Array Library (ASM x86-64)

A small dynamic array library in assembly language for working with 32-bit unsigned integers (uint32_t). Implemented: creation, addition, insertion, deletion, sum calculation, min/max search, and memory deallocation.

The library supports both platforms:
- **Windows**: Win64 ABI (arguments in RCX/RDX/R8/R9, 32-byte shadow space)
- **Linux**: SysV ABI (arguments in RDI/RSI/RDX/RCX/R8/R9)

The code automatically adapts to the target platform through conditional compilation (`%if IS_WIN64`).

## Memory Layout
```
offset 0  (8 bytes)   size     (uint64_t, current number of elements)
offset 8  (8 bytes)   capacity (uint64_t, max elements without reallocation)
offset 16 (data)      data[]   (sequence of uint32_t elements)
```

## Basic Types
```
Array* points to the beginning of the block (size at offset 0).
```

## Implemented Functions (Windows Signatures)
Below is which registers take parameters in Windows x64 ABI.

Functions (Windows x64 ABI):

- new_array(capacity)
	- Purpose: Create a new array (capacity=0 => default 4)
	- Parameters: RCX = capacity (uint64)
	- Returns: RAX = Array* or 0 on error

- free_array(ptr)
	- Purpose: Free array memory
	- Parameters: RCX = Array*
	- Returns: nothing

- resize_array(old_ptr, new_capacity)
	- Purpose: Change capacity, possibly moving buffer
	- Parameters: RCX = old Array*, RDX = new capacity (uint64)
	- Returns: RAX = new Array* or 0 on error

- push_element(&ptr, value)
	- Purpose: Add element to end; resize if space needed
	- Parameters: RCX = address of pointer variable (Array**), RDX = value (uint32)
	- Returns: nothing

- insert_at(&ptr, index, value)
	- Purpose: Insert element at index (if index > size, append at end)
	- Parameters: RCX = Array**, RDX = index (uint64), R8D = value (uint32)
	- Returns: nothing

- remove_at(&ptr, index)
	- Purpose: Remove element at index (does nothing if index >= size)
	- Parameters: RCX = Array**, RDX = index (uint64)
	- Returns: nothing

- sum_array(ptr)
	- Purpose: Calculate sum of all elements
	- Parameters: RCX = Array*
	- Returns: RAX = sum (uint64)

- min_array(ptr)
	- Purpose: Find minimum element (0 if empty/NULL)
	- Parameters: RCX = Array*
	- Returns: RAX = min (uint32)

- max_array(ptr)
	- Purpose: Find maximum element (0 if empty/NULL)
	- Parameters: RCX = Array*
	- Returns: RAX = max (uint32)

Note: `fill_array`, `find_value`, `copy_array`, `sort_array` mentioned earlier but not implemented / exported twice (artifact). Can be added similarly if needed.

## Linux Implementation
In `main_linux.asm`, SysV ABI registers are used:
| Function     | Parameters (Linux)                      |
|--------------|------------------------------------------|
| new_array    | RDI = capacity                           |
| push_element | RDI = Array**, ESI = value               |
| insert_at    | RDI = Array**, RSI = index, EDX = value  |
| remove_at    | RDI = Array**, RSI = index               |
| sum_array    | RDI = Array*                             |
| min_array    | RDI = Array*                             |
| max_array    | RDI = Array*                             |
| free_array   | RDI = Array*                             |

All functions in `array_lib.asm` automatically detect output format (`__OUTPUT_FORMAT__`) and use corresponding registers.

## Adding / Modifying Data (Windows)
In `main_windows.asm`, the following is currently executed:
```
push_element(&array_ptr, 10)
push_element(&array_ptr, 20)
push_element(&array_ptr, 30)
remove_at(&array_ptr, 1)        ; removes value 20
insert_at(&array_ptr, 1, 25)    ; inserts 25 at position 1
sum_array(array_ptr)
min_array(array_ptr)
max_array(array_ptr)
free_array(array_ptr)
```
To test with different values:
1. Open `main_windows.asm`.
2. Find blocks:
	- `mov rdx, 10` / `mov rdx, 20` / `mov rdx, 30` — replace numbers (e.g., with `-5`, `123`, `0`).
3. Add additional elements by copying the block:
	```nasm
	lea rcx, [rel array_ptr]
	mov rdx, <VALUE>
	call push_element
	```
4. Change index in `remove_at` / `insert_at` (register `RDX` for Windows).
5. Save file and run build.

## Building
Two methods available: `build.sh` script or `Makefile`.

### Windows (MSYS2 / Git Bash)
```bash
bash build.sh
```
The script:
- Cleans old object files.
- Assembles `main_windows.asm` and `array_lib.asm` (`nasm -f win64`).
- Links via `gcc` to `msvcrt` and `kernel32`.
- Runs `./test_program.exe`.

### Linux
When running the script in Linux environment, it selects the `build_linux` branch.
```bash
bash build.sh
```
Or manually:
```bash
nasm -f elf64 main_linux.asm -o main.o
nasm -f elf64 array_lib.asm -o array_lib.o
gcc main.o array_lib.o -o test_program
./test_program
```

### Makefile (cross-platform)
```bash
make
```
Make automatically selects format (win64/elf64) by the `OS` variable.

## Expected Output Example (Windows)
```
after new
after push 1
after push 2
after push 3
after remove
after insert
after sum
min_array result: 10
max_array result: 30
min=10 max=30
free_array entry: 0x............
free_array exit:  0x............
after free
```
Min/max values depend on your changes.

## Expected Output Example (Linux)
```
[Linux] Start
[Linux] After new_array
[Linux] After push 1
[Linux] After push 2
[Linux] After push 3
[Linux] After remove
[Linux] After insert
[Linux] After sum
min_array result: 10
max_array result: 30
[Linux] After min
[Linux] After max
[Linux] After free
```
Debug messages `[Linux] ...` are output via `write` syscall in `main_linux.asm`.

## Correctness Verification
1. Change the set of values, rebuild — verify that `min` is truly minimum and `max` is maximum.
2. Delete an element — verify it's gone.
3. Insert element at position 0 — check that others are shifted.
4. Call `sum_array` after modifications and manually verify the sum.
5. Test with empty array (comment out all `push_element`) — `min_array` and `max_array` return 0 (behavior can be changed if desired).

## API Extension Ideas
- Implement `fill_array(ptr, value)` — write `value` to all elements.
- `find_value(ptr, value)` — linear search, return index or -1.
- `copy_array(ptr)` — allocate new block, copy data.
- `sort_array(ptr)` — bubble sort or more efficient sorting.
- Add bounds checking and error codes (e.g., return -1 in RAX on errors).

## ABI Subtleties (Windows)
- Parameters: RCX, RDX, R8, R9 (rest via stack, not used here).
- Before calling CRT functions (`malloc`, `free`, `printf`), stack alignment to 16 bytes is required.
- Shadow space 32 bytes is reserved in the calling function — current implementation uses `sub rsp, 32` before calls.
- Callee-saved registers (RBX, RBP, RDI, RSI, R12–R15) are preserved when needed.

## ABI Subtleties (Linux)
- Parameters: RDI, RSI, RDX, RCX, R8, R9 (rest via stack).
- For varargs functions (e.g., `printf`), set `AL` to 0 before the call (number of vector registers): `xor eax, eax`.
- Stack alignment to 16 bytes is mandatory before function calls — `push rbp; mov rbp, rsp` at function start ensures this.
- Callee-saved registers: RBX, RBP, R12–R15.

## Cross-Platform Compilation
The library uses NASM conditional macros for automatic adaptation:
```nasm
%ifidni __OUTPUT_FORMAT__, win64
%define IS_WIN64 1
%else
%define IS_WIN64 0
%endif
```
All functions check `IS_WIN64` and use corresponding registers and calling conventions.

## Common Problems
Common issues and solutions:

- Segmentation fault after `free_array`:
	- Cause: Stack alignment violated or saved register not restored.
	- Solution: Check `push/pop` parity, correct `sub/add rsp`, verify alignment `rsp % 16 == 0` before `malloc/free/printf` calls.

- Incorrect min/max:
	- Cause: Wrong values passed to `push_element` (e.g., sign error or argument order mixed up).
	- Solution: Verify register loading in `main_windows.asm` before call (`RCX = &ptr`, `RDX = value`).

- Nothing printed:
	- Cause: Build error or missing libraries (`msvcrt`).
	- Solution: Verify `gcc` and `nasm` are present, rebuild (`bash build.sh`), check executable runs without errors.

- Identical min and max values (e.g., `min=30 max=30` with different elements):
	- Cause: During `printf` call, min value in `RDX` was overwritten by second `max_array` call (argument clobber), so both became identical.
	- Solution: Call `min_array` first, save result to memory or non-clobbered register/variable (`min_tmp`), then call `max_array` and only then load saved min into `RDX` before `printf` (as in updated `main_windows.asm`).

- Segmentation fault on Linux when calling library functions:
	- Cause: Calling convention mismatch (e.g., function expects parameter in RDI but passed in RCX).
	- Solution: Ensure `array_lib.asm` compiled with `-f elf64` (NASM automatically sets `__OUTPUT_FORMAT__` to `elf64`, activating SysV ABI). Verify `main_linux.asm` uses `global main` (not `_start`) for proper gcc linking.

- Crash inside `printf` on Linux:
	- Cause: Register `AL` not set to 0 before varargs function call.
	- Solution: Add `xor eax, eax` before `call printf` in Linux code branches.

## How to Change min/max Behavior for Empty Array
Currently, 0 is returned for empty or NULL array. Change options:
1. Return special value: Replace `xor eax,eax` with `mov eax,0xFFFFFFFF` (for -1) at `.min_ret_zero` and `.max_ret_zero` labels.
2. Add global error flag: Set 1 in some global variable.

## Cleanup of Diagnostic Output
In `array_lib.asm` there are format strings and `printf` calls for logging:
- `free_array`: logs entry/exit with pointer address
- `resize_array`: logs old pointer and new capacity (Windows only)
- `min_array`: logs found minimum value
- `max_array`: logs found maximum value

For clean release build, remove:
1. Blocks between comments `; log entry` / `; log exit` / `; log result` in functions
2. Format strings in `.data` section (`fmt_free_entry`, `fmt_free_exit`, `fmt_resize_entry`, `fmt_resize_exit`, `fmt_min_result`, `fmt_max_result`)
3. Debug `write` syscalls in `main_linux.asm` (messages `[Linux] ...`)

Or add macro-flag `ENABLE_LOGGING` for conditional compilation.

## Quick Checklist for Changing Values
1. Edit numbers in `mov rdx, <value>` for `push_element`.
2. Change index in `mov rdx, <index>` before `remove_at` / `insert_at`.
3. Rebuild: `bash build.sh`.
4. Check lines `min=..., max=...`.

## License / Usage

