//! lua-zbench shared library entry point.
//! This file defines the Lua C API entry point `luaopen_lua_zbench`
//! that Lua calls when loading the module via `require("lua_zbench")`.

const std = @import("std");
const lua_zbench = @import("lua_zbench");

// The luaopen function is exported from lua_zbench.zig
// This file exists as the root source for the shared library build.
