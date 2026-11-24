import * as path from 'path'

// GitHub-hosted Windows runners keep the workspace on D:, which unpacks the mise cache several times faster than C:.
export function workspaceDataDir(
  env: NodeJS.ProcessEnv,
  platform: NodeJS.Platform
): string | undefined {
  if (platform !== 'win32') return undefined
  if (env.MISE_DATA_DIR || env.XDG_DATA_HOME) return undefined
  const workspace = env.GITHUB_WORKSPACE
  if (!workspace) return undefined
  const root = path.win32.parse(workspace).root
  if (!root) return undefined
  const systemDrive = env.SYSTEMDRIVE
  if (systemDrive && root.toUpperCase().startsWith(systemDrive.toUpperCase())) {
    return undefined
  }
  return path.win32.join(root, 'mise')
}
