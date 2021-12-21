ifeq ($(origin CC), default)
CC := cc
endif
ifeq ($(origin LD), default)
LD := ld
endif
OBJCOPY ?= objcopy
ifeq ($(origin AR), default)
AR := ar
endif

CFLAGS  ?= -Wall -Wextra -O2 -pipe
LDFLAGS ?=

INTERNALLDFLAGS :=                              \
	-Treduced-gnu-efi/gnuefi/elf_x86_64_efi.lds \
	-nostdlib                                   \
	-zmax-page-size=0x1000                      \
	-melf_x86_64                                \
	-static                                     \
	-pie                                        \
	--no-dynamic-linker                         \
	-ztext

INTERNALCFLAGS :=                \
	-I.                          \
	-Ireduced-gnu-efi/inc        \
	-Ireduced-gnu-efi/inc/x86_64 \
	-DGNU_EFI_USE_MS_ABI         \
	-std=gnu11                   \
	-ffreestanding               \
	-fshort-wchar                \
	-fno-stack-protector         \
	-fpie                        \
	-fno-lto                     \
	-m64                         \
	-march=x86-64                \
	-mabi=sysv                   \
	-mno-80387                   \
	-mno-mmx                     \
	-mno-3dnow                   \
	-mno-sse                     \
	-mno-sse2                    \
	-mno-red-zone                \
	-MMD

CFILES      := $(shell find ./src -type f -name '*.c')
OBJ         := $(CFILES:.c=.o)
HEADER_DEPS := $(CFILES:.c=.d)

.PHONY: all
all: HELLO.EFI

reduced-gnu-efi:
	git clone https://github.com/limine-bootloader/reduced-gnu-efi.git

reduced-gnu-efi/gnuefi/crt0-efi-x86_64.o reduced-gnu-efi/gnuefi/libgnuefi.a: reduced-gnu-efi
	$(MAKE) -C reduced-gnu-efi/gnuefi CC="$(CC)" AR="$(AR)" ARCH=x86_64

HELLO.EFI: hello.elf
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 $< $@

hello.elf: reduced-gnu-efi/gnuefi/crt0-efi-x86_64.o reduced-gnu-efi/gnuefi/libgnuefi.a $(OBJ)
	$(LD) $^ $(LDFLAGS) $(INTERNALLDFLAGS) -o $@

-include $(HEADER_DEPS)

%.o: %.c reduced-gnu-efi
	$(CC) $(CFLAGS) $(INTERNALCFLAGS) -c $< -o $@

ovmf:
	mkdir -p ovmf
	cd ovmf && curl -o OVMF-X64.zip https://efi.akeo.ie/OVMF/OVMF-X64.zip && unzip OVMF-X64.zip

.PHONY: run
run: all ovmf
	mkdir -p boot/EFI/BOOT
	cp HELLO.EFI boot/EFI/BOOT/BOOTX64.EFI
	qemu-system-x86_64 -M q35 -drive file=fat:rw:boot -bios ovmf/OVMF.fd
	rm -rf boot

.PHONY: clean
clean:
	rm -rf HELLO.EFI hello.elf $(OBJ) $(HEADER_DEPS)

.PHONY: distclean
distclean: clean
	rm -rf reduced-gnu-efi ovmf
