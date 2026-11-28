import { execFileSync } from 'node:child_process'
import { statSync } from 'node:fs'
import { join } from 'node:path'

const toolchain = 'nightly-2026-11-24'

export function ensureSvgRustSrc({ exec = execFileSync, stat = statSync } = {}) {
  const query = { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] }
  // Only the tier-3 setup selects an undated nightly as the default.
  // The checked-out rust-toolchain.toml still overrides the active toolchain.
  const [defaultToolchain] = exec('rustup', ['default'], query).trim().split(/\s+/)
  if (!/^nightly(?:-x86_64-unknown-linux-gnu)?$/.test(defaultToolchain)) return false

  exec('rustup', ['toolchain', 'install', toolchain, '--profile', 'minimal', '--component', 'rust-src', '--no-self-update'], {
    stdio: 'inherit'
  })
  const sysroot = exec('rustc', [`+${toolchain}`, '--print', 'sysroot'], query).trim()
  if (!stat(join(sysroot, 'lib/rustlib/src/rust/library/Cargo.lock')).isFile()) {
    throw new Error(`rust-src for ${toolchain} does not contain library/Cargo.lock`)
  }
  return true
}
