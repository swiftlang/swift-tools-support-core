#undef _GNU_SOURCE
#include "strerror.h"
#include <string.h>

#ifndef _WIN32
int tsc_strerror_r(int errnum, char *buf, size_t buflen) {
    return strerror_r(errnum, buf, buflen);
}
#endif
