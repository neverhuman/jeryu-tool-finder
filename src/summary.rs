//! `summary`: print the sibling jeryu-tool registry summary. The authoritative
//! aggregation is `jeryu-toolctl registry-summary`, owned by jeryu-tool (the
//! registry owner); this subcommand delegates to it from inside the jeryu-tool
//! checkout, so there is exactly one summary implementation.

use std::ffi::OsString;
use std::path::PathBuf;

use anyhow::{Context, Result, bail};
use clap::Args;

use crate::paths;

#[derive(Args)]
pub struct SummaryArgs {
    /// The sibling jeryu-tool checkout owning the registry.
    #[arg(long = "jeryu-tool", default_value_os_t = paths::default_jeryu_tool())]
    jeryu_tool: PathBuf,
    /// The jeryu-toolctl binary (a path or a name resolved on PATH).
    #[arg(long, env = "JERYU_TOOLCTL", default_value = "jeryu-toolctl")]
    toolctl: OsString,
    /// Extra arguments passed through to `jeryu-toolctl registry-summary`.
    #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
    rest: Vec<String>,
}

pub fn run(args: SummaryArgs) -> Result<()> {
    if !args.jeryu_tool.is_dir() {
        bail!(
            "jeryu-tool checkout not found: {}",
            args.jeryu_tool.display()
        );
    }
    let toolctl = args.toolctl.to_string_lossy().into_owned();
    let status = std::process::Command::new(&args.toolctl)
        .arg("registry-summary")
        .args(&args.rest)
        .current_dir(&args.jeryu_tool)
        .status()
        .with_context(|| {
            format!("run `{toolctl} registry-summary` (is jeryu-toolctl installed?)")
        })?;
    if !status.success() {
        bail!("`{toolctl} registry-summary` exited with {status}");
    }
    Ok(())
}
