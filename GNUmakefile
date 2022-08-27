define DEFAULT_VAR =
    ifeq ($(origin $1),default)
        override $(1) := $(2)
    endif
    ifeq ($(origin $1),undefined)
        override $(1) := $(2)
    endif
endef

$(eval $(call DEFAULT_VAR,CC,cc))
$(eval $(call DEFAULT_VAR,LD,ld))
$(eval $(call DEFAULT_VAR,OBJCOPY,objcopy))
$(eval $(call DEFAULT_VAR,AR,ar))

CFLAGS ?= -Wall -Wextra -O2 -g -pipe
LDFLAGS ?=

override INTERNALLDFLAGS :=                \
    -Tlimine-efi/gnuefi/elf_x86_64_efi.lds \
    -nostdlib                              \
    -zmax-page-size=0x1000                 \
    -melf_x86_64                           \
    -static                                \
    -pie                                   \
    --no-dynamic-linker                    \
    -ztext

override INTERNALCFLAGS :=  \
    -I.                     \
    -Ilimine-efi/inc        \
    -Ilimine-efi/inc/x86_64 \
    -DGNU_EFI_USE_MS_ABI    \
    -std=gnu11              \
    -ffreestanding          \
    -fshort-wchar           \
    -fno-stack-protector    \
    -fno-stack-check        \
    -fpie                   \
    -fno-lto                \
    -m64                    \
    -march=x86-64           \
    -mabi=sysv              \
    -mno-80387              \
    -mno-mmx                \
    -mno-sse                \
    -mno-sse2               \
    -mno-red-zone           \
    -MMD

override CFILES := $(shell find ./src -type f -name '*.c')
override OBJ := $(CFILES:.c=.o)
override HEADER_DEPS := $(CFILES:.c=.d)

.PHONY: all
all: HELLO.EFI

limine-efi:
	git clone https://github.com/limine-bootloader/limine-efi.git

limine-efi/gnuefi/crt0-efi-x86_64.o limine-efi/gnuefi/reloc_x86_64.o: limine-efi
	$(MAKE) -C limine-efi/gnuefi CC="$(CC)" ARCH=x86_64

HELLO.EFI: hello.elf
	$(OBJCOPY) -O binary $< $@

hello.elf: limine-efi/gnuefi/crt0-efi-x86_64.o limine-efi/gnuefi/reloc_x86_64.o $(OBJ)
	$(LD) $^ $(LDFLAGS) $(INTERNALLDFLAGS) -o $@

-include $(HEADER_DEPS)
%.o: %.c limine-efi
	$(CC) $(CFLAGS) $(INTERNALCFLAGS) -c $< -o $@

ovmf:
	mkdir -p ovmf
	cd ovmf && curl -o OVMF-X64.zip https://efi.akeo.ie/OVMF/OVMF-X64.zip && unzip OVMF-X64.zip

.PHONY: run
run: all ovmf
	mkdir -p boot/EFI/BOOT
	cp HELLO.EFI boot/EFI/BOOT/BOOTX64.EFI
	qemu-system-x86_64 -net none -M q35 -drive file=fat:rw:boot -bios ovmf/OVMF.fd
	rm -rf boot

.PHONY: clean
clean:
	rm -rf HELLO.EFI hello.elf $(OBJ) $(HEADER_DEPS)

.PHONY: distclean
distclean: clean
	rm -rf limine-efi ovmf
