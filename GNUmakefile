# Nuke built-in rules and variables.
MAKEFLAGS += -rR
.SUFFIXES:

# This is the name that our final executable will have.
# Change as needed.
override OUTPUT := efi-template

# Convenience macro to reliably declare user overridable variables.
override USER_VARIABLE = $(if $(filter $(origin $(1)),default undefined),$(eval override $(1) := $(2)))

# Target architecture to build for. Default to x86_64.
$(call USER_VARIABLE,KARCH,x86_64)

# Check if the architecture is supported.
ifeq ($(filter $(KARCH),aarch64 loongarch64 riscv64 x86_64),)
    $(error Architecture $(KARCH) not supported)
endif

# Default user QEMU flags. These are appended to the QEMU command calls.
$(call USER_VARIABLE,QEMUFLAGS,-m 2G)

# User controllable C compiler command.
$(call USER_VARIABLE,KCC,cc)

# User controllable linker command.
$(call USER_VARIABLE,KLD,ld)

# User controllable objcopy command.
$(call USER_VARIABLE,KOBJCOPY,objcopy)

# User controllable C flags.
$(call USER_VARIABLE,KCFLAGS,-g -O2 -pipe)

# User controllable C preprocessor flags. We set none by default.
$(call USER_VARIABLE,KCPPFLAGS,)

ifeq ($(KARCH),x86_64)
    # User controllable nasm flags.
    $(call USER_VARIABLE,KNASMFLAGS,-F dwarf -g)
endif

# User controllable linker flags. We set none by default.
$(call USER_VARIABLE,KLDFLAGS,)

# Ensure the dependencies have been obtained.
ifeq ($(shell ( ! test -d freestnd-c-hdrs-0bsd || ! test -f src/cc-runtime.c || ! test -d nyu-efi ); echo $$?),0)
    $(error Please run the ./get-deps script first)
endif

# Check if KCC is Clang.
override KCC_IS_CLANG := $(shell ! $(KCC) --version | grep 'clang' >/dev/null 2>&1; echo $$?)

# Save user KCFLAGS and KCPPFLAGS before we append internal flags.
override USER_KCFLAGS := $(KCFLAGS)
override USER_KCPPFLAGS := $(KCPPFLAGS)

# Internal C flags that should not be changed by the user.
override KCFLAGS += \
    -Wall \
    -Wextra \
    -std=gnu11 \
    -nostdinc \
    -ffreestanding \
    -fno-stack-protector \
    -fno-stack-check \
    -fshort-wchar \
    -fno-lto \
    -fPIE \
    -ffunction-sections \
    -fdata-sections

# Internal C preprocessor flags that should not be changed by the user.
override KCPPFLAGS := \
    -I src \
    -I nyu-efi/inc \
    -isystem freestnd-c-hdrs-0bsd \
    $(KCPPFLAGS) \
    -MMD \
    -MP

ifeq ($(KARCH),x86_64)
    # Internal nasm flags that should not be changed by the user.
    override KNASMFLAGS += \
        -Wall
endif

# Architecture specific internal flags.
ifeq ($(KARCH),x86_64)
    ifeq ($(KCC_IS_CLANG),1)
        override KCC += \
            -target x86_64-unknown-none
    endif
    override KCFLAGS += \
        -m64 \
        -march=x86-64 \
        -mno-80387 \
        -mno-mmx \
        -mno-sse \
        -mno-sse2 \
        -mno-red-zone
    override KLDFLAGS += \
        -m elf_x86_64
    override KNASMFLAGS += \
        -f elf64
endif
ifeq ($(KARCH),aarch64)
    ifeq ($(KCC_IS_CLANG),1)
        override KCC += \
            -target aarch64-unknown-none
    endif
    override KCFLAGS += \
        -mgeneral-regs-only
    override KLDFLAGS += \
        -m aarch64elf
endif
ifeq ($(KARCH),riscv64)
    ifeq ($(KCC_IS_CLANG),1)
        override KCC += \
            -target riscv64-unknown-none
        override KCFLAGS += \
            -march=rv64imac
    else
        override KCFLAGS += \
            -march=rv64imac_zicsr_zifencei
    endif
    override KCFLAGS += \
        -mabi=lp64 \
        -mno-relax
    override KLDFLAGS += \
        -m elf64lriscv \
        --no-relax
