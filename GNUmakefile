# Nuke built-in rules and variables.
override MAKEFLAGS += -rR

# This is the name that our final executable will have.
# Change as needed.
override OUTPUT := efi-template

# Convenience macro to reliably declare user overridable variables.
define DEFAULT_VAR =
    ifeq ($(origin $1),default)
        override $(1) := $(2)
    endif
    ifeq ($(origin $1),undefined)
        override $(1) := $(2)
    endif
endef

# Target architecture to build for. Default to x86_64.
override DEFAULT_KARCH := x86_64
$(eval $(call DEFAULT_VAR,KARCH,$(DEFAULT_KARCH)))

# Default user QEMU flags. These are appended to the QEMU command calls.
override DEFAULT_QEMUFLAGS := -m 2G
$(eval $(call DEFAULT_VAR,QEMUFLAGS,$(DEFAULT_QEMUFLAGS)))

# User controllable C compiler command.
override DEFAULT_KCC := clang
$(eval $(call DEFAULT_VAR,KCC,$(DEFAULT_KCC)))

# Check if KCC is Clang.
override KCC_IS_CLANG := no
ifeq ($(shell $(KCC) --version 2>&1 | grep -i 'clang' >/dev/null 2>&1 && echo 1),1)
    override KCC_IS_CLANG := yes
endif

# User controllable linker command.
override DEFAULT_KLD := ld.lld
$(eval $(call DEFAULT_VAR,KLD,$(DEFAULT_KLD)))

# User controllable objcopy command.
override DEFAULT_KOBJCOPY := llvm-objcopy
$(eval $(call DEFAULT_VAR,KOBJCOPY,$(DEFAULT_KOBJCOPY)))

# User controllable C flags.
override DEFAULT_KCFLAGS := -g -O2 -pipe
$(eval $(call DEFAULT_VAR,KCFLAGS,$(DEFAULT_KCFLAGS)))

# User controllable C preprocessor flags. We set none by default.
override DEFAULT_KCPPFLAGS :=
$(eval $(call DEFAULT_VAR,KCPPFLAGS,$(DEFAULT_KCPPFLAGS)))

ifeq ($(KARCH),x86_64)
    # User controllable nasm flags.
    override DEFAULT_KNASMFLAGS := -F dwarf -g
    $(eval $(call DEFAULT_VAR,KNASMFLAGS,$(DEFAULT_KNASMFLAGS)))
endif

# User controllable linker flags. We set none by default.
override DEFAULT_KLDFLAGS :=
$(eval $(call DEFAULT_VAR,KLDFLAGS,$(DEFAULT_KLDFLAGS)))

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
    -I limine-efi/inc \
    -I limine-efi/inc/$(KARCH) \
    $(KCPPFLAGS) \
    -isystem freestanding-headers \
    -MMD \
    -MP

ifeq ($(KARCH),x86_64)
    # Internal nasm flags that should not be changed by the user.
    override KNASMFLAGS += \
        -Wall
endif

# Architecture specific internal flags.
ifeq ($(KARCH),x86_64)
    ifeq ($(KCC_IS_CLANG),yes)
        override KCC += \
            -target x86_64-elf
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
else ifeq ($(KARCH),aarch64)
    ifeq ($(KCC_IS_CLANG),yes)
        override KCC += \
            -target aarch64-elf
    endif
    override KCFLAGS += \
        -mgeneral-regs-only
    override KLDFLAGS += \
        -m aarch64elf
else ifeq ($(KARCH),riscv64)
    ifeq ($(KCC_IS_CLANG),yes)
        override KCC += \
            -target riscv64-elf
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
else ifeq ($(KARCH),loongarch64)
    ifeq ($(KCC_IS_CLANG),yes)
        override KCC += \
            -target loongarch64-none
    endif
    override KCFLAGS += \
        -march=loongarch64 \
        -mabi=lp64s
    override KLDFLAGS += \
        -m elf64loongarch \
        --no-relax
