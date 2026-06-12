//! `summary`: print the sibling jeryu-tool registry summary. The authoritative
//! aggregation lives in jeryu-tool's `ops/registry_summary.py` (the registry
//! owner); this subcommand delegates to it exactly like the Python wrapper
//! did, so there is exactly one summary implementation.

use std::path::PathBuf;

use anyhow::{Context, Result, bail};
use clap::Args;

use crate::paths;

#[derive(Args)]
pub struct SummaryArgs {
    /// The sibling jeryu-tool checkout owning the registry.
    #[arg(long = "jeryu-tool", default_value_os_t = paths::default_jeryu_tool())]
    jeryu_tool: PathBuf,
    /// Extra arguments passed through to registry_summary.py.
    #[arg(trailing_var_arg = true)]
    rest: Vec<String>,
}

pub fn run(args: SummaryArgs) -> Result<()> {
    let script = args.jeryu_tool.join("ops").join("registry_summary.py");
    if !script.is_file() {
        bail!("registry summary script not found: {}", script.display());
    }
    let status = std::process::Command::new("python3")
        .arg(&script)
        .args(&args.rest)
        .current_dir(&args.jeryu_tool)
        .status()
        .context("run registry_summary.py")?;
    if !status.success() {
        bail!("registry_summary.py exited with {status}");
    }
    Ok(())
}
