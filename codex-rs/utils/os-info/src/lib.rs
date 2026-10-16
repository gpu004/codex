use std::sync::LazyLock;

/// Process-wide OS information.
///
/// `os_info::get()` spawns `lsb_release` (which runs `dpkg-query`) and `getconf` on Linux, so every
/// crate must share this single cache instead of keeping its own.
#[expect(
    clippy::disallowed_methods,
    reason = "this is the single sanctioned caller of os_info::get"
)]
pub fn os_info() -> &'static os_info::Info {
    static OS_INFO: LazyLock<os_info::Info> = LazyLock::new(os_info::get);
    &OS_INFO
}

#[cfg(test)]
#[path = "os_info_tests.rs"]
mod tests;
