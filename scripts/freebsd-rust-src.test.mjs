import assert from 'node:assert/strict'
import test from 'node:test'
import { ensureSvgRustSrc } from '../compat/freebsd-rust-src.mjs'

test('installs and checks rust-src for the exact toolchain mounted by Cross', () => {
  const calls = []
  assert.equal(ensureSvgRustSrc({
    exec(bin, args) {
      calls.push([bin, ...args])
      if (args[0] === 'default') return 'nightly-x86_64-unknown-linux-gnu (default)\n'
      if (bin === 'rustc') return '/toolchain-root\n'
    },
    stat(path) {
      assert.equal(path, '/toolchain-root/lib/rustlib/src/rust/library/Cargo.lock')
      return { isFile: () => true }
    }
  }), true)
  assert.deepEqual(calls, [
    ['rustup', 'default'],
    ['rustup', 'toolchain', 'install', 'nightly-2026-11-24', '--profile', 'minimal', '--component', 'rust-src', '--no-self-update'],
    ['rustc', '+nightly-2026-11-24', '--print', 'sysroot']
  ])
})

test('other default toolchains do not trigger a toolchain install', () => {
  for (const value of ['stable-x86_64-unknown-linux-gnu', 'nightly-2026-11-24-x86_64-unknown-linux-gnu']) {
    assert.equal(ensureSvgRustSrc({
      exec(bin, args) {
        assert.deepEqual([bin, ...args], ['rustup', 'default'])
        return `${value} (default)\n`
      }
    }), false)
  }
})
