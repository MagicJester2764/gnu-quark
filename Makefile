# GNU/Quark — the Quark kernel, and GNU on top of it.
#
#   make          build everything and assemble gnu-quark.img
#   make run      boot it in QEMU
#   make test     boot it, type the acceptance script at it, check what it said
#   make check    e2fsck the root filesystem inside the image
#
# Quark builds a kernel, quarkutils the programs that make a kernel a system,
# and Bang a bootloader. GNU's programs are built here, from the tarballs
# packages/PACKAGES names, with the cross toolchain (x86_64-quark-musl-gcc on
# PATH). Nothing in any of them is reached into: each is asked to install,
# and this is where what they installed becomes a machine.

QUARK_DIR      ?= ../quark
QUARKUTILS_DIR ?= ../quarkutils
BANG_DIR       ?= ../bang

# The firmware lives in Bang because that is what needs it to exist.
OVMF_PATH ?= $(BANG_DIR)/firmware-redist/ovmf

# What an image is made of is said in packages/PACKAGES: every package
# marked `base`, and of those marked `optional` the ones EXTRA names.
#
#     make EXTRA="make"
#
# The line that makes the list is read where this file is, whatever
# directory make was started in.
EXTRA    ?=
LISTED    = $(shell awk 'substr($$0, 1, 1) != "\043" && $$2 == "$(1)" { print $$1 }' $(dir $(lastword $(MAKEFILE_LIST)))packages/PACKAGES)
BASE     := $(call LISTED,base)
OPTIONAL := $(call LISTED,optional)
UNKNOWN  := $(filter-out $(OPTIONAL),$(EXTRA))
ifneq ($(UNKNOWN),)
$(error no optional package called $(UNKNOWN): there is $(OPTIONAL))
endif
PACKAGES := $(BASE) $(EXTRA)

# Where this file is, and so where everything it makes goes — whatever
# directory make was started in. The two things below that are removed are
# named from here and from nowhere else.
HERE  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BUILD := $(HERE)/build
IMAGE := $(HERE)/gnu-quark.img

.PHONY: all stage packages root image run test check clean FORCE

all: image

# The kernel, then the userland, into one directory. That order is how the
# two meet: the userland checks its own copy of the system call numbers
# against the header the kernel has just installed, and REQUIRE_ABI makes a
# missing header an error rather than a check that was skipped.
stage: FORCE
	@mkdir -p $(BUILD)/stage
	$(MAKE) -C $(QUARK_DIR) install DESTDIR=$(BUILD)/stage
	$(MAKE) -C $(QUARKUTILS_DIR) install DESTDIR=$(BUILD)/stage REQUIRE_ABI=1
	$(MAKE) -C $(BANG_DIR) build
	@cp $(BANG_DIR)/BOOTX64.EFI $(BUILD)/stage/BOOTX64.EFI

# Each package: fetch and check its source, then run its recipe. A recipe
# configures once and builds what has changed, so this is cheap to run again.
packages: FORCE
	@for p in $(PACKAGES); do \
		src=`sh $(HERE)/tools/fetch.sh $$p $(BUILD)` || exit 1; \
		sh $(HERE)/packages/$$p/build.sh $$src $(BUILD)/obj/$$p $(BUILD)/pkg/$$p || exit 1; \
	done

# Made fresh every time: a root left over from another build is how a program
# that was removed stays in the image.
root: stage packages
	rm -rf $(BUILD)/root
	sh $(HERE)/tools/mkroot.sh $(BUILD)/stage $(BUILD)/root $(foreach p,$(PACKAGES),$(BUILD)/pkg/$(p))

image: root
	sh $(HERE)/tools/mkimage.sh $(BUILD)/stage $(BUILD)/root $(BUILD)/image $(IMAGE)

# -cpu max is deliberate: the default CPU models expose neither SMEP nor SMAP,
# so the kernel's supervisor-mode protections are silently off without it.
KVM := $(shell test -w /dev/kvm && echo -enable-kvm)
QEMU_FLAGS = $(KVM) -cpu max -m 1G -L $(OVMF_PATH)/ -pflash $(OVMF_PATH)/OVMF_CODE.fd

run: image
	qemu-system-x86_64 $(QEMU_FLAGS) -serial stdio -hda $(IMAGE)

test: image
	sh $(HERE)/tools/acceptance.sh $(IMAGE)

check:
	sh $(HERE)/tools/check-rootfs.sh $(IMAGE)

clean:
	rm -rf $(BUILD)
	rm -f $(IMAGE)

FORCE:
