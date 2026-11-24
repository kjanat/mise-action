import * as core from '@actions/core'
import * as fs from 'fs'
import * as path from 'path'

export interface TreeStats {
  files: number
  dirs: number
  bytes: number
}

const phases: Array<[string, number]> = []

export async function timed<T>(
  phase: string,
  op: () => Promise<T>
): Promise<T> {
  const start = performance.now()
  try {
    return await op()
  } finally {
    const seconds = (performance.now() - start) / 1000
    phases.push([phase, seconds])
    core.info(`timing: ${phase} took ${seconds.toFixed(2)}s`)
  }
}

export async function treeStats(dir: string): Promise<TreeStats> {
  const stats: TreeStats = { files: 0, dirs: 0, bytes: 0 }
  const pending = [dir]
  for (let next = pending.pop(); next !== undefined; next = pending.pop()) {
    let entries: fs.Dirent[]
    try {
      entries = await fs.promises.readdir(next, { withFileTypes: true })
    } catch {
      continue
    }
    for (const entry of entries) {
      const full = path.join(next, entry.name)
      if (entry.isDirectory()) {
        stats.dirs++
        pending.push(full)
      } else {
        stats.files++
        stats.bytes += (await fs.promises.lstat(full)).size
      }
    }
  }
  return stats
}

export async function writeTimingSummary(dirStats?: TreeStats): Promise<void> {
  const rows = phases.map(([phase, seconds]) => [phase, seconds.toFixed(2)])
  const summary = core.summary
    .addHeading(`mise-action timings (${process.platform})`, 3)
    .addTable([
      [
        { data: 'Phase', header: true },
        { data: 'Seconds', header: true }
      ],
      ...rows
    ])
  if (dirStats) {
    summary.addRaw(
      `mise dir: ${dirStats.files} files, ${dirStats.dirs} directories, ${(
        dirStats.bytes /
        1024 /
        1024
      ).toFixed(1)} MiB\n`,
      true
    )
  }
  await summary.write()
}