else
    $(error Architecture $(KARCH) not supported)
endif

# Internal linker flags that should not be changed by the user.
override KLDFLAGS += \
    -nostdlib \
    -pie \
    -z text \
    -z max-page-size=0x1000 \
    -gc-sections \
    -T limine-efi/src/elf_$(KARCH)_efi.lds

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

# Ensure the dependencies have been obtained.
override MISSING_DEPS := $(shell if ! test -d freestanding-headers || ! test -f src/cc-runtime.c || ! test -d limine-efi; then echo 1; fi)
ifeq ($(MISSING_DEPS),1)
    $(error Please run the ./get-deps script first)
endif

# Default target.
.PHONY: all
all: bin-$(KARCH)/$(OUTPUT).efi

# Rules to build the limine-efi objects we need.
limine-efi/src/crt0-efi-$(KARCH).S.o: limine-efi

limine-efi/src/reloc_$(KARCH).c.o: limine-efi

.PHONY: limine-efi
limine-efi:
	$(MAKE) -C limine-efi/src -f limine-efi.mk \
		ARCH="$(KARCH)" \
		CC="$(KCC)" \
		CFLAGS="$(USER_KCFLAGS) -nostdinc" \
		CPPFLAGS="$(USER_KCPPFLAGS) -isystem ../../freestanding-headers"

# Rule to convert the final ELF executable to a .EFI PE executable.
bin-$(KARCH)/$(OUTPUT).efi: bin-$(KARCH)/$(OUTPUT) GNUmakefile
	mkdir -p "$$(dirname $@)"
	$(KOBJCOPY) -O binary $< $@
	dd if=/dev/zero of=$@ bs=4096 count=0 seek=$$(( ($$(wc -c < $@) + 4095) / 4096 )) 2>/dev/null

# Link rules for the final executable.
bin-$(KARCH)/$(OUTPUT): GNUmakefile limine-efi/src/elf_$(KARCH)_efi.lds limine-efi/src/crt0-efi-$(KARCH).S.o limine-efi/src/reloc_$(KARCH).c.o $(OBJ)
	mkdir -p "$$(dirname $@)"
	$(KLD) limine-efi/src/crt0-efi-$(KARCH).S.o limine-efi/src/reloc_$(KARCH).c.o $(OBJ) $(KLDFLAGS) -o $@

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
	curl -Lo $@ https://github.com/limine-bootloader/edk2-ovmf-nightly/releases/latest/download/ovmf-code-$(KARCH).fd
	if [ "$(KARCH)" = "aarch64" ]; then dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null; fi
	if [ "$(KARCH)" = "riscv64" ]; then dd if=/dev/zero of=$@ bs=1 count=0 seek=33554432 2>/dev/null; fi

ovmf/ovmf-vars-$(KARCH).fd:
	mkdir -p ovmf
	curl -Lo $@ https://github.com/limine-bootloader/edk2-ovmf-nightly/releases/latest/download/ovmf-vars-$(KARCH).fd
	if [ "$(KARCH)" = "aarch64" ]; then dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null; fi
	if [ "$(KARCH)" = "riscv64" ]; then dd if=/dev/zero of=$@ bs=1 count=0 seek=33554432 2>/dev/null; fi

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
else ifeq ($(KARCH),aarch64)
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
else ifeq ($(KARCH),riscv64)
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
		-device virtio-scsi-pci,id=scsi \
		-device scsi-hd,drive=hd0 \
		-drive id=hd0,file=fat:rw:boot \
		$(QEMUFLAGS)
else ifeq ($(KARCH),loongarch64)
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
	$(MAKE) -C limine-efi/src -f limine-efi.mk ARCH="$(KARCH)" clean
	rm -rf bin-$(KARCH) obj-$(KARCH)

# Remove everything built and generated including downloaded dependencies.
.PHONY: distclean
distclean:
	rm -rf bin-* obj-* freestanding-headers src/cc-runtime.c limine-efi ovmf
