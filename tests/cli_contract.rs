//! Public command-line contract: the checked-in help text must change in the
//! same review as any user-visible command surface.

use std::process::Command;

#[test]
fn top_level_help_matches_tracked_contract() {
    let output = Command::new(env!("CARGO_BIN_EXE_jeryu-tool-finder"))
        .arg("--help")
        .output()
        .expect("run jeryu-tool-finder --help");

    assert!(
        output.status.success(),
        "--help failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(output.stderr.is_empty(), "--help wrote to stderr");
    assert_eq!(
        String::from_utf8(output.stdout).expect("help is UTF-8"),
        include_str!("../contracts/cli-help.txt"),
        "CLI help drifted; review and update contracts/cli-help.txt"
    );
}