endif
ifeq ($(KARCH),loongarch64)
    ifeq ($(KCC_IS_CLANG),1)
        override KCC += \
            -target loongarch64-unknown-none
    endif
    override KCFLAGS += \
        -march=loongarch64 \
        -mabi=lp64s
    override KLDFLAGS += \
        -m elf64loongarch \
        --no-relax
endif

# Internal linker flags that should not be changed by the user.
override KLDFLAGS += \
    -nostdlib \
    -pie \
    -z text \
    -z max-page-size=0x1000 \
    -gc-sections \
    -T nyu-efi/src/elf_$(KARCH)_efi.lds

# Use "find" to glob all *.c, *.S, and *.asm files in the tree and obtain the
# object and header dependency file names.
override CFILES := $(shell cd src && find -L * -type f -name '*.c')
override ASFILES := $(shell cd src && find -L * -type f -name '*.S')
ifeq ($(KARCH),x86_64)
override NASMFILES := $(shell cd src && find -L * -type f -name '*.asm')
endif
override OBJ := $(addprefix obj-$(KARCH)/,$(CFILES:.c=.c.o) $(ASFILES:.S=.S.o))
ifeq ($(KARCH),x86_64)
override OBJ += $(addprefix obj-$(KARCH)/,$(NASMFILES:.asm=.asm.o))
endif
override HEADER_DEPS := $(addprefix obj-$(KARCH)/,$(CFILES:.c=.c.d) $(ASFILES:.S=.S.d))

# Default target.
.PHONY: all
all: bin-$(KARCH)/$(OUTPUT).efi

# Rules to build the nyu-efi objects we need.
nyu-efi/src/crt0-efi-$(KARCH).S.o: nyu-efi

nyu-efi/src/reloc_$(KARCH).c.o: nyu-efi

.PHONY: nyu-efi
nyu-efi:
	$(MAKE) -C nyu-efi/src -f nyu-efi.mk \
		ARCH="$(KARCH)" \
		CC="$(KCC)" \
		CFLAGS="$(USER_KCFLAGS) -nostdinc" \
		CPPFLAGS="$(USER_KCPPFLAGS) -isystem ../../freestnd-c-hdrs-0bsd"

# Rule to convert the final ELF executable to a .EFI PE executable.
bin-$(KARCH)/$(OUTPUT).efi: bin-$(KARCH)/$(OUTPUT) GNUmakefile
	mkdir -p "$$(dirname $@)"
	$(KOBJCOPY) -O binary $< $@
	dd if=/dev/zero of=$@ bs=4096 count=0 seek=$$(( ($$(wc -c < $@) + 4095) / 4096 )) 2>/dev/null

# Link rules for the final executable.
bin-$(KARCH)/$(OUTPUT): GNUmakefile nyu-efi/src/elf_$(KARCH)_efi.lds nyu-efi/src/crt0-efi-$(KARCH).S.o nyu-efi/src/reloc_$(KARCH).c.o $(OBJ)
	mkdir -p "$$(dirname $@)"
	$(KLD) nyu-efi/src/crt0-efi-$(KARCH).S.o nyu-efi/src/reloc_$(KARCH).c.o $(OBJ) $(KLDFLAGS) -o $@

# Include header dependencies.
-include $(HEADER_DEPS)

# Compilation rules for *.c files.
obj-$(KARCH)/%.c.o: src/%.c GNUmakefile
	mkdir -p "$$(dirname $@)"
	$(KCC) $(KCFLAGS) $(KCPPFLAGS) -c $< -o $@

# Compilation rules for *.S files.
obj-$(KARCH)/%.S.o: src/%.S GNUmakefile
	mkdir -p "$$(dirname $@)"
	$(KCC) $(KCFLAGS) $(KCPPFLAGS) -c $< -o $@

ifeq ($(KARCH),x86_64)
# Compilation rules for *.asm (nasm) files.
obj-$(KARCH)/%.asm.o: src/%.asm GNUmakefile
	mkdir -p "$$(dirname $@)"
	nasm $(KNASMFLAGS) $< -o $@
