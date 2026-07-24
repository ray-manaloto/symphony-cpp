set(CMAKE_C_COMPILER "/opt/clang-p2996/bin/clang" CACHE FILEPATH "")
set(CMAKE_CXX_COMPILER "/opt/clang-p2996/bin/clang++" CACHE FILEPATH "")
set(CMAKE_CXX_FLAGS_INIT "-stdlib=libc++")
set(_symphony_p2996_rpaths
    "-Wl,-rpath,/opt/clang-p2996/lib/x86_64-unknown-linux-gnu -Wl,-rpath,/opt/clang-p2996/lib/aarch64-unknown-linux-gnu -Wl,-rpath,/opt/clang-p2996/lib")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld ${_symphony_p2996_rpaths}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-fuse-ld=lld ${_symphony_p2996_rpaths}")
unset(_symphony_p2996_rpaths)
