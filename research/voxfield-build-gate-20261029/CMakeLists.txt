# REVIEW CANDIDATE ONLY. Not configured/built in Stage A.
cmake_minimum_required(VERSION 3.16)
project(voxfield_native_baseline LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# C++14 accommodates Debian's modern GoogleTest; upstream mapper source unchanged.
set(CMAKE_CXX_EXTENSIONS OFF)
foreach(required VOXBLOX_ROOT MINKINDR_ROOT EIGENCHECKS_ROOT REUSE_PREFIX DEPS_PREFIX)
  if(NOT DEFINED ${required})
    message(FATAL_ERROR "Explicit ${required} required")
  endif()
endforeach()
find_package(Threads REQUIRED)
set(DEPLIB "${DEPS_PREFIX}/usr/lib/x86_64-linux-gnu")
find_library(PROTOBUF_LIBRARY protobuf PATHS "${DEPLIB}" NO_DEFAULT_PATH REQUIRED)
find_library(GLOG_LIBRARY glog PATHS "${DEPLIB}" NO_DEFAULT_PATH REQUIRED)
find_library(GFLAGS_LIBRARY gflags PATHS "${DEPLIB}" NO_DEFAULT_PATH REQUIRED)
find_library(GTEST_LIBRARY gtest PATHS "${DEPLIB}" NO_DEFAULT_PATH REQUIRED)
set(PROTOC "${DEPS_PREFIX}/usr/bin/protoc")
set(PROTO_GEN "${CMAKE_CURRENT_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${PROTO_GEN}")
set(PROTO_SRCS)
foreach(proto Block Layer)
  add_custom_command(OUTPUT "${PROTO_GEN}/voxblox/${proto}.pb.cc" "${PROTO_GEN}/voxblox/${proto}.pb.h"
    COMMAND "${PROTOC}" --proto_path=${VOXBLOX_ROOT}/voxblox/proto --cpp_out=${PROTO_GEN}
      "${VOXBLOX_ROOT}/voxblox/proto/voxblox/${proto}.proto"
    DEPENDS "${VOXBLOX_ROOT}/voxblox/proto/voxblox/${proto}.proto" VERBATIM)
  list(APPEND PROTO_SRCS "${PROTO_GEN}/voxblox/${proto}.pb.cc")
endforeach()
# Exact 26-file native source list from the pinned upstream core CMake.
set(NATIVE_SRCS
  src/alignment/icp.cc
  src/core/block.cc
  src/core/esdf_map.cc
  src/core/tsdf_map.cc
  src/integrator/esdf_integrator.cc
  src/integrator/esdf_occ_integrator.cc
  src/integrator/integrator_utils.cc
  src/integrator/intensity_integrator.cc
  src/integrator/tsdf_integrator.cc
  src/integrator/np_tsdf_integrator.cc
  src/integrator/esdf_voxfield_integrator.cc
  src/integrator/esdf_occ_fiesta_integrator.cc
  src/integrator/esdf_occ_edt_integrator.cc
  src/io/mesh_ply.cc
  src/io/sdf_ply.cc
  src/mesh/marching_cubes.cc
  src/simulation/objects.cc
  src/simulation/simulation_world.cc
  src/utils/camera_model.cc
  src/utils/evaluation_utils.cc
  src/utils/layer_utils.cc
  src/utils/neighbor_tools.cc
  src/utils/protobuf_utils.cc
  src/utils/timing.cc
  src/utils/voxel_utils.cc
  src/utils/neighbor_tools_ex.cc)
list(TRANSFORM NATIVE_SRCS PREPEND "${VOXBLOX_ROOT}/voxblox/")
add_library(voxfield_native SHARED ${NATIVE_SRCS} ${PROTO_SRCS})
target_include_directories(voxfield_native PUBLIC
 "${VOXBLOX_ROOT}/voxblox/include" "${MINKINDR_ROOT}/minkindr/include"
 "${REUSE_PREFIX}/usr/include/eigen3" "${DEPS_PREFIX}/usr/include" "${PROTO_GEN}")
target_link_libraries(voxfield_native PUBLIC "${PROTOBUF_LIBRARY}" "${GLOG_LIBRARY}" "${GFLAGS_LIBRARY}" Threads::Threads)
set(CMAKE_BUILD_RPATH "${DEPLIB}")
set_target_properties(voxfield_native PROPERTIES POSITION_INDEPENDENT_CODE ON)
enable_testing()
# Same 10 test targets listed by upstream; retain test mains and data.
foreach(t approx_hash_array tsdf_map protobuf tsdf_interpolator layer merge_integration layer_utils sdf_integrators bucket_queue clear_spheres)
 add_executable(test_${t} "${VOXBLOX_ROOT}/voxblox/test/test_${t}.cc")
 target_include_directories(test_${t} PRIVATE "${EIGENCHECKS_ROOT}/include")
 target_link_libraries(test_${t} PRIVATE voxfield_native "${GTEST_LIBRARY}")
 add_test(NAME upstream_${t} COMMAND test_${t})
 set_tests_properties(upstream_${t} PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}" TIMEOUT 120)
endforeach()
if(EXISTS "${VOXBLOX_ROOT}/voxblox/test/test_data")
 file(COPY "${VOXBLOX_ROOT}/voxblox/test/test_data" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}")
endif()
# Calibrated I/O runner belongs to a later reviewed adapter freeze; not added here.

add_executable(old13_fixtures "${CMAKE_CURRENT_SOURCE_DIR}/old13_fixtures.cpp")
target_link_libraries(old13_fixtures PRIVATE voxfield_native)

add_executable(np_fixtures "${CMAKE_CURRENT_SOURCE_DIR}/np_fixtures.cpp")
target_link_libraries(np_fixtures PRIVATE voxfield_native)

add_executable(n1_fixtures "${CMAKE_CURRENT_SOURCE_DIR}/n1_fixtures.cpp")
target_include_directories(n1_fixtures PRIVATE "${REUSE_PREFIX}/usr/include/eigen3")
target_compile_options(n1_fixtures PRIVATE -fsanitize=address,undefined -fno-omit-frame-pointer)
target_link_options(n1_fixtures PRIVATE -fsanitize=address,undefined)
