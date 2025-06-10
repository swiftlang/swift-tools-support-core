#if !defined(_WIN32)

#include <spawn.h>
#include <stdbool.h>

#ifdef TSC_API_UNAVAILABLE_DEFINED
#error TSC_API_UNAVAILABLE_DEFINED already defined
#endif

#ifndef __API_UNAVAILABLE
#define __API_UNAVAILABLE(...)
#define TSC_API_UNAVAILABLE_DEFINED
#endif

// Wrapper method for posix_spawn_file_actions_addchdir_np that fails on Linux versions that do not have this method available.
int SPM_posix_spawn_file_actions_addchdir_np(posix_spawn_file_actions_t *restrict file_actions, const char *restrict path) __API_UNAVAILABLE(ios, tvos, watchos, visionos);

// Runtime check for the availability of posix_spawn_file_actions_addchdir_np. Returns 0 if the method is available, -1 if not.
bool SPM_posix_spawn_file_actions_addchdir_np_supported();

#ifdef TSC_API_UNAVAILABLE_DEFINED
#undef TSC_API_UNAVAILABLE_DEFINED
#undef __API_UNAVAILABLE
#endif

#endif
