# CMake generated Testfile for 
# Source directory: /mnt/sata/knowledge/notes/llama.cpp-rocm/examples/eval-callback
# Build directory: /mnt/sata/knowledge/notes/llama.cpp-rocm/build-hip/examples/eval-callback
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
add_test(test-eval-callback "/mnt/sata/knowledge/notes/llama.cpp-rocm/build-hip/bin/llama-eval-callback" "--hf-repo" "ggml-org/models" "--hf-file" "tinyllamas/stories260K.gguf" "--model" "stories260K.gguf" "--prompt" "hello" "--seed" "42" "-ngl" "0")
set_tests_properties(test-eval-callback PROPERTIES  LABELS "eval-callback;curl" _BACKTRACE_TRIPLES "/mnt/sata/knowledge/notes/llama.cpp-rocm/examples/eval-callback/CMakeLists.txt;9;add_test;/mnt/sata/knowledge/notes/llama.cpp-rocm/examples/eval-callback/CMakeLists.txt;0;")
