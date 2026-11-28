import { svgReleaseEnvironment } from './svg-release.mjs'

const env = svgReleaseEnvironment(process.env)
if (env !== undefined) {
  console.log('SVG 0.6.0 release compatibility: install cargo-binstall with Cross and use runner Rust')
  Object.assign(process.env, env)
}
await import('../dist/index.js')
