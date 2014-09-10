# make  to compile without debug info
# make DEBUG=1 to compile with debug info
all: HBL.BIN H.BIN

# use a different FOLDER to make for different exploits
# Exploit-specific files go in the subfolders, see targets hbl and loader below
FOLDER_PATH = exploits/$(FOLDER)

LD	= psp-ld
CC	= psp-gcc
AS	= psp-as

INCDIR	= -I $(shell psp-config --pspsdk-path)/include -I include -I $(FOLDER_PATH) -I .

CFLAGS	= $(INCDIR) -G1 -Os -Wall -Werror -mno-abicalls -fomit-frame-pointer -fno-pic -fno-strict-aliasing -fno-zero-initialized-in-bss
ifdef VITA
CFLAGS += -D VITA=$(VITA)
endif

ifdef NID_DEBUG
DEBUG = 1
CFLAGS += -D NID_DEBUG
endif
ifdef DEBUG
CFLAGS += -D DEBUG
endif

LDFLAGS = -O1 -G0 --no-keep-memory


OBJS_COMMON = sdk.o common/stubs/tables.o \
	common/utils/fnt.o common/utils/scr.o common/utils/string.o \
	common/memory.o common/utils.o
ifndef VITA
OBJS_COMMON += common/stubs/syscall.o
endif

ifdef DEBUG
OBJS_COMMON += common/debug.o
endif

OBJS_HBL = hbl/eloader.o \
	hbl/modmgr/elf.o hbl/modmgr/modmgr.o hbl/modmgr/reloc.o \
	hbl/stubs/hook.o hbl/stubs/md5.o hbl/stubs/resolve.o \
	hbl/utils/settings.o

OBJS_LOADER = loader/loader.o loader/bruteforce.o loader/freemem.o loader/runtime.o

%.BIN: %.elf
	psp-objcopy -S -O binary $< $@

HBL.elf: $(OBJS_COMMON) $(OBJS_HBL) $(FOLDER_PATH)/linker_hbl.x
	$(LD) $(LDFLAGS) -T $(FOLDER_PATH)/linker_hbl.x $(OBJS_COMMON) $(OBJS_HBL) -o $@

H.elf: $(OBJS_COMMON) $(OBJS_LOADER) $(FOLDER_PATH)/linker_loader.x
	$(LD) $(LDFLAGS) -T $(FOLDER_PATH)/linker_loader.x $(OBJS_COMMON) $(OBJS_LOADER) -o $@

sdk.o: $(FOLDER_PATH)/sdk.S
	$(AS) $< -o $@

loader/loader.o: loader/loader.c HBL.elf
	$(CC) $(CFLAGS) -D HBL_SIZE=$(lastword $(shell psp-size -A HBL.elf)) -c -o $@ $<

hbl/modmgr/modmgr.o: svnversion.h
loader/loader.o: svnversion.h

#svn version in code
svnversion.h:
	-@echo "//svnversion.h is automatically generated by the Makefile!!!" > svnversion.h
	-@echo "" >> svnversion.h
	-@echo "#ifndef SVNVERSION" >> svnversion.h
	-@echo "#define SVNVERSION \"$(shell svnversion -n)\"" >> svnversion.h
	-@echo "#endif" >> svnversion.h
	-SubWCRev . svnversion.txt svnversion.h

clean:
	rm -Rf $(OBJS_COMMON) common/stubs/syscall.o common/debug.o $(OBJS_HBL) $(OBJS_LOADER) svnversion.h HBL.elf H.elf HBL.BIN H.BIN
