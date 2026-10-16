use super::os_info;
use pretty_assertions::assert_eq;

#[test]
#[cfg(target_os = "linux")]
fn os_discovery_runs_once_per_process() {
    const PROBE_DIR: &str = "CODEX_TEST_OS_INFO_PROBE_DIR";
    if std::env::var_os(PROBE_DIR).is_some() {
        std::thread::scope(|scope| {
            for _ in 0..8 {
                scope.spawn(|| {
                    for _ in 0..4 {
                        assert_eq!(os_info().version().to_string(), "99.7.3");
                    }
                });
            }
        });
        return;
    }

    let temp = tempfile::tempdir().expect("probe directory");
    for (program, output) in [
        ("lsb_release", "Distributor ID: Ubuntu\nRelease: 99.7.3\n"),
        ("getconf", "64\n"),
    ] {
        codex_utils_cargo_bin::write_executable(
            &temp.path().join(program),
            &format!(
                "#!/bin/sh\nprintf '{program}\\n' >> \"${PROBE_DIR}/calls\"\nprintf '{output}'\n"
            ),
        )
        .expect("write probe");
    }
    let output = std::process::Command::new(std::env::current_exe().expect("test executable"))
        .args([
            "--exact",
            "tests::os_discovery_runs_once_per_process",
            "--nocapture",
        ])
        .env(PROBE_DIR, temp.path())
        .env("PATH", temp.path())
        .output()
        .expect("run isolated os_info test");
    assert!(output.status.success(), "{output:?}");
    let calls = std::fs::read_to_string(temp.path().join("calls")).expect("probe calls");
    let mut calls = calls.lines().collect::<Vec<_>>();
    calls.sort_unstable();
    assert_eq!(calls, vec!["getconf", "lsb_release"]);
}
