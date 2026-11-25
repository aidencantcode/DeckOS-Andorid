# rcheevos v12.5.0 (commit 1433173), hashing part only - see README.md in this folder.

add_library(rcheevos STATIC
    src/rc_compat.c
    src/rhash/aes.c
    src/rhash/cdreader.c
    src/rhash/hash.c
    src/rhash/hash_disc.c
    src/rhash/hash_encrypted.c
    src/rhash/hash_rom.c
    src/rhash/hash_zip.c
    src/rhash/md5.c
)
target_include_directories(rcheevos PUBLIC include)
target_compile_definitions(rcheevos PUBLIC RC_NO_THREADS)
set_target_properties(rcheevos PROPERTIES POSITION_INDEPENDENT_CODE ON)
