cmake_minimum_required(VERSION 3.10)

project(wayvibes)

set(CMAKE_CXX_STANDARD 11)

# Specify the source files
set(SOURCES
    src/main.cpp
    src/audio.cpp
    src/device.cpp
    src/config.cpp
)

# Include directories
include_directories(src)

# Add the executable
add_executable(wayvibes ${SOURCES})

# Link libraries (if any, e.g., for audio processing)
# target_link_libraries(wayvibes <library_name>)