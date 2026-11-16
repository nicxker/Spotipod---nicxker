TARGET := iphone:clang:latest:6.0
ARCHS := armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Nicxker

Nicxker_FILES = src/main.m \
                src/NXAppDelegate.m \
                src/NXSpotifyAuth.m \
                src/NXHTTPClient.m \
                src/NXSpotifyAPI.m \
                src/NXLoginViewController.m \
                src/NXMainTabController.m \
                src/NXPlayerViewController.m \
                src/NXSearchViewController.m \
                src/NXLibraryViewController.m

Nicxker_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
Nicxker_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/application.mk

