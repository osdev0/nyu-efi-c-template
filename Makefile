CC ?= cc
LD ?= ld
OBJCOPY ?= objcopy
AR ?= ar

CFLAGS  ?= -Wall -Wextra -O2 -pipe
LDFLAGS ?=

INTERNALLDFLAGS :=                      \
	-Tgnu-efi/gnuefi/elf_x86_64_efi.lds \
	-nostdlib                           \
	-zmax-page-size=0x1000              \
	-melf_x86_64                        \
	-static                             \
	-pie                                \
	--no-dynamic-linker                 \
	-ztext

INTERNALCFLAGS :=        \
	-I.                  \
	-Ignu-efi/inc        \
	-Ignu-efi/inc/x86_64 \
	-DGNU_EFI_USE_MS_ABI \
	-std=gnu11           \
	-ffreestanding       \
	-fshort-wchar        \
	-fno-stack-protector \
	-fpie                \
	-fno-lto             \
	-m64                 \
	-march=x86-64        \
	-mabi=sysv           \
	-mno-80387           \
	-mno-mmx             \
	-mno-3dnow           \
	-mno-sse             \
	-mno-sse2            \
	-mno-red-zone        \
	-MMD

CFILES      := $(shell find ./src -type f -name '*.c')
OBJ         := $(CFILES:.c=.o)
HEADER_DEPS := $(CFILES:.c=.d)

.PHONY: all
all: HELLO.EFI

gnu-efi:
	git clone https://git.code.sf.net/p/gnu-efi/code --branch=3.0.14 --depth=1 $@
	cp aux/elf/* gnu-efi/inc/
	# gnu-efi's build system is broken and fails to actually detect clang.
	# This is a workaround.
	sed 's/-maccumulate-outgoing-args//g' < "gnu-efi/Make.defaults" > sed.tmp
	mv sed.tmp "gnu-efi/Make.defaults"

gnu-efi/gnuefi/crt0-efi-x86_64.o gnu-efi/gnuefi/libgnuefi.a: gnu-efi
	$(MAKE) -C gnu-efi/gnuefi CC="$(CC)" AR="$(AR)" ARCH=x86_64

HELLO.EFI: hello.elf
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 $< $@

hello.elf: gnu-efi/gnuefi/crt0-efi-x86_64.o gnu-efi/gnuefi/libgnuefi.a $(OBJ)
	$(LD) $^ $(LDFLAGS) $(INTERNALLDFLAGS) -o $@

-include $(HEADER_DEPS)

%.o: %.c gnu-efi
	$(CC) $(CFLAGS) $(INTERNALCFLAGS) -c $< -o $@

ovmf:
	mkdir -p ovmf
	cd ovmf && curl -o OVMF-X64.zip https://efi.akeo.ie/OVMF/OVMF-X64.zip && unzip OVMF-X64.zip

.PHONY: run
run: ovmf
	mkdir -p boot/EFI/BOOT
	cp HELLO.EFI boot/EFI/BOOT/BOOTX64.EFI
	qemu-system-x86_64 -M q35 -drive file=fat:rw:boot -bios ovmf/OVMF.fd

.PHONY: clean
clean:
	rm -rf HELLO.EFI hello.elf $(OBJ) $(HEADER_DEPS)

.PHONY: distclean
distclean: clean
	rm -rf gnu-efi
