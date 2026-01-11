cmake_minimum_required(VERSION 3.10)
project(adbd_arm64)

# 目标架构设置
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)
set(CMAKE_ANDROID_PLATFORM android-30)
set(CMAKE_ANDROID_STL c++_static)

# 编译选项
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror -Wno-unused-parameter -D_GNU_SOURCE -DADB_HOST=0")

# 源文件列表
set(LIBADB_SOURCES
    adb.cpp
    adb_io.cpp
    adb_listeners.cpp
    adb_mdns.cpp
    adb_trace.cpp
    adb_unique_fd.cpp
    adb_utils.cpp
    apacket_reader.cpp
    services.cpp
    sockets.cpp
    socket_spec.cpp
    transport.cpp
    transport_fd.cpp
    types.cpp
    sysdeps_unix.cpp
    sysdeps/posix/network.cpp
    sysdeps/errno.cpp
    sysdeps/env.cpp
    fdevent/fdevent.cpp
    fdevent/fdevent_epoll.cpp
)

set(ADBD_DAEMON_SOURCES
    daemon/adb_wifi.cpp
    daemon/auth.cpp
    daemon/jdwp_service.cpp
    daemon/logging.cpp
    daemon/transport_socket_server.cpp
    daemon/file_sync_service.cpp
    daemon/services.cpp
    daemon/shell_service.cpp
    daemon/restart_service.cpp
)

# 创建静态库
add_library(adbd_core STATIC
    ${LIBADB_SOURCES}
    ${ADBD_DAEMON_SOURCES}
)

target_include_directories(adbd_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/daemon
)

# 创建可执行文件
add_executable(adbd daemon/main.cpp)

# 链接库
target_link_libraries(adbd
    adbd_core
    crypto
    base
    cutils
    log
    cap
    minijail
    selinux
)

# 编译选项
target_compile_options(adbd PRIVATE
    -Wall -Werror -Wno-unused-parameter
    -D_GNU_SOURCE
    -DADB_HOST=0
)

# 静态链接
set_target_properties(adbd PROPERTIES
    LINK_FLAGS "-static-libstdc++"
)
