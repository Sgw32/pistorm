EXENAME          = emulator

MAINFILES        = emulator.c \
	memory_mapped.c \
	config_file/config_file.c \
	config_file/rominfo.c \
	input/input.c \
	gpio/ps_protocol.c \
	platforms/platforms.c \
	platforms/amiga/amiga-autoconf.c \
	platforms/amiga/amiga-platform.c \
	platforms/amiga/amiga-registers.c \
	platforms/amiga/amiga-interrupts.c \
	platforms/mac68k/mac68k-platform.c \
	platforms/dummy/dummy-platform.c \
	platforms/dummy/dummy-registers.c \
	platforms/amiga/Gayle.c \
	platforms/amiga/hunk-reloc.c \
	platforms/amiga/cdtv-dmac.c \
	platforms/amiga/rtg/rtg.c \
	platforms/amiga/rtg/rtg-output-raylib.c \
	platforms/amiga/rtg/rtg-gfx.c \
	platforms/amiga/piscsi/piscsi.c \
	platforms/amiga/ahi/pi_ahi.c \
	platforms/amiga/pistorm-dev/pistorm-dev.c \
	platforms/amiga/net/pi-net.c \
	platforms/shared/rtc.c \
	platforms/shared/common.c

MUSASHIFILES     = m68kcpu.c m68kdasm.c softfloat/softfloat.c softfloat/softfloat_fpsp.c
MUSASHIGENCFILES = m68kops.c
MUSASHIGENHFILES = m68kops.h
MUSASHIGENERATOR = m68kmake

# EXE = .exe
# EXEPATH = .\\
EXE =
EXEPATH = ./

.CFILES   = $(MAINFILES) $(MUSASHIFILES) $(MUSASHIGENCFILES)
.OFILES   = $(.CFILES:%.c=%.o) a314/a314.o

CROSS_COMPILE ?=

ifeq ($(origin CC),default)
DEFAULT_CC := yes
else ifeq ($(origin CC),undefined)
DEFAULT_CC := yes
else
DEFAULT_CC := no
endif

ifeq ($(origin CXX),default)
DEFAULT_CXX := yes
else ifeq ($(origin CXX),undefined)
DEFAULT_CXX := yes
else
DEFAULT_CXX := no
endif

ifeq ($(DEFAULT_CC),yes)
CC        := gcc
endif

ifeq ($(DEFAULT_CXX),yes)
CXX       := g++
endif

ifneq ($(strip $(CROSS_COMPILE)),)
ifeq ($(DEFAULT_CC),yes)
CC        := $(CROSS_COMPILE)gcc
endif
ifeq ($(DEFAULT_CXX),yes)
CXX       := $(CROSS_COMPILE)g++
endif
endif

HOSTCC    ?= gcc
WARNINGS  = -Wall -Wextra -pedantic

VC_PATH          ?= /opt/vc
VC_INCLUDE_PATH  ?= $(VC_PATH)/include
VC_LIB_PATH      ?= $(VC_PATH)/lib
RAYLIB_PATH      ?= ./raylib
RAYLIB_DRM_PATH  ?= ./raylib_drm
RAYLIB_PI4_PATH  ?= ./raylib_pi4_test
LOCAL_LIB_PATH   ?= /usr/local/lib

SYSROOT ?=
ifneq ($(strip $(SYSROOT)),)
SYSROOT_CFLAGS := --sysroot=$(SYSROOT)
SYSROOT_LFLAGS := --sysroot=$(SYSROOT)
endif

ARM_ARCH_FLAGS    ?= -march=armv8-a
ARM_FLOAT_FLAGS   ?= -mfloat-abi=hard -mfpu=neon-fp-armv8

CC_BASENAME := $(notdir $(firstword $(CC)))
ifneq ($(filter aarch64%,$(CC_BASENAME)),)
ARM_FLOAT_FLAGS :=
else ifneq ($(filter aarch64%,$(CROSS_COMPILE)),)
ARM_FLOAT_FLAGS :=
endif

COMMON_CFLAGS = $(WARNINGS) $(SYSROOT_CFLAGS) -I. -I$(RAYLIB_PATH) -I$(VC_INCLUDE_PATH) $(ARM_ARCH_FLAGS) $(ARM_FLOAT_FLAGS) -O3 -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -lstdc++ $(ACFLAGS)

ifeq ($(PLATFORM),PI3_BULLSEYE)
        LFLAGS    = $(WARNINGS) $(SYSROOT_LFLAGS) -L$(LOCAL_LIB_PATH) -L$(VC_LIB_PATH) -L$(RAYLIB_DRM_PATH) -lraylib -lGLESv2 -lEGL -lgbm -ldrm -ldl -lstdc++ -lvcos -lvchiq_arm -lvchostif -lasound
        CFLAGS    = $(COMMON_CFLAGS) -I$(RAYLIB_DRM_PATH)
else ifeq ($(PLATFORM),PI4)
        LFLAGS    = $(WARNINGS) $(SYSROOT_LFLAGS) -L$(LOCAL_LIB_PATH) -L$(VC_LIB_PATH) -L$(RAYLIB_PI4_PATH) -lraylib -lGLESv2 -lEGL -lgbm -ldrm -ldl -lstdc++ -lvcos -lvchiq_arm -lvchostif -lasound
        CFLAGS    = $(COMMON_CFLAGS) -DRPI4_TEST -I$(RAYLIB_PI4_PATH)
else
        CFLAGS    = $(COMMON_CFLAGS)
        LFLAGS    = $(WARNINGS) $(SYSROOT_LFLAGS) -L$(VC_LIB_PATH) -L$(RAYLIB_PATH) -lraylib -lbrcmGLESv2 -lbrcmEGL -lbcm_host -lstdc++ -lvcos -lvchiq_arm -lasound
endif

TARGET = $(EXENAME)$(EXE)

DELETEFILES = $(MUSASHIGENCFILES) $(MUSASHIGENHFILES) $(.OFILES) $(.OFILES:%.o=%.d) $(TARGET) $(MUSASHIGENERATOR)$(EXE)


all: $(MUSASHIGENCFILES) $(MUSASHIGENHFILES) $(TARGET) buptest

clean:
	rm -f $(DELETEFILES)

$(TARGET):  $(MUSASHIGENCFILES:%.c=%.o) $(.CFILES:%.c=%.o) a314/a314.o
	$(CC) -o $@ $^ -O3 -pthread $(LFLAGS) -lm -lstdc++

buptest: buptest.c gpio/ps_protocol.c
	$(CC) $^ -o $@ -I./ $(ARM_ARCH_FLAGS) $(ARM_FLOAT_FLAGS) -O0

a314/a314.o: a314/a314.cc a314/a314.h
	$(CXX) -MMD -MP -c -o a314/a314.o a314/a314.cc $(ARM_ARCH_FLAGS) $(ARM_FLOAT_FLAGS) -O3 -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -I. -I..

$(MUSASHIGENCFILES) $(MUSASHIGENHFILES): $(MUSASHIGENERATOR)$(EXE)
	$(EXEPATH)$(MUSASHIGENERATOR)$(EXE)

$(MUSASHIGENERATOR)$(EXE):  $(MUSASHIGENERATOR).c
	$(HOSTCC) -o  $(MUSASHIGENERATOR)$(EXE)  $(MUSASHIGENERATOR).c

-include $(.CFILES:%.c=%.d) $(MUSASHIGENCFILES:%.c=%.d) a314/a314.d $(MUSASHIGENERATOR).d
