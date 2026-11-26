/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if os(Windows)

import WinSDK

@_transparent
internal var CREATE_NEW_PROCESS_GROUP: DWORD {
  DWORD(WinSDK.CREATE_NEW_PROCESS_GROUP)
}

@_transparent
internal var CREATE_SUSPENDED: DWORD {
  DWORD(WinSDK.CREATE_SUSPENDED)
}

@_transparent
internal var ENABLE_VIRTUAL_TERMINAL_PROCESSING: DWORD {
  DWORD(WinSDK.ENABLE_VIRTUAL_TERMINAL_PROCESSING)
}

@_transparent
internal var FILE_ATTRIBUTE_NORMAL: DWORD {
  DWORD(WinSDK.FILE_ATTRIBUTE_NORMAL)
}

@_transparent
internal var FILE_FLAG_BACKUP_SEMANTICS: DWORD {
  DWORD(WinSDK.FILE_FLAG_BACKUP_SEMANTICS)
}

@_transparent
internal var FILE_FLAG_OVERLAPPED: DWORD {
  DWORD(WinSDK.FILE_FLAG_OVERLAPPED)
}

@_transparent
internal var FILE_LIST_DIRECTORY: DWORD {
  DWORD(WinSDK.FILE_LIST_DIRECTORY)
}

@_transparent
internal var FILE_NOTIFY_CHANGE_CREATION: DWORD {
  DWORD(WinSDK.FILE_NOTIFY_CHANGE_CREATION)
}

@_transparent
internal var FILE_NOTIFY_CHANGE_DIR_NAME: DWORD {
  DWORD(WinSDK.FILE_NOTIFY_CHANGE_DIR_NAME)
}

@_transparent
internal var FILE_NOTIFY_CHANGE_FILE_NAME: DWORD {
  DWORD(WinSDK.FILE_NOTIFY_CHANGE_FILE_NAME)
}

@_transparent
internal var FILE_NOTIFY_CHANGE_LAST_WRITE: DWORD {
  DWORD(WinSDK.FILE_NOTIFY_CHANGE_LAST_WRITE)
}

@_transparent
internal var FILE_NOTIFY_CHANGE_SIZE: DWORD {
  DWORD(WinSDK.FILE_NOTIFY_CHANGE_SIZE)
}

@_transparent
internal var FILE_SHARE_DELETE: DWORD {
  DWORD(WinSDK.FILE_SHARE_DELETE)
}

@_transparent
internal var FILE_SHARE_READ: DWORD {
  DWORD(WinSDK.FILE_SHARE_READ)
}

@_transparent
internal var FILE_SHARE_WRITE: DWORD {
  DWORD(WinSDK.FILE_SHARE_WRITE)
}

@_transparent
internal var GENERIC_READ: DWORD {
  DWORD(WinSDK.GENERIC_READ)
}

@_transparent
internal var GENERIC_WRITE: DWORD {
  DWORD(WinSDK.GENERIC_WRITE)
}

@_transparent
internal var JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE: DWORD {
  DWORD(WinSDK.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE)
}

@_transparent
internal var JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK: DWORD {
  DWORD(WinSDK.JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK)
}

@_transparent
internal var LOCKFILE_EXCLUSIVE_LOCK: DWORD {
  DWORD(WinSDK.LOCKFILE_EXCLUSIVE_LOCK)
}

@_transparent
internal var LOCKFILE_FAIL_IMMEDIATELY: DWORD {
  DWORD(WinSDK.LOCKFILE_FAIL_IMMEDIATELY)
}

@_transparent
internal var OPEN_ALWAYS: DWORD {
  DWORD(WinSDK.OPEN_ALWAYS)
}

@_transparent
internal var OPEN_EXISTING: DWORD {
  DWORD(WinSDK.OPEN_EXISTING)
}

@_transparent
internal var VOLUME_NAME_DOS: DWORD {
  DWORD(WinSDK.VOLUME_NAME_DOS)
}

@_transparent
internal var WAIT_TIMEOUT: DWORD {
  DWORD(WinSDK.WAIT_TIMEOUT)
}

#endif
