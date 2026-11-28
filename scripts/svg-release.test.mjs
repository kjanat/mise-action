import assert from 'node:assert/strict'
import test from 'node:test'
import { svgReleaseEnvironment } from '../compat/svg-release.mjs'

const release = {
  GITHUB_REPOSITORY: 'kjanat/svg',
  GITHUB_RUN_ID: '46098822352',
  GITHUB_WORKFLOW_REF: 'kjanat/svg/.github/workflows/release.yml@refs/heads/master',
  INPUT_MISE_ENV: 'release',
  INPUT_INSTALL_ARGS: 'cross'
}

test('adds cargo-binstall to both Cross install selections', () => {
  assert.deepEqual(svgReleaseEnvironment(release), {
    INPUT_INSTALL_ARGS: 'cargo-binstall cross',
    MISE_DISABLE_TOOLS: 'rust'
  })
  assert.deepEqual(
    svgReleaseEnvironment({
      ...release,
      INPUT_INSTALL_ARGS: 'cross cargo:rust-script',
      MISE_DISABLE_TOOLS: 'go,rust'
    }),
    {
      INPUT_INSTALL_ARGS: 'cargo-binstall cross rust-script',
      MISE_DISABLE_TOOLS: 'go,rust'
    }
  )
})

test('leaves all other callers and install selections unchanged', () => {
  for (const override of [
    { GITHUB_REPOSITORY: 'somewhere/else' },
    { GITHUB_RUN_ID: '46098822353' },
    { GITHUB_WORKFLOW_REF: 'kjanat/svg/.github/workflows/ci.yml@refs/heads/master' },
    { INPUT_MISE_ENV: 'dev' },
    { INPUT_INSTALL_ARGS: 'bun' },
    { INPUT_INSTALL_ARGS: 'cargo-binstall cross' },
    { INPUT_INSTALL_ARGS: undefined }
  ]) assert.equal(svgReleaseEnvironment({ ...release, ...override }), undefined)
})
