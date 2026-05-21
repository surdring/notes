#!/usr/bin/env node
/**
 * 通用 Git 提交助手（提交后自动推送）
 *
 * 运行方式:
 *   1. npm run commit                    # 自动生成提交信息 + push
 *   2. npm run commit -- "feat: xxx"     # 自定义提交信息 + push
 *   3. node scripts/git-commit.js          # 直接运行
 *   4. node scripts/git-commit.js "feat: xxx"  # 带自定义信息
 *
 * 不带参数时会根据变更文件自动生成提交信息
 */

import { execSync } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, resolve, extname, basename } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const ANSI = {
  reset: '\x1b[0m', bright: '\x1b[1m', red: '\x1b[31m',
  green: '\x1b[32m', yellow: '\x1b[33m', cyan: '\x1b[36m', gray: '\x1b[90m',
};

function run(cmd) {
  return execSync(cmd, { encoding: 'utf-8', cwd: ROOT }).trim();
}

function color(c, text) {
  return `${ANSI[c]}${text}${ANSI.reset}`;
}

function getChangedFiles() {
  const status = run('git status --porcelain');
  if (!status) return [];
  return status.split('\n').map(line => {
    // --porcelain format: "XY filename" or "XY orig -> dest" for renames
    // XY is exactly 2 chars, then at least one space, then filename
    const trimmed = line.trim();
    if (!trimmed) return null;
    const statusCode = trimmed.substring(0, 2).trim();
    const file = trimmed.substring(2).trim().replace(/^.*->\s*/, ''); // handle renames
    return { status: statusCode, file };
  }).filter(f => f && f.file);
}

function generateMessage(files) {
  const added = files.filter(f => f.status === 'A' || f.status === '??');
  const modified = files.filter(f => f.status === 'M');
  const deleted = files.filter(f => f.status === 'D');

  const parts = [];
  if (added.length > 0) parts.push(`新增 ${added.length} 文件`);
  if (modified.length > 0) parts.push(`修改 ${modified.length} 文件`);
  if (deleted.length > 0) parts.push(`删除 ${deleted.length} 文件`);

  // Build scope from affected directories (top-level)
  const dirs = [...new Set(files.map(f => f.file.split('/')[0]))];
  const scope = dirs.length === 1 ? dirs[0] : `${dirs.length} dirs`;

  const subject = parts.join(', ') || '更新';
  return `update(${scope}): ${subject}`;
}

function main() {
  console.log(color('bright', '\n  Git Commit Helper\n'));

  // Check if in a git repo
  try {
    run('git rev-parse --git-dir');
  } catch {
    console.log(color('red', '  错误: 当前目录不是 Git 仓库\n'));
    process.exit(1);
  }

  const branch = run('git branch --show-current');
  console.log(`  当前分支: ${color('cyan', branch)}\n`);

  const files = getChangedFiles();
  if (files.length === 0) {
    console.log(color('yellow', '  没有变更的文件，无需提交\n'));
    process.exit(0);
  }

  console.log(color('bright', '  变更文件:'));
  for (const { status, file } of files) {
    const colorName = status === 'M' ? 'yellow' : status === 'A' || status === '??' ? 'green' : status === 'D' ? 'red' : 'gray';
    console.log(`    ${color(colorName, status.padStart(2))}  ${file}`);
  }
  console.log();

  // Stage all changes
  run('git add -A');
  console.log(color('green', '  已添加到暂存区'));

  // Check if there are actually staged changes
  const diff = run('git diff --cached --stat');
  if (!diff) {
    console.log(color('yellow', '  暂存区无实际变更，跳过提交\n'));
    process.exit(0);
  }
  console.log();

  // Commit message
  let message = process.argv[2];
  if (!message) {
    message = generateMessage(files);
    console.log(color('gray', `  自动生成提交信息: "${message}"`));
    console.log(color('gray', '  提示: 可传入参数自定义，如 npm run commit -- "feat: 新增功能"\n'));
  }

  try {
    // Escape quotes in message for shell safety
    const safeMessage = message.replace(/"/g, '\\"');
    run(`git commit -m "${safeMessage}"`);
    const hash = run('git rev-parse --short HEAD');
    console.log(color('green', `  提交成功: ${hash}`));
    try {
      run(`git push origin ${branch}`);
      console.log(color('green', `  推送成功: origin/${branch}\n`));
    } catch (err) {
      const lines = (err.message || '').split('\n').filter(l => l.includes('fatal') || l.includes('error') || l.includes('remote'));
      const hint = lines.slice(0, 2).join(' ') || '未知错误';
      console.log(color('yellow', `  推送失败: ${hint}\n`));
    }
  } catch (err) {
    console.log(color('red', `  提交失败: ${err.message?.split('\n')[0] || '未知错误'}\n`));
    process.exit(1);
  }
}

main();
