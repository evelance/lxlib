symbols = {
    { CFunction, "attributes",        "file_info" },
    { CFunction, "chdir",             "change_dir" },
    { CFunction, "currentdir",        "get_dir" },
    { CFunction, "dir",               "dir_iter_factory" },
    { CFunction, "link",              "make_link" },
    { CFunction, "lock",              "file_lock" },
    { CFunction, "mkdir",             "make_dir" },
    { CFunction, "rmdir",             "remove_dir" },
    { CFunction, "symlinkattributes", "link_info" },
    { CFunction, "setmode",           "lfs_f_setmode" },
    { CFunction, "touch",             "file_utime" },
    { CFunction, "unlock",            "file_unlock" },
    { CFunction, "lock_dir",          "lfs_lock_dir" },
    { CString,   "_COPYRIGHT",        [["Copyright (C) 2003-2017 Kepler Project"]] },
    { CString,   "_DESCRIPTION",      [["LuaFileSystem is a Lua library developed to complement the set of functions ]]
                                    ..[[related to file systems offered by the standard Lua distribution"]] },
    { CString,   "_VERSION",          [["LuaFileSystem " LFS_VERSION]] },
}
