// This compatibility shim is only for the existing SVG 0.6.0 release run.
// It leaves all other v6 callers on the original bundle and inputs.
export function svgReleaseEnvironment(env) {
  const args = (env.INPUT_INSTALL_ARGS ?? '').trim()
  if (
    env.GITHUB_REPOSITORY !== 'kjanat/svg' ||
    env.GITHUB_RUN_ID !== '46098822352' ||
    env.GITHUB_WORKFLOW_REF !== 'kjanat/svg/.github/workflows/release.yml@refs/heads/master' ||
    env.INPUT_MISE_ENV !== 'release' ||
    !['cross', 'cross cargo:rust-script'].includes(args)
  ) {
    return undefined
  }

  // Mise 2026.11.14 checks configured install dependencies even if they
  // were not requested. Install the helper in the batch; keep using the
  // runner's Rust (including the separately installed nightly on tier 3).
  const disabled = new Set((env.MISE_DISABLE_TOOLS ?? '').split(',').map(tool => tool.trim()).filter(Boolean))
  disabled.add('rust')
  // Use the configured alias so mise exposes rust-script on the job PATH.
  const tools = args === 'cross' ? 'cross' : 'cross rust-script'
  return {
    INPUT_INSTALL_ARGS: `cargo-binstall ${tools}`,
    MISE_DISABLE_TOOLS: [...disabled].join(',')
  }
}
