#if defined(__linux__)

#ifndef _GNU_SOURCE
#define _GNU_SOURCE /* for posix_spawn_file_actions_addchdir_np */
#endif

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

#include "process.h"

int SPM_posix_spawn_file_actions_addchdir_np(posix_spawn_file_actions_t *restrict file_actions, const char *restrict path) {
#if defined(__GLIBC__)
#  if __GLIBC_PREREQ(2, 29)
    return posix_spawn_file_actions_addchdir_np(file_actions, path);
#  else
    return ENOSYS;
#  endif
#else
    return ENOSYS;
#endif
}

bool SPM_posix_spawn_file_actions_addchdir_np_supported() {
#if defined(__GLIBC__)
#  if __GLIBC_PREREQ(2, 29)
    return true;
#  else
    return false;
#  endif
#else
    return false;
#endif
}

int SPM_fork_exec_chdir(pid_t *pid, const char *cwd,
                        const char *cmd, char *const argv[], char *const envp[],
                        int in_pipe[], int out_pipe[], int err_pipe[], bool redirect_out, bool redirect_err) {
    *pid = fork();

    if (*pid < 0) {
        perror("fork() failed");
        _exit(EXIT_FAILURE);
    } else if (*pid > 0) { // Parent process
        // Wait for child process to finish
        int status;
        waitpid(*pid, &status, 0);
        return status;
    } else { // Child process
        // Change working directory then execute cmd
        if (chdir(cwd)) {
            _exit(EXIT_FAILURE);
        }
        
        // Replicate pipe logic in TSCBasic.Process.launch()
        
        // Dupe the read portion of the remote to 0.
        dup2(in_pipe[0], 0);
        // Close the other side's pipe since it was duped to 0.
        close(in_pipe[0]);
        close(in_pipe[1]);
        
        if (redirect_out) {
            // Open the write end of the pipe.
            dup2(out_pipe[1], 1);
            // Close the other ends of the pipe since they were duped to 1.
            close(out_pipe[0]);
            close(out_pipe[1]);
            
            if (redirect_err) {
                // If merged was requested, send stderr to stdout.
                dup2(1, 2);
            } else {
                // If no redirect was requested, open the pipe for stderr.
                dup2(err_pipe[1], 2);
                // Close the other ends of the pipe since they were dupped to 2.
                close(err_pipe[0]);
                close(err_pipe[1]);
            }
        } else {
            dup2(1, 1);
            dup2(2, 2);
        }

        execve(cmd, argv, envp);
        
        // If execve returns, it must have failed.
        perror(cmd);
        _exit(EXIT_FAILURE);
    }
}

#endif
