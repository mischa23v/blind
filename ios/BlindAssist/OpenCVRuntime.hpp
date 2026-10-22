#pragma once
#include <opencv2/core.hpp>
#include <mutex>

namespace ba_runtime {
inline void configureOpenCVOnce() {
    static std::once_flag once;
    std::call_once(once, [] { cv::setNumThreads(1); });
}
}
