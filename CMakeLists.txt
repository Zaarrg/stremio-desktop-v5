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

# ---------------------------------------------------------------------------
# libmpv — downloaded and unpacked at configure time (no binaries in git).
#
# To update mpv: bump MPV_VERSION to a build published at
#   https://sourceforge.net/projects/mpv-player-windows/files/libmpv/
# and refresh the matching SHA-256 hashes below. Nothing else needs to change;
# the DLL, headers and import library are regenerated on the next configure.
# ---------------------------------------------------------------------------
set(MPV_VERSION "20260607-git-71ebd08")

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(MPV_ARCH "x86_64")
    # v3 = x86-64-v3 (AVX2) optimized build; needs a Haswell-era or newer CPU.
    set(MPV_ARCHIVE_NAME "mpv-dev-x86_64-v3-${MPV_VERSION}.7z")
    set(MPV_ARCHIVE_SHA256 "6c48a01aa7783a6543c2edbcab10da3cd2efd54db2af5b590e38b488597a5841")
    set(MPV_MACHINE "x64")
else()
    set(MPV_ARCH "i686")
    set(MPV_ARCHIVE_NAME "mpv-dev-i686-${MPV_VERSION}.7z")
    set(MPV_ARCHIVE_SHA256 "1a39bbb0e194f5b5685844afb52084e73e0bcba6212c3e4eb9865b2065031e34")
    set(MPV_MACHINE "x86")
endif()

set(MPV_DIR "${CMAKE_BINARY_DIR}/libmpv/${MPV_ARCH}")
set(MPV_INCLUDE_DIR "${MPV_DIR}/include")
set(MPV_DLL "${MPV_DIR}/libmpv-2.dll")
set(MPV_LIBRARY "${MPV_DIR}/mpv.lib")
set(MPV_STAMP "${MPV_DIR}/.mpv-version")

# Re-fetch whenever the DLL is missing or the checked-out version changed.
set(MPV_NEED_FETCH TRUE)
if(EXISTS "${MPV_DLL}" AND EXISTS "${MPV_STAMP}")
    file(READ "${MPV_STAMP}" MPV_CACHED_VERSION)
    string(STRIP "${MPV_CACHED_VERSION}" MPV_CACHED_VERSION)
    if(MPV_CACHED_VERSION STREQUAL MPV_VERSION)
        set(MPV_NEED_FETCH FALSE)
    endif()
endif()

if(MPV_NEED_FETCH)
    set(MPV_ARCHIVE "${CMAKE_BINARY_DIR}/${MPV_ARCHIVE_NAME}")
    message(STATUS "Downloading libmpv ${MPV_VERSION} (${MPV_ARCH})...")
    file(DOWNLOAD
        "https://downloads.sourceforge.net/project/mpv-player-windows/libmpv/${MPV_ARCHIVE_NAME}"
        "${MPV_ARCHIVE}"
        SHOW_PROGRESS
        TLS_VERIFY ON
        EXPECTED_HASH "SHA256=${MPV_ARCHIVE_SHA256}"
        STATUS MPV_DL_STATUS
    )
    list(GET MPV_DL_STATUS 0 MPV_DL_CODE)
    if(NOT MPV_DL_CODE EQUAL 0)
        list(GET MPV_DL_STATUS 1 MPV_DL_MSG)
        message(FATAL_ERROR "Failed to download libmpv: ${MPV_DL_MSG}")
    endif()
    file(REMOVE_RECURSE "${MPV_DIR}")
    file(MAKE_DIRECTORY "${MPV_DIR}")
    file(ARCHIVE_EXTRACT INPUT "${MPV_ARCHIVE}" DESTINATION "${MPV_DIR}")
    file(WRITE "${MPV_STAMP}" "${MPV_VERSION}\n")
endif()

# libmpv ships a MinGW import library (libmpv.dll.a) that MSVC's linker cannot
# consume, so generate an MSVC .lib from the checked-in module-definition file.
if(NOT EXISTS "${MPV_LIBRARY}")
    get_filename_component(MPV_MSVC_BINDIR "${CMAKE_LINKER}" DIRECTORY)
    find_program(MPV_LIB_TOOL NAMES lib lib.exe HINTS "${MPV_MSVC_BINDIR}" REQUIRED)
    message(STATUS "Generating mpv.lib from libmpv.def...")
    execute_process(
        COMMAND "${MPV_LIB_TOOL}"
                "/def:${CMAKE_CURRENT_SOURCE_DIR}/deps/mpv/libmpv.def"
                "/machine:${MPV_MACHINE}"
                "/out:${MPV_LIBRARY}"
        RESULT_VARIABLE MPV_LIB_RESULT
        OUTPUT_VARIABLE MPV_LIB_OUTPUT
        ERROR_VARIABLE MPV_LIB_OUTPUT
    )
    if(NOT MPV_LIB_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to generate mpv.lib:\n${MPV_LIB_OUTPUT}")
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
add_subdirectory(deps/discord-rpc)
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