// Generated by `zig build`; DO NOT EDIT.

const builtin = @import("builtin");

pub const console = struct {
    extern fn sysjs_console_log(string: [*]const u8, string_len: u32) void;
    pub inline fn log(string: []const u8) void {
        return sysjs_console_log(string.ptr, string.len);
    }
    extern fn sysjs_console_log2(string: [*]const u8, string_len: u32, [*]const u8, u32) void;
    pub inline fn log2(string: []const u8, v1: []const u8) void {
        return sysjs_console_log2(string.ptr, string.len, v1.ptr, v1.len);
    }
};

pub const String = struct {
    extern fn sysjs_String_new(buf: [*]const u8, buf_len: u32) u32;
    pub inline fn new(buf: []const u8) String {
        return String{.id = sysjs_String_new(buf.ptr, buf.len});
    }
};
pub fn doPrint() void {
    // use console.log
    console.log("zig:js.console.log(\"hello from Zig\")");
}