endif

# Rules to download the UEFI firmware per architecture for testing.
ovmf/ovmf-code-$(KARCH).fd:
	mkdir -p ovmf
	curl -Lo $@ https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/ovmf-code-$(KARCH).fd
	case "$(KARCH)" in \
		aarch64) dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null;; \
		riscv64) dd if=/dev/zero of=$@ bs=1 count=0 seek=33554432 2>/dev/null;; \
	esac

ovmf/ovmf-vars-$(KARCH).fd:
	mkdir -p ovmf
	curl -Lo $@ https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/ovmf-vars-$(KARCH).fd
	case "$(KARCH)" in \
		aarch64) dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null;; \
		riscv64) dd if=/dev/zero of=$@ bs=1 count=0 seek=33554432 2>/dev/null;; \
	esac

# Rules for running our executable in QEMU.
.PHONY: run
run: all ovmf/ovmf-code-$(KARCH).fd ovmf/ovmf-vars-$(KARCH).fd
	mkdir -p boot/EFI/BOOT
ifeq ($(KARCH),x86_64)
	cp bin-$(KARCH)/$(OUTPUT).efi boot/EFI/BOOT/BOOTX64.EFI
	qemu-system-$(KARCH) \
		-M q35 \
		-drive if=pflash,unit=0,format=raw,file=ovmf/ovmf-code-$(KARCH).fd,readonly=on \
		-drive if=pflash,unit=1,format=raw,file=ovmf/ovmf-vars-$(KARCH).fd \
		-drive file=fat:rw:boot \
		$(QEMUFLAGS)
endif
ifeq ($(KARCH),aarch64)
	cp bin-$(KARCH)/$(OUTPUT).efi boot/EFI/BOOT/BOOTAA64.EFI
	qemu-system-$(KARCH) \
		-M virt \
		-cpu cortex-a72 \
		-device ramfb \
		-device qemu-xhci \
		-device usb-kbd \
		-device usb-mouse \
		-drive if=pflash,unit=0,format=raw,file=ovmf/ovmf-code-$(KARCH).fd,readonly=on \
		-drive if=pflash,unit=1,format=raw,file=ovmf/ovmf-vars-$(KARCH).fd \
		-drive file=fat:rw:boot \
		$(QEMUFLAGS)
endif
ifeq ($(KARCH),riscv64)
	cp bin-$(KARCH)/$(OUTPUT).efi boot/EFI/BOOT/BOOTRISCV64.EFI
	qemu-system-$(KARCH) \
		-M virt \
		-cpu rv64 \
		-device ramfb \
		-device qemu-xhci \
		-device usb-kbd \
		-device usb-mouse \
		-drive if=pflash,unit=0,format=raw,file=ovmf/ovmf-code-$(KARCH).fd,readonly=on \
		-drive if=pflash,unit=1,format=raw,file=ovmf/ovmf-vars-$(KARCH).fd \
		-drive file=fat:rw:boot \
		$(QEMUFLAGS)
endif
ifeq ($(KARCH),loongarch64)
	cp bin-$(KARCH)/$(OUTPUT).efi boot/EFI/BOOT/BOOTLOONGARCH64.EFI
	qemu-system-$(KARCH) \
		-M virt \
		-cpu la464 \
		-device ramfb \
		-device qemu-xhci \
		-device usb-kbd \
		-device usb-mouse \
		-drive if=pflash,unit=0,format=raw,file=ovmf/ovmf-code-$(KARCH).fd,readonly=on \
		-drive if=pflash,unit=1,format=raw,file=ovmf/ovmf-vars-$(KARCH).fd \
		-drive file=fat:rw:boot \
		$(QEMUFLAGS)
endif
	rm -rf boot

# Remove object files and the final executable.
.PHONY: clean
clean:
	$(MAKE) -C nyu-efi/src -f nyu-efi.mk ARCH="$(KARCH)" clean
	rm -rf bin-$(KARCH) obj-$(KARCH)

# Remove everything built and generated including downloaded dependencies.
.PHONY: distclean
distclean:
	rm -rf bin-* obj-* freestnd-c-hdrs-0bsd src/cc-runtime.c nyu-efi ovmf
