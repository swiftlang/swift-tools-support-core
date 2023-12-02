#if defined(__linux__)

#include <spawn.h>
#include <stdbool.h>

// Wrapper method for posix_spawn_file_actions_addchdir_np that fails on Linux versions that do not have this method available.
int SPM_posix_spawn_file_actions_addchdir_np(posix_spawn_file_actions_t *restrict file_actions, const char *restrict path);

// Runtime check for the availability of posix_spawn_file_actions_addchdir_np. Returns 0 if the method is available, -1 if not.
bool SPM_posix_spawn_file_actions_addchdir_np_supported();

// Alternative for posix_spawn_file_actions_addchdir_np on Linux that mimics its behavior using fork, exec*, and chdir.
int SPM_fork_exec_chdir(pid_t *pid, const char *target_directory, const char *cmd, char *const argv[], char *const envp[],
                        int in_pipe[], int out_pipe[], int err_pipe[], bool redirect_out, bool redirect_err);

#endif
