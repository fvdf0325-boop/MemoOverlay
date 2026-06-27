# THEOS_DEVICE_IP = 192.168.x.x  # SSH 직접 설치 시 주석 해제 후 IP 입력
# THEOS_DEVICE_PORT = 22

ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MemoOverlay
MemoOverlay_FILES = Tweak.x
MemoOverlay_FRAMEWORKS = UIKit Foundation

include $(THEOS)/makefiles/tweak.mk
