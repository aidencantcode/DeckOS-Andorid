# miniz 3.0.2 (zip reading, for hashing zipped ROMs) - see README.md in this folder.

add_library(miniz STATIC miniz.c)
# `#include "miniz/miniz.h"`, as with qmake
target_include_directories(miniz PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_compile_definitions(miniz PUBLIC MINIZ_NO_STDIO MINIZ_NO_TIME MINIZ_NO_ZLIB_COMPATIBLE_NAMES)
set_target_properties(miniz PROPERTIES POSITION_INDEPENDENT_CODE ON)
