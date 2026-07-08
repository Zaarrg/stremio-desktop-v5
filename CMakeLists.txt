cmake_minimum_required(VERSION 3.16)

# -----------------------------------------------------------------------------
# Auto-detect Vcpkg
# -----------------------------------------------------------------------------
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    if(DEFINED ENV{VCPKG_ROOT})
        set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
    else()
        # Try common locations
        set(_VCPKG_PATHS
            "C:/vcpkg"
            "C:/Users/$ENV{USERNAME}/vcpkg"
            "C:/Users/$ENV{USERNAME}/scoop/apps/vcpkg/current"
            "${CMAKE_CURRENT_SOURCE_DIR}/deps/vcpkg"
        )
        foreach(_PATH ${_VCPKG_PATHS})
            if(EXISTS "${_PATH}/scripts/buildsystems/vcpkg.cmake")
                message(STATUS "Found Vcpkg at: ${_PATH}")
                set(CMAKE_TOOLCHAIN_FILE "${_PATH}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
                break()
            endif()
        endforeach()
        
        if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
            message(WARNING "Vcpkg not found in standard locations. Please set VCPKG_ROOT environment variable or pass -DCMAKE_TOOLCHAIN_FILE.")
        endif()
    endif()
endif()

if(DEFINED CMAKE_TOOLCHAIN_FILE)
    message(STATUS "Using toolchain: ${CMAKE_TOOLCHAIN_FILE}")
    set(VCPKG_TARGET_TRIPLET "x64-windows-static" CACHE STRING "")
    set(VCPKG_MANIFEST_MODE ON CACHE BOOL "")
    set(VCPKG_MANIFEST_INSTALL ON CACHE BOOL "")

    # Resolve VCPKG_ROOT from toolchain file path
    get_filename_component(_VCPKG_SCRIPTS_DIR "${CMAKE_TOOLCHAIN_FILE}" DIRECTORY) # .../scripts/buildsystems
    get_filename_component(_VCPKG_SCRIPTS_ROOT "${_VCPKG_SCRIPTS_DIR}" DIRECTORY)  # .../scripts
    get_filename_component(VCPKG_ROOT_DETECTED "${_VCPKG_SCRIPTS_ROOT}" DIRECTORY)  # .../vcpkg (root)

    # Preseed NASM if not present (fix for unstable nasm.us)
    # Extract the exact version vcpkg wants from its own scripts
    set(NASM_ACQUIRE_SCRIPT "${VCPKG_ROOT_DETECTED}/scripts/cmake/vcpkg_find_acquire_program(NASM).cmake")
    
    if(EXISTS "${NASM_ACQUIRE_SCRIPT}")
        file(READ "${NASM_ACQUIRE_SCRIPT}" SCRIPT_CONTENTS)
        string(REGEX MATCH "set\\(program_version ([0-9.]+)\\)" _ "${SCRIPT_CONTENTS}")
        set(NASM_VERSION ${CMAKE_MATCH_1})
        
        if(NASM_VERSION)
            set(NASM_ZIP "nasm-${NASM_VERSION}-win64.zip")
            set(VCPKG_DOWNLOADS "${VCPKG_ROOT_DETECTED}/downloads")

            # 1. Ensure the downloads directory exists
            if(NOT EXISTS "${VCPKG_DOWNLOADS}")
                file(MAKE_DIRECTORY "${VCPKG_DOWNLOADS}")
            endif()

            # 2. Pre-seed the ZIP
            if(NOT EXISTS "${VCPKG_DOWNLOADS}/${NASM_ZIP}")
                message(STATUS "vcpkg needs NASM ${NASM_VERSION}. Pre-seeding from mirror...")
                file(DOWNLOAD 
                    "https://gstreamer.freedesktop.org/data/src/mirror/${NASM_ZIP}"
                    "${VCPKG_DOWNLOADS}/${NASM_ZIP}"
                    SHOW_PROGRESS
                    TLS_VERIFY ON
                )
            endif()
        endif()
    endif()
endif()

message(STATUS "DEBUG: CMake running...")

project(stremio VERSION "5.0.21")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

option(DEBUG_LOG "Allow debug logs" ON)

# Locate MPV and Discord
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(MPV_ARCH "x86_64")
else()
    set(MPV_ARCH "i686")
endif()

set(MPV_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/libmpv/${MPV_ARCH}")
set(MPV_INCLUDE_DIR "${MPV_DIR}/include")
set(MPV_LIBRARY "${MPV_DIR}/mpv.lib")
set(MPV_DLL "${MPV_DIR}/libmpv-2.dll")
set(MPV_RAR "${MPV_DIR}/libmpv-2.dll.rar")

# Auto-extract libmpv if needed
if(EXISTS "${MPV_RAR}" AND NOT EXISTS "${MPV_DLL}")
    message(STATUS "Extracting libmpv DLL from ${MPV_RAR}...")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E tar x "${MPV_RAR}"
        WORKING_DIRECTORY "${MPV_DIR}"
        RESULT_VARIABLE TAR_RESULT
    )
    if(NOT TAR_RESULT EQUAL 0)
        message(WARNING "Failed to extract libmpv dll. Please unzip manually.")
    else()
        message(STATUS "Successfully extracted libmpv.")
    endif()
endif()

# Automate discord-rpc patching
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/deps/discord-rpc/include/discord_rpc.h" RPC_HEADER_CONTENT)
if(NOT RPC_HEADER_CONTENT MATCHES "statusDisplayType")
    message(STATUS "Patching discord-rpc...")
    find_package(Git REQUIRED)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} apply --directory=deps/discord-rpc "${CMAKE_CURRENT_SOURCE_DIR}/deps/discord-rpc.patch"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE PATCH_RESULT
    )
    if(NOT PATCH_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to apply discord-rpc.patch. Please apply manually or check git state.")
    endif()
endif()

option(BUILD_EXAMPLES "Build example apps" OFF)
# discord-rpc ships cmake_minimum_required(VERSION 3.2.0), which CMake 4.0+
# rejects ("Compatibility with CMake < 3.5 has been removed"). Allow the
# vendored subdirectory to configure under modern CMake.
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
add_subdirectory(deps/discord-rpc)
unset(CMAKE_POLICY_VERSION_MINIMUM)
set(DISCORD_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/discord-rpc/include")

include_directories(${DISCORD_INCLUDE_DIR})
include_directories(${MPV_INCLUDE_DIR})

find_package(OpenSSL REQUIRED)
find_package(CURL REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(unofficial-webview2 CONFIG REQUIRED)

set(SOURCES
        src/main.cpp
        stremio.rc
        src/core/globals.h
        src/core/globals.cpp
        src/utils/helpers.h
        src/utils/helpers.cpp
        src/utils/config.h
        src/utils/config.cpp
        src/utils/crashlog.h
        src/utils/crashlog.cpp
        src/mpv/player.h
        src/mpv/player.cpp
        src/node/server.cpp
        src/node/server.h
        src/tray/tray.h
        src/tray/tray.cpp
        src/ui/splash.h
        src/ui/splash.cpp
        src/updater/updater.cpp
        src/updater/updater.h
        src/webview/webview.h
        src/webview/webview.cpp
        src/ui/mainwindow.h
        src/ui/mainwindow.cpp
        src/resource.h
        src/utils/extensions.cpp
        src/utils/extensions.h
        src/utils/discord.cpp
        src/utils/discord.h
)

add_executable(${PROJECT_NAME} WIN32 ${SOURCES})


target_link_libraries(${PROJECT_NAME} PRIVATE
        gdiplus.lib
        dwmapi.lib
        Shcore.lib
        Msimg32.lib
        winhttp.lib
        shlwapi.lib
        nlohmann_json::nlohmann_json
        unofficial::webview2::webview2
        OpenSSL::SSL
        OpenSSL::Crypto
        CURL::libcurl
        ${MPV_LIBRARY}
        discord-rpc
)

target_compile_definitions(${PROJECT_NAME} PRIVATE DEBUG_LOG)

# Copy MPV DLL
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${MPV_DLL}"
        $<TARGET_FILE_DIR:${PROJECT_NAME}>
)