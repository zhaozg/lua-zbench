//! lua-zbench shared library entry point.
//! This file defines the Lua C API entry point `luaopen_zbench`
//! that Lua calls when loading the module via `require("zbench")`.

const std = @import("std");
const lua_zbench = @import("zbench");

// luaopen_zbench is exported from lua_zbench.zig
// We just need to reference the module to ensure it's linked
comptime {
    _ = lua_zbench.luaopen_zbench;
}
