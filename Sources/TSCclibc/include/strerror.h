#include <stddef.h>

#ifndef _WIN32
extern int tsc_strerror_r(int errnum, char *buf, size_t buflen);
#endif
