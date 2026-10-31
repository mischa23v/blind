# REVIEW CANDIDATE ONLY. Not configured/built in Stage A.
cmake_minimum_required(VERSION 3.16)
project(voxfield_rayguard_baseline LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# C++14 accommodates Debian's modern GoogleTest; upstream mapper source unchanged.
set(CMAKE_CXX_EXTENSIONS OFF)
foreach(required ORIGINAL_ROOT ORIGINAL_BUILD VOXBLOX_ROOT MINKINDR_ROOT EIGENCHECKS_ROOT REUSE_PREFIX DEPS_PREFIX)
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
add_library(voxfield_rayguard SHARED ${NATIVE_SRCS} ${PROTO_SRCS})
target_include_directories(voxfield_rayguard PUBLIC
 "${VOXBLOX_ROOT}/voxblox/include" "${MINKINDR_ROOT}/minkindr/include"
 "${REUSE_PREFIX}/usr/include/eigen3" "${DEPS_PREFIX}/usr/include" "${PROTO_GEN}")
target_link_libraries(voxfield_rayguard PUBLIC "${PROTOBUF_LIBRARY}" "${GLOG_LIBRARY}" "${GFLAGS_LIBRARY}" Threads::Threads)
set(CMAKE_BUILD_RPATH "${DEPLIB}")
set_target_properties(voxfield_rayguard PROPERTIES POSITION_INDEPENDENT_CODE ON)

add_executable(candidate_client "${CMAKE_CURRENT_SOURCE_DIR}/client.cpp")
target_link_libraries(candidate_client PRIVATE voxfield_rayguard)
add_executable(original_client "${CMAKE_CURRENT_SOURCE_DIR}/client.cpp")
target_include_directories(original_client PRIVATE "${ORIGINAL_ROOT}/voxblox/include" "${MINKINDR_ROOT}/minkindr/include" "${REUSE_PREFIX}/usr/include/eigen3" "${DEPS_PREFIX}/usr/include" "${ORIGINAL_BUILD}/generated")
target_link_libraries(original_client PRIVATE "${ORIGINAL_BUILD}/libvoxfield_native.so" "${PROTOBUF_LIBRARY}" "${GLOG_LIBRARY}" "${GFLAGS_LIBRARY}" Threads::Threads)
