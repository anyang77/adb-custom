LOCAL_PATH := $(call my-dir)

# 主要的 adbd 库
include $(CLEAR_VARS)

LOCAL_MODULE := adbd_core
LOCAL_MODULE_TAGS := optional

LOCAL_SRC_FILES := \
    adb.cpp \
    adb_io.cpp \
    adb_listeners.cpp \
    adb_mdns.cpp \
    adb_trace.cpp \
    adb_unique_fd.cpp \
    adb_utils.cpp \
    apacket_reader.cpp \
    services.cpp \
    sockets.cpp \
    socket_spec.cpp \
    transport.cpp \
    transport_fd.cpp \
    types.cpp \
    daemon/adb_wifi.cpp \
    daemon/auth.cpp \
    daemon/jdwp_service.cpp \
    daemon/logging.cpp \
    daemon/transport_socket_server.cpp \
    daemon/file_sync_service.cpp \
    daemon/services.cpp \
    daemon/shell_service.cpp \
    daemon/restart_service.cpp \
    sysdeps_unix.cpp \
    sysdeps/posix/network.cpp \
    fdevent/fdevent.cpp \
    fdevent/fdevent_epoll.cpp

LOCAL_C_INCLUDES := \
    $(LOCAL_PATH) \
    $(LOCAL_PATH)/daemon

LOCAL_CFLAGS := \
    -Wall -Werror -Wno-unused-parameter \
    -DADB_HOST=0 \
    -D_GNU_SOURCE \
    -std=c++17

LOCAL_CPPFLAGS := \
    -std=c++17

LOCAL_STATIC_LIBRARIES := \
    libc++_static

LOCAL_SHARED_LIBRARIES := \
    libc \
    libdl \
    libm

include $(BUILD_STATIC_LIBRARY)

# adbd 可执行文件
include $(CLEAR_VARS)

LOCAL_MODULE := adbd
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := EXECUTABLES

LOCAL_SRC_FILES := daemon/main.cpp

LOCAL_C_INCLUDES := $(LOCAL_PATH)

LOCAL_CFLAGS := \
    -Wall -Werror -Wno-unused-parameter \
    -DADB_HOST=0 \
    -D_GNU_SOURCE \
    -std=c++17

LOCAL_CPPFLAGS := -std=c++17

LOCAL_STATIC_LIBRARIES := \
    adbd_core \
    libc++_static

LOCAL_SHARED_LIBRARIES := \
    libc \
    libdl \
    libm

LOCAL_LDFLAGS := -static-libstdc++

include $(BUILD_EXECUTABLE)
