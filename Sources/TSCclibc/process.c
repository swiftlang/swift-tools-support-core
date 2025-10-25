#if !defined(_WIN32)

#if defined(__linux__)
#ifndef _GNU_SOURCE
#define _GNU_SOURCE /* for posix_spawn_file_actions_addchdir_np */
#endif
#endif

#ifndef __GLIBC_PREREQ
#define __GLIBC_PREREQ(maj, min) 0
#endif

#include <errno.h>

#include "process.h"

int SPM_posix_spawn_file_actions_addchdir_np(posix_spawn_file_actions_t *restrict file_actions, const char *restrict path) {
#if defined(__GLIBC__) && !__GLIBC_PREREQ(2, 29)
    // Glibc versions prior to 2.29 don't support posix_spawn_file_actions_addchdir_np, impacting:
    //  - Amazon Linux 2 (EoL mid-2025)
    return ENOSYS;
#elif defined(__ANDROID__) && __ANDROID_API__ < 34
    // Android versions prior to 14 (API level 34) don't support posix_spawn_file_actions_addchdir_np
    return ENOSYS;
#elif defined(__OpenBSD__) || defined(__QNX__)
    // Currently missing as of:
    //  - OpenBSD 7.5 (April 2024)
    //  - QNX 8 (December 2023)
    return ENOSYS;
#elif defined(__GLIBC__) || defined(__APPLE__) || defined(__FreeBSD__) || defined(__ANDROID__) || defined(__musl__)
    // Pre-standard posix_spawn_file_actions_addchdir_np version available in:
    //  - Solaris 11.3 (October 2015)
    //  - Glibc 2.29 (February 2019)
    //  - macOS 10.15 (October 2019)
    //  - musl 1.1.24 (October 2019)
    //  - FreeBSD 13.1 (May 2022)
    //  - Android 14 (October 2023)
    return posix_spawn_file_actions_addchdir_np((posix_spawn_file_actions_t *)file_actions, path);
#else
    // Standardized posix_spawn_file_actions_addchdir version (POSIX.1-2024, June 2024) available in:
    //  - Solaris 11.4 (August 2018)
    //  - NetBSD 10.0 (March 2024)
    return posix_spawn_file_actions_addchdir((posix_spawn_file_actions_t *)file_actions, path);
#endif
}

bool SPM_posix_spawn_file_actions_addchdir_np_supported() {
#if (defined(__GLIBC__) && !__GLIBC_PREREQ(2, 29)) || (defined(__OpenBSD__)) || (defined(__ANDROID__) && __ANDROID_API__ < 34) || (defined(__QNX__))
    return false;
#else
    return true;
#endif
}

int SPM_posix_spawnp(pid_t *pid, const char *file, const posix_spawn_file_actions_t *actions, const posix_spawnattr_t *attr, char *const argv[], char *const env[]) {
    return posix_spawnp(pid, file, actions, attr, argv, env);
}

#endif
