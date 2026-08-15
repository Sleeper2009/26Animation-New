OS_PACKAGE_SCHEME = rootless

TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = custom26

custom26_FILES = Tweak.x
custom26_CFLAGS = -fobjc-arc
custom26_FRAMEWORKS = UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
