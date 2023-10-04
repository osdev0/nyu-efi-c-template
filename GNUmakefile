# Nuke built-in rules and variables.
override MAKEFLAGS += -rR

define DEFAULT_VAR =
    ifeq ($(origin $1),default)
        override $(1) := $(2)
    endif
    ifeq ($(origin $1),undefined)
        override $(1) := $(2)
    endif
endef

override DEFAULT_CC := cc
$(eval $(call DEFAULT_VAR,CC,$(DEFAULT_CC)))
override DEFAULT_LD := ld
$(eval $(call DEFAULT_VAR,LD,$(DEFAULT_LD)))
override DEFAULT_OBJCOPY := objcopy
$(eval $(call DEFAULT_VAR,OBJCOPY,$(DEFAULT_OBJCOPY)))

override DEFAULT_CFLAGS := -g -O2 -pipe
$(eval $(call DEFAULT_VAR,CFLAGS,$(DEFAULT_CFLAGS)))
override DEFAULT_CPPFLAGS :=
$(eval $(call DEFAULT_VAR,CPPFLAGS,$(DEFAULT_CPPFLAGS)))
override DEFAULT_LDFLAGS :=
$(eval $(call DEFAULT_VAR,LDFLAGS,$(DEFAULT_LDFLAGS)))

override CFLAGS += \
    -Wall \
    -Wextra \
    -std=gnu11 \
    -ffreestanding \
    -fno-stack-protector \
    -fno-stack-check \
    -fshort-wchar \
    -fno-lto \
    -fPIE \
    -m64 \
    -march=x86-64 \
    -mno-80387 \
    -mno-mmx \
    -mno-sse \
    -mno-sse2 \
    -mno-red-zone

override CPPFLAGS := \
    -I src \
    -I limine-efi/inc \
    -I limine-efi/inc/x86_64 \
    $(CPPFLAGS) \
    -MMD \
    -MP

override LDFLAGS += \
    -m elf_x86_64 \
    -nostdlib \
    -static \
    -pie \
    --no-dynamic-linker \
    -z text \
    -z max-page-size=0x1000 \
    -T limine-efi/gnuefi/elf_x86_64_efi.lds

override CFILES := $(shell cd src && find -L * -type f -name '*.c')
override OBJ := $(addprefix obj/,$(CFILES:.c=.c.o))
override HEADER_DEPS := $(addprefix obj/,$(CFILES:.c=.c.d))

.PHONY: all
all: bin/HELLO.EFI

limine-efi/gnuefi/crt0-efi-x86_64.S: limine-efi

limine-efi/gnuefi/crt0-efi-x86_64.S.o: limine-efi/gnuefi/crt0-efi-x86_64.S
	$(MAKE) -C limine-efi/gnuefi ARCH=x86_64 crt0-efi-x86_64.S.o

limine-efi/gnuefi/reloc_x86_64.c: limine-efi

limine-efi/gnuefi/reloc_x86_64.c.o: limine-efi/gnuefi/reloc_x86_64.c
	$(MAKE) -C limine-efi/gnuefi ARCH=x86_64 reloc_x86_64.c.o

limine-efi/gnuefi/elf_x86_64_efi.lds: limine-efi

limine-efi:
	git clone https://github.com/limine-bootloader/limine-efi.git --depth=1

bin/HELLO.EFI: bin/hello.elf GNUmakefile
	mkdir -p "$$(dirname $@)"
	$(OBJCOPY) -O binary $< $@

bin/hello.elf: GNUmakefile limine-efi/gnuefi/elf_x86_64_efi.lds limine-efi/gnuefi/crt0-efi-x86_64.S.o limine-efi/gnuefi/reloc_x86_64.c.o $(OBJ)
	mkdir -p "$$(dirname $@)"
	$(LD) limine-efi/gnuefi/crt0-efi-x86_64.S.o limine-efi/gnuefi/reloc_x86_64.c.o $(OBJ) $(LDFLAGS) -o $@

-include $(HEADER_DEPS)

obj/%.c.o: src/%.c GNUmakefile limine-efi
	mkdir -p "$$(dirname $@)"
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

ovmf:
	mkdir -p ovmf
	cd ovmf && curl -Lo OVMF.fd https://retrage.github.io/edk2-nightly/bin/RELEASEX64_OVMF.fd

.PHONY: run
run: all ovmf
	mkdir -p boot/EFI/BOOT
	cp bin/HELLO.EFI boot/EFI/BOOT/BOOTX64.EFI
	qemu-system-x86_64 -net none -M q35 -drive file=fat:rw:boot -bios ovmf/OVMF.fd
	rm -rf boot

.PHONY: clean
clean:
	if [ -d limine-efi/gnuefi ]; then $(MAKE) -C limine-efi/gnuefi ARCH=x86_64 clean; fi
	rm -rf bin obj

.PHONY: distclean
distclean: clean
	rm -rf limine-efi ovmf
