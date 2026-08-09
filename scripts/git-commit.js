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
import { dirname, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const ANSI = {
  reset: '\x1b[0m', bright: '\x1b[1m', red: '\x1b[31m',
  green: '\x1b[32m', yellow: '\x1b[33m', cyan: '\x1b[36m', gray: '\x1b[90m',
};

const useColor = process.stdout.isTTY;

function run(cmd, opts = {}) {
  try {
    return execSync(cmd, { encoding: 'utf-8', cwd: ROOT, ...opts }).trimEnd();
  } catch (err) {
    const msg = err.stderr?.trim() || err.message;
    throw new Error(msg);
  }
}

function color(c, text) {
  return useColor ? `${ANSI[c]}${text}${ANSI.reset}` : text;
}

function getChangedFiles() {
  const status = run('git status --porcelain');
  if (!status) return [];
  return status.split('\n').map(line => {
    const trimmed = line.trim();
    if (!trimmed) return null;
    // --porcelain 格式: "XY filename" 或 "XY  orig -> dest" (重命名)
    const statusCode = trimmed.slice(0, 2).trim();
    const file = trimmed.slice(2).trim().replace(/^.*->\s*/, '');
    return { status: statusCode, file };
  }).filter(f => f && f.file);
}

function generateMessage(files) {
  const added = files.filter(f => f.status === 'A' || f.status === '??');
  const modified = files.filter(f => f.status === 'M');
  const deleted = files.filter(f => f.status === 'D');
  const renamed = files.filter(f => f.status === 'R');

  const parts = [];
  if (added.length > 0) parts.push(`新增 ${added.length} 文件`);
  if (modified.length > 0) parts.push(`修改 ${modified.length} 文件`);
  if (deleted.length > 0) parts.push(`删除 ${deleted.length} 文件`);
  if (renamed.length > 0) parts.push(`重命名 ${renamed.length} 文件`);

  // 从影响的顶层目录推断 scope
  const dirs = [...new Set(files.map(f => {
    const idx = f.file.indexOf('/');
    return idx === -1 ? '.' : f.file.slice(0, idx);
  }).filter(Boolean))];
  const scope = dirs.length === 1 && dirs[0] !== '.' ? dirs[0]
    : dirs.length > 1 ? `${dirs.length} dirs`
    : 'root';

  const subject = parts.join(', ') || '更新';
  return `update(${scope}): ${subject}`;
}

function main() {
  console.log(color('bright', '\n  Git Commit Helper\n'));

  // 检查是否在 Git 仓库中
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
    const colorName = status === 'M' ? 'yellow'
      : status === 'A' || status === '??' ? 'green'
      : status === 'D' ? 'red' : 'gray';
    console.log(`    ${color(colorName, status.padStart(2))}  ${file}`);
  }
  console.log();

  // 暂存所有变更
  run('git add -A');
  console.log(color('green', '  已添加到暂存区'));

  // 检查是否真的有暂存变更（--quiet: 退出码 0=无差异, 非0=有差异）
  let hasStagedChanges = false;
  try {
    run('git diff --cached --quiet');
  } catch {
    hasStagedChanges = true;
  }
  if (!hasStagedChanges) {
    console.log(color('yellow', '  暂存区无实际变更，跳过提交\n'));
    process.exit(0);
  }
  console.log();

  // 提交信息
  let message = process.argv[2]?.trim();
  if (!message) {
    message = generateMessage(files);
    console.log(color('gray', `  自动生成提交信息: "${message}"`));
    console.log(color('gray', '  提示: 可传入参数自定义，如 npm run commit -- "feat: 新增功能"\n'));
  }

  try {
    const safeMessage = message.replace(/"/g, '\\"');
    run(`git commit -m "${safeMessage}"`);
    const hash = run('git rev-parse --short HEAD');
    console.log(color('green', `  提交成功: ${hash}`));
    try {
      run(`git push origin ${branch}`);
      console.log(color('green', `  推送成功: origin/${branch}\n`));
    } catch (err) {
      const hint = (err.message || '').split('\n').slice(0, 2).join('; ');
      console.log(color('yellow', `  推送失败: ${hint}\n`));
    }
  } catch (err) {
    console.log(color('red', `  提交失败: ${(err.message || '').split('\n')[0]}\n`));
    process.exit(1);
  }
}

main();