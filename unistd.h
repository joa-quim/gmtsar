#ifndef GMTSAR_COMPAT_UNISTD_H
#define GMTSAR_COMPAT_UNISTD_H

#ifdef _WIN32

#	include <direct.h>
#	include <process.h>
#	include <io.h>

#ifndef PATH_MAX
#	define PATH_MAX 260
#endif

#	define R_OK 04
#	define W_OK 02
#	define X_OK 01
#	define F_OK 00

	/* POSIX mkdir accepts a mode; the MSVC CRT's _mkdir does not. */
#	define mkdir(path, mode) _mkdir(path)

#else
	/* This compatibility header can precede the system include directories in
	 * the Autotools build.  Forward Unix builds to their native header. */
#	include_next <unistd.h>
#endif

#endif /* GMTSAR_COMPAT_UNISTD_H */
