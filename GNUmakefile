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

override LDFLAGS += \
    -Tlimine-efi/gnuefi/elf_x86_64_efi.lds \
    -nostdlib \
    -z max-page-size=0x1000 \
    -m elf_x86_64 \
    -static \
    -pie \
    --no-dynamic-linker \
    -z text

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
    -mabi=sysv \
    -mno-80387 \
    -mno-mmx \
    -mno-sse \
    -mno-sse2 \
    -mno-red-zone

override CPPFLAGS := \
    -I. \
    -Ilimine-efi/inc \
    -Ilimine-efi/inc/x86_64 \
    $(CPPFLAGS) \
    -MMD \
    -MP

override CFILES := $(shell find -L ./src -type f -name '*.c')
override OBJ := $(CFILES:.c=.c.o)
override HEADER_DEPS := $(CFILES:.c=.c.d)

.PHONY: all
all: HELLO.EFI

limine-efi:
	git clone https://github.com/limine-bootloader/limine-efi.git --depth=1

limine-efi/gnuefi/crt0-efi-x86_64.S.o limine-efi/gnuefi/reloc_x86_64.c.o: limine-efi
	$(MAKE) -C limine-efi/gnuefi ARCH=x86_64

HELLO.EFI: hello.elf
	$(OBJCOPY) -O binary $< $@

hello.elf: limine-efi/gnuefi/crt0-efi-x86_64.S.o limine-efi/gnuefi/reloc_x86_64.c.o $(OBJ)
	$(LD) $^ $(LDFLAGS) -o $@

-include $(HEADER_DEPS)
%.c.o: %.c limine-efi
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

ovmf:
	mkdir -p ovmf
	cd ovmf && curl -Lo OVMF-X64.zip https://efi.akeo.ie/OVMF/OVMF-X64.zip && unzip OVMF-X64.zip

.PHONY: run
run: all ovmf
	mkdir -p boot/EFI/BOOT
	cp HELLO.EFI boot/EFI/BOOT/BOOTX64.EFI
	qemu-system-x86_64 -net none -M q35 -drive file=fat:rw:boot -bios ovmf/OVMF.fd
	rm -rf boot

.PHONY: clean
clean:
	if [ -d limine-efi/gnuefi ]; then $(MAKE) -C limine-efi/gnuefi ARCH=x86_64 clean; fi
	rm -rf HELLO.EFI hello.elf $(OBJ) $(HEADER_DEPS)

.PHONY: distclean
distclean: clean
	rm -rf limine-efi ovmf
