cmake_minimum_required(VERSION 3.30)

project(stremio VERSION "5.0.5")

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/CMakeModules/")

add_definitions(-DSTREMIO_SHELL_VERSION="${PROJECT_VERSION}"  -DUNICODE -D_UNICODE)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(QT_DEFAULT_MAJOR_VERSION 6)

list(APPEND WEBENGINE_CONFIG use_proprietary_codecs)
set(SOURCES
        src/main.cpp
        src/stremio.qrc
        src/stremio.rc
        src/player/mpv.cpp
        src/player/mpv.h
        src/mainapplication.h
        src/tray/systemtray.cpp
        src/tray/systemtray.h
        src/updater/autoupdater.cpp
        src/updater/autoupdater.h
        src/ssl/verifysig.c
        src/ssl/verifysig.h
        src/ssl/publickey.h
        src/saver/screensaver.cpp
        src/saver/screensaver.h
        src/server/stremioprocess.cpp
        src/server/stremioprocess.h
)

set(MPV_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/libmpv/i686/include)
if(WIN32)
    set(ENV{Qt6_DIR} $ENV{QTDIR})
    # Check if the system is 64-bit
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        # 64-bit system
        set(MPV_LIBRARY_mpv "${CMAKE_CURRENT_SOURCE_DIR}/deps/libmpv/x86_64/mpv.lib")
        set(MPV_DLL "${CMAKE_CURRENT_SOURCE_DIR}/deps/libmpv/x86_64/libmpv-2.dll")
    else()
        # 32-bit system
        set(MPV_LIBRARY_mpv "${CMAKE_CURRENT_SOURCE_DIR}/deps/libmpv/i686/mpv.lib")
        set(MPV_DLL "${CMAKE_CURRENT_SOURCE_DIR}/deps/libmpv/i686/libmpv-2.dll")
    endif()
endif()

if(APPLE)
    list(APPEND SOURCES images/stremio.icns)
    set_source_files_properties(images/stremio.icns PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    set(MPV_LIBRARY_mpv ${CMAKE_CURRENT_SOURCE_DIR}/deps/lib/libmpv.dylib)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-rpath,@executable_path/../Frameworks")
    add_definitions("-pipe")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++ -arch x86_64")
    set(ENV{OPENSSL_ROOT_DIR} $ENV{OPENSSL_BIN_PATH})
endif()

#Needed for SingleApplication
set(QAPPLICATION_CLASS QApplication)
add_subdirectory(deps/singleapplication)

# Find the required Qt6 components
find_package(Qt${QT_DEFAULT_MAJOR_VERSION} COMPONENTS QuickControls2 OpenGL Gui Widgets Network Qml Quick WebEngineQuick WebChannel DBus OpenGL REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(MPV REQUIRED)

if(APPLE)
    add_executable(${PROJECT_NAME} MACOSX_BUNDLE ${SOURCES})
    set_target_properties(${PROJECT_NAME} PROPERTIES
            BUNDLE True
            MACOSX_BUNDLE_ICON_FILE ${PROJECT_NAME}.icns
            MACOSX_BUNDLE_GUI_IDENTIFIER com.smartcodeltd.${PROJECT_NAME}
            MACOSX_BUNDLE_BUNDLE_EXECUTABLE_NAME ${PROJECT_NAME}
            MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
            MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
    )

    find_package(OpenGL)
    if(NOT OPENGL_FOUND)
        find_package(GLES2)
        if(NOT GLES2_FOUND)
            message(FATAL_ERROR "OpenGL or GLES2 is required")
        else(NOT GLES2_FOUND)
            set(OPENGL_LIBS ${GLES2_LIBRARY})
        endif(NOT GLES2_FOUND)
    else(NOT OPENGL_FOUND)
        set(OPENGL_LIBS ${OPENGL_gl_LIBRARY})
    endif(NOT OPENGL_FOUND)
    find_library(C_LIBRARY NAMES c REQUIRED)
    find_library(COREFOUNDATION_LIBRARY NAMES CoreFoundation REQUIRED)
    find_library(DISKARBITRATION_LIBRARY DiskArbitration REQUIRED)
    find_library(IOKIT_LIBRARY NAMES IOKit REQUIRED)
    find_library(AGL_LIBRARY NAMES AGL REQUIRED)
    target_link_libraries(${PROJECT_NAME} LINK_PUBLIC
            ${C_LIBRARY}
            ${COREFOUNDATION_LIBRARY}
            ${DISKARBITRATION_LIBRARY}
            ${IOKIT_LIBRARY}
            ${OPENGL_LIBS}
            ${AGL_LIBRARY}
    )
else()
    add_executable(${PROJECT_NAME} ${SOURCES})
endif()

if(WIN32 AND CMAKE_BUILD_TYPE STREQUAL "Release")
    set_property(TARGET ${PROJECT_NAME} PROPERTY WIN32_EXECUTABLE true)
endif()

target_include_directories(${PROJECT_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${MPV_INCLUDE_DIR}
)

# Link the Qt6 libraries
target_link_libraries(${PROJECT_NAME} PRIVATE
        Qt6::Qml
        Qt6::Quick
        Qt6::Gui
        Qt6::GuiPrivate
        Qt6::Network
        Qt6::Widgets
        Qt6::WebEngineQuick
        Qt6::WebChannel
        Qt6::QuickControls2
        Qt6::DBus
        Qt6::OpenGL
        SingleApplication::SingleApplication
        OpenSSL::Crypto
        ${MPV_LIBRARY_mpv}
)

if(UNIX AND NOT APPLE)
    install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION opt/stremio)
endif()

if(WIN32)
    # Copy MPV DLL
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${MPV_DLL}"
            $<TARGET_FILE_DIR:${PROJECT_NAME}>
    )
endif()