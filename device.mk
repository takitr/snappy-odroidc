include common.mk

DEVICE_VERSION := "0.5"
DEVICE_PREINSTALLED := http://cdimage.ubuntu.com/ubuntu-core/daily-preinstalled/current/wily-preinstalled-core-armhf.device.tar.gz

DEVICE_SRC := $(PWD)/device
DEVICE_UIMAGE := $(DEVICE_SRC)/assets/uImage
DEVICE_DTBS := $(DEVICE_SRC)/assets/dtbs
DEVICE_INITRD := $(DEVICE_SRC)/initrd
DEVICE_INITRD_IMG := $(DEVICE_SRC)/initrd.img
DEVICE_UINITRD := $(DEVICE_SRC)/assets/uInitrd
DEVICE_MODULES := $(DEVICE_SRC)/system
DEVICE_MODPROBE_D := $(DEVICE_SRC)/system/lib/modprobe.d
DEVICE_TAR := $(PWD)/device-odroidc_$(DEVICE_VERSION).tar.xz

all: build

clean:
	rm -f $(DEVICE_UIMAGE) $(DEVICE_UINITRD) $(DEVICE_INITRD_IMG)
	rm -rf $(DEVICE_DTBS)
	rm -rf $(DEVICE_MODULES)
	rm -rf $(DEVICE_INITRD)
	rm -rf $(DEVICE_SRC)/preinstalled
	rm -rf $(DEVICE_MODPROBE_D)

distclean:
	rm -rf $(DEVICE_SRC)/preinstalled.tar.gz

$(DEVICE_SRC):
	mkdir -p $(DEVICE_SRC)

$(DEVICE_UIMAGE):
	@if [ ! -f $(LINUX_UIMAGE) ] ; then echo "Build linux first."; exit 1; fi
	@mkdir -p $(DEVICE_SRC)/assets
	cp -f $(LINUX_UIMAGE) $(DEVICE_UIMAGE)

$(DEVICE_UINITRD): $(DEVICE_INITRD_IMG)
	@mkdir -p $(DEVICE_SRC)/assets
	@rm -f $(DEVICE_UINITRD)
	mkimage -A arm -T ramdisk -C none -n "Snappy Initrd" -d $(DEVICE_INITRD_IMG) $(DEVICE_UINITRD)

$(DEVICE_INITRD_IMG): $(DEVICE_SRC)/preinstalled/initrd.img
	@rm -f $(DEVICE_INITRD_IMG)
	@rm -rf $(DEVICE_INITRD)
	@mkdir -p $(DEVICE_INITRD)
	lzcat $(DEVICE_SRC)/preinstalled/initrd.img | ( cd $(DEVICE_INITRD); cpio -i )
	@rm -rf $(DEVICE_INITRD)/lib/modules
	@rm -rf $(DEVICE_INITRD)/lib/firmware
	( cd $(DEVICE_INITRD); find | sort | cpio --quiet -o -H newc ) | lzma > $(DEVICE_INITRD_IMG)

$(DEVICE_SRC)/preinstalled.tar.gz: | $(DEVICE_SRC)
	@wget $(DEVICE_PREINSTALLED) -O $@

$(DEVICE_SRC)/preinstalled/initrd.img: $(DEVICE_SRC)/preinstalled.tar.gz
	@mkdir -p $(DEVICE_SRC)/preinstalled
	tar xzvf $< -C $(DEVICE_SRC)/preinstalled --wildcards 'system/boot/initrd.img-*'
	cp $(DEVICE_SRC)/preinstalled/system/boot/initrd.img-* $@

dtbs:
	@if [ ! -f $(LINUX_DTB) ] ; then echo "Build linux first."; exit 1; fi
	@mkdir -p $(DEVICE_DTBS)
	cp $(LINUX_DTB) $(DEVICE_DTBS)

modules:
	@if [ ! -e $(LINUX_MODULES) ] ; then echo "Build linux first."; exit 1; fi
	@rm -rf $(DEVICE_MODULES)
	@mkdir -p $(DEVICE_MODULES)
	cp -a $(LINUX_MODULES)/* $(DEVICE_MODULES)

modprobe.d:
	@rm -rf $(DEVICE_MODPROBE_D)
	@mkdir -p $(DEVICE_MODPROBE_D)
	cp -a $(DEVICE_SRC)/modprobe.d/* $(DEVICE_MODPROBE_D)

device: $(DEVICE_UIMAGE) $(DEVICE_UINITRD) dtbs modules modprobe.d
	@rm -f $(DEVICE_TAR)
	tar -C $(DEVICE_SRC) -cavf $(DEVICE_TAR) --exclude ./preinstalled --exclude ./preinstalled.tar.gz --exclude ./initrd --exclude ./initrd.img --exclude ./modprobe.d --xform s:'./':: .

build: device

.PHONY: dtbs modules device build $(DEVICE_INITRD_IMG) $(DEVICE_UIMAGE)
