# NicaClaw-Lite Rebranding and Optimization Tasks

## Overall Goal
The goal is to rebrand PicoClaw to NicaClaw, and optimize the engine to run on an ESP32 with 1MB of RAM.
The system will now use Go + C + ASM via CGO.

## Instructions for NicaClaw Agent
Please execute the following tasks. Once you have completed a task, mark it as `[x]` in this file.

- [ ] **Task 1: Rebrand to NicaClaw**
  - Search the codebase for all occurrences of "PicoClaw" and rename them to "NicaClaw" (or "nicaclaw-lite" depending on context).
  - Update `go.mod` to have `module nicaclaw-lite` and `go 1.23`. Update any inner module packages imports to `nicaclaw-lite/...`.

- [ ] **Task 2: Assembly Hotspot Implementation**
  - Create the file `hotspot.asm` in the root of the project with the following AVX2 instructions:
```nasm
; hotspot.asm - NicaClaw ASM hotspots
BITS 64
section .text

global asm_memcpy_avx2
global asm_zero512

; AVX2 memcpy 32 bytes/ciclo (vs 8 rep movsb)
asm_memcpy_avx2:
    mov rax, rdi      ; dst
    mov rbx, rsi      ; src
    mov rcx, rdx      ; count
    shr rcx, 5        ; /32 bytes
    jz .tail

.loop:
    vmovdqu ymm0, [rbx]
    vmovdqu ymm1, [rbx+32]
    vmovdqu ymm2, [rbx+64]
    vmovdqu ymm3, [rbx+96]
    vmovdqu [rax], ymm0
    vmovdqu [rax+32], ymm1
    vmovdqu [rax+64], ymm2
    vmovdqu [rax+96], ymm3
    add rax, 128
    add rbx, 128
    dec rcx
    jnz .loop

.tail:
    mov rcx, rdx
    and rcx, 31
    rep movsb
    vzeroupper
    ret

; Zero 512 bytes (token cache)
asm_zero512:
    xor rax, rax
    mov rcx, 512/8
    rep stosq
    ret
```

- [ ] **Task 3: CGO Integration**
  - Update `main.go` and other relevant files to integrate the use of ASM and CGO.
  - Make sure to include CFLAGS `-mavx2 -O3 -ffast-math` and LDFLAGS `-lcurl -static`.
  - Add the external function signatures for the ASM routines so they can be called from Go.

Please make the code changes, ensure it builds successfully, and then update this file with `[x]` before finishing.
