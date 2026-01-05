#!/usr/bin/env python3
 #
 # 用途：从 RAGFlow 导出“图片 OCR 解析后的 chunks”，并转换为大模型更容易解析的结构化格式（JSONL / Markdown）。
 #
 # 你需要准备 3 个参数：
 # 1) api-key：RAGFlow UI 右上角头像 -> API 页面获取（用于请求头 Authorization: Bearer <api-key>）。
 # 2) dataset-id：知识库 ID。
 #    - UI 里通常能在知识库页面 URL 中看到；或调用 SDK 接口 GET /api/v1/datasets 列表拿到 id。
 # 3) document-id：文档 ID（图片文件对应的 document）。
 #    - 可用 SDK 接口 GET /api/v1/datasets/<dataset_id>/documents 找到 name=图片文件名的那条记录的 id。
 #
 # base-url 怎么填？
 # - 本脚本走的是“SDK 接口”，路由前缀是 /api/v1。
 # - 你在浏览器里看到的 /v1/document/list 属于 UI 登录态接口，不是本脚本使用的接口。
 # - 因此 base-url 通常应为： http://<host>:<port>/api/v1
 #
 # 示例：导出为 JSONL（推荐给后续 LLM/ETL 处理）
 #   python tools/export_image_ocr_for_llm.py \
 #     --base-url http://127.0.0.1:8088/api/v1 \
 #     --api-key <YOUR_API_KEY> \
 #     --dataset-id <YOUR_DATASET_ID> \
 #     --document-id <YOUR_DOCUMENT_ID> \
 #     --format jsonl \
 #     --out /tmp/ocr_chunks.jsonl
 #
 # 示例：导出为 Markdown（表格能识别就输出 Markdown Table，否则输出原文本）
 #   python tools/export_image_ocr_for_llm.py \
 #     --base-url http://127.0.0.1:8088/api/v1 \
 #     --api-key <YOUR_API_KEY> \
 #     --dataset-id <YOUR_DATASET_ID> \
 #     --document-id <YOUR_DOCUMENT_ID> \
 #     --format md \
 #     --out /tmp/ocr_chunks.md
 #
import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import requests


_SESSION = requests.Session()
_SESSION.trust_env = False


@dataclass
class ChunkRecord:
    chunk_id: str
    dataset_id: str
    document_id: str
    image_id: str
    positions: list[list[int]]
    raw_text: str
    rows: list[list[str]]
    delimiter: str


def _join_url(base: str, path: str) -> str:
    base = (base or "").rstrip("/")
    path = (path or "").lstrip("/")
    return f"{base}/{path}" if base else f"/{path}"


def _build_headers(api_key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "Accept": "application/json",
        "Connection": "close",
    }


def _curl_request_json(url: str, headers: dict[str, str], params: dict[str, Any] | None, timeout: int) -> dict:
    if not shutil.which("curl"):
        raise RuntimeError("curl not found")

    if params:
        from urllib.parse import urlencode

        qs = urlencode(params, doseq=True)
        if "?" in url:
            full_url = url + ("&" if not url.endswith("?") and not url.endswith("&") else "") + qs
        else:
            full_url = url + "?" + qs
    else:
        full_url = url

    args: list[str] = [
        "curl",
        "-sS",
        "--fail",
        "--max-time",
        str(int(timeout)),
    ]
    for k, v in headers.items():
        args.extend(["-H", f"{k}: {v}"])
    args.append(full_url)

    try:
        out = subprocess.check_output(args, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
        body = ""
        try:
            body = (e.output or b"").decode("utf-8", errors="replace")
        except Exception:
            body = ""
        raise RuntimeError(f"curl request failed: {body[:2000]}") from e

    return json.loads(out.decode("utf-8"))


def _request_json(
    method: str,
    url: str,
    headers: dict[str, str],
    params: dict[str, Any] | None = None,
    *,
    timeout: int = 60,
    retries: int = 2,
) -> dict:
    last_exc: Exception | None = None
    for attempt in range(max(0, int(retries)) + 1):
        try:
            resp = _SESSION.request(method, url, headers=headers, params=params, timeout=timeout)
        except requests.RequestException as e:
            last_exc = e
            if attempt < retries:
                time.sleep(1.0 * (2**attempt))
                continue
            raise

        if resp.status_code in {502, 503, 504} and attempt < retries:
            time.sleep(1.0 * (2**attempt))
            continue

        try:
            resp.raise_for_status()
        except requests.HTTPError as e:
            body = ""
            try:
                body = resp.text
            except Exception:
                body = ""
            raise requests.HTTPError(
                f"{e} | status_code={resp.status_code} | response_body={body[:2000]}",
                response=resp,
            ) from e

        data = resp.json()
        if isinstance(data, dict) and data.get("code", 0) not in (0, "0"):
            raise RuntimeError(f"API error: code={data.get('code')} message={data.get('message')}")
        return data

    if last_exc is not None:
        raise last_exc
    raise RuntimeError("请求失败：未知错误")


def _fetch_all_chunks(
    base_url: str,
    api_key: str,
    dataset_id: str,
    document_id: str,
    page_size: int,
    keywords: str = "",
    timeout: int = 60,
    retries: int = 2,
    curl_fallback: bool = True,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    url = _join_url(base_url, f"datasets/{dataset_id}/documents/{document_id}/chunks")
    headers = _build_headers(api_key)

    page = 1
    chunks: list[dict[str, Any]] = []
    doc: dict[str, Any] = {}
    total: int | None = None

    while True:
        params = {
            "page": page,
            "page_size": page_size,
        }
        if keywords:
            params["keywords"] = keywords

        try:
            data = _request_json(
                "GET",
                url,
                headers=headers,
                params=params,
                timeout=timeout,
                retries=retries,
            )
        except requests.HTTPError as e:
            sc = getattr(getattr(e, "response", None), "status_code", None)
            if curl_fallback and sc in {502, 503, 504} and shutil.which("curl"):
                data = _curl_request_json(url, headers=headers, params=params, timeout=timeout)
            else:
                raise
        payload = (data.get("data") or {}) if isinstance(data, dict) else {}

        if not doc:
            doc = payload.get("doc") or {}
        batch = payload.get("chunks") or []
        if total is None:
            try:
                total = int(payload.get("total") or 0)
            except Exception:
                total = 0

        if not isinstance(batch, list) or not batch:
            break

        chunks.extend(batch)

        if total is not None and len(chunks) >= total:
            break

        page += 1

    return doc, chunks


def _split_lines(text: str) -> list[str]:
    lines = [ln.strip() for ln in (text or "").splitlines()]
    return [ln for ln in lines if ln]


def _guess_delimiter(lines: list[str]) -> str:
    if not lines:
        return ""

    if any("\t" in ln for ln in lines):
        return "\t"

    pipe_lines = [ln for ln in lines if ln.count("|") >= 2]
    if len(pipe_lines) >= max(2, len(lines) // 3):
        return "|"

    space_split_lines = [ln for ln in lines if re.search(r"\s{2,}", ln)]
    if len(space_split_lines) >= max(2, len(lines) // 3):
        return "  "

    return ""


def _parse_markdown_pipe_table(lines: list[str]) -> list[list[str]]:
    rows: list[list[str]] = []
    for ln in lines:
        s = ln.strip()
        if not s:
            continue
        if set(s.replace("|", "").strip()) <= {"-", ":"}:
            continue
        if s.startswith("|"):
            s = s[1:]
        if s.endswith("|"):
            s = s[:-1]
        cells = [c.strip() for c in s.split("|")]
        if any(cells):
            rows.append([c for c in cells])
    return rows


def _parse_rows(text: str) -> tuple[list[list[str]], str]:
    lines = _split_lines(text)
    delim = _guess_delimiter(lines)

    if not lines:
        return [], delim

    if delim == "|":
        rows = _parse_markdown_pipe_table(lines)
        if rows and max(len(r) for r in rows) >= 2:
            return rows, "|"

    if delim == "\t":
        rows = [[c.strip() for c in ln.split("\t")] for ln in lines]
        if rows and max(len(r) for r in rows) >= 2:
            return rows, "\\t"

    if delim == "  ":
        rows = [[c.strip() for c in re.split(r"\s{2,}", ln.strip())] for ln in lines]
        if rows and max(len(r) for r in rows) >= 2:
            return rows, "\\s{2,}"

    return [[ln] for ln in lines], ""


def _to_chunk_record(dataset_id: str, document_id: str, chunk: dict[str, Any]) -> ChunkRecord:
    raw_text = str(chunk.get("content") or "").strip()
    rows, delim = _parse_rows(raw_text)
    return ChunkRecord(
        chunk_id=str(chunk.get("id") or ""),
        dataset_id=dataset_id,
        document_id=document_id,
        image_id=str(chunk.get("image_id") or ""),
        positions=chunk.get("positions") or [],
        raw_text=raw_text,
        rows=rows,
        delimiter=delim,
    )


def _write_jsonl(path: Path, doc: dict[str, Any], records: list[ChunkRecord]) -> None:
    obj = {
        "type": "ragflow_image_ocr_export_v1",
        "doc": doc,
    }
    header_path = path.with_suffix(path.suffix + ".meta.json")
    header_path.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

    with path.open("w", encoding="utf-8") as f:
        for r in records:
            f.write(
                json.dumps(
                    {
                        "chunk_id": r.chunk_id,
                        "dataset_id": r.dataset_id,
                        "document_id": r.document_id,
                        "image_id": r.image_id,
                        "positions": r.positions,
                        "delimiter": r.delimiter,
                        "raw_text": r.raw_text,
                        "rows": r.rows,
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )


def _rows_to_markdown_table(rows: list[list[str]], max_cols: int | None = None) -> str:
    if not rows:
        return ""

    coln = max(len(r) for r in rows)
    if max_cols is not None:
        coln = min(coln, max_cols)
    if coln <= 1:
        return ""

    def norm_row(r: list[str]) -> list[str]:
        rr = (r + [""] * coln)[:coln]
        return [c.replace("\n", " ").strip() for c in rr]

    header = norm_row(rows[0])
    body = [norm_row(r) for r in rows[1:]]

    out = []
    out.append("| " + " | ".join(header) + " |")
    out.append("| " + " | ".join(["---"] * coln) + " |")
    for r in body:
        out.append("| " + " | ".join(r) + " |")
    return "\n".join(out)


def _try_parse_int(s: str) -> int | None:
    ss = (s or "").strip()
    if not ss:
        return None
    if re.fullmatch(r"[+-]?\d+", ss):
        try:
            return int(ss)
        except Exception:
            return None
    return None


def _find_header_row(table_rows: list[list[str]], keywords: tuple[str, ...] | None = None) -> list[str] | None:
    if not table_rows:
        return None

    best: tuple[int, int, int, list[str]] | None = None
    for idx, row in enumerate(table_rows):
        if len(row) < 2:
            continue

        score = 0
        non_empty = 0
        for c in row:
            cc = (c or "").strip()
            if not cc:
                continue

            non_empty += 1
            if keywords and any(k in cc for k in keywords):
                score += 2

        first_is_number = _try_parse_int(row[0]) is not None

        # 通用启发式：表头往往“第一列不是数字”且“列数多/非空多”。
        if not first_is_number:
            score += 1

        # prefer: higher score, more non-empty cells, more columns, earlier
        cand = (score, non_empty, len(row), -idx, row)
        if best is None or cand > best:
            best = cand

    return None if best is None else best[4]


def _escape_md_cell(s: str) -> str:
    return (s or "").replace("\n", " ").replace("|", "\\|").strip()


def _write_llm_markdown(
    path: Path,
    doc: dict[str, Any],
    records: list[ChunkRecord],
    *,
    header_override: list[str] | None = None,
    header_keywords: tuple[str, ...] | None = None,
    sort_col: int = 1,
) -> None:
    name = str(doc.get("name") or doc.get("docnm_kwd") or "")

    table_rows: list[list[str]] = []
    notes: list[str] = []

    for r in records:
        if not r.rows:
            continue
        # 表格：至少两列，且不是明显的“标题”单列文本
        if max((len(x) for x in r.rows), default=0) >= 2:
            for row in r.rows:
                if len(row) >= 2:
                    table_rows.append([str(c or "").strip() for c in row])
        else:
            t = (r.raw_text or "").strip()
            if t:
                notes.append(t)

    header = header_override or _find_header_row(table_rows, keywords=header_keywords)
    if header is not None:
        header_n = len(header)
    else:
        header_n = max((len(r) for r in table_rows), default=0)
        if header_n <= 0:
            header_n = 1
        header = [f"col_{i+1}" for i in range(header_n)]

    # 过滤掉 header 行本身（如果出现在数据里）
    header_norm = [c.strip() for c in header]
    filtered_rows: list[list[str]] = []
    for row in table_rows:
        if len(row) == len(header_norm) and [c.strip() for c in row] == header_norm:
            continue
        filtered_rows.append(row)

    # 排序：若第一列可解析为数字，按数字排序；否则保持原顺序
    sort_idx = max(0, int(sort_col) - 1)
    if sort_col <= 0:
        ordered_rows = list(filtered_rows)
    else:
        numeric_rows: list[tuple[int, list[str]]] = []
        other_rows: list[list[str]] = []
        for row in filtered_rows:
            if row and sort_idx < len(row):
                n = _try_parse_int(row[sort_idx])
                if n is not None:
                    numeric_rows.append((n, row))
                else:
                    other_rows.append(row)
            else:
                other_rows.append(row)
        numeric_rows.sort(key=lambda x: x[0])
        ordered_rows = [r for _, r in numeric_rows] + other_rows

    # 统一列数
    def pad(row: list[str]) -> list[str]:
        rr = (row + [""] * header_n)[:header_n]
        return [_escape_md_cell(x) for x in rr]

    md: list[str] = []
    md.append("# OCR 导出（可直接喂给大模型）")
    if name:
        md.append(f"\n- document: `{name}`")
    if doc.get("id"):
        md.append(f"- document_id: `{doc.get('id')}`")
    if doc.get("dataset_id"):
        md.append(f"- dataset_id: `{doc.get('dataset_id')}`")

    if notes:
        md.append("\n## 额外文本")
        for t in notes:
            md.append(f"- {t}")

    md.append("\n## 表格")
    md.append("| " + " | ".join([_escape_md_cell(c) for c in header]) + " |")
    md.append("| " + " | ".join(["---"] * header_n) + " |")
    for row in ordered_rows:
        md.append("| " + " | ".join(pad(row)) + " |")

    path.write_text("\n".join(md) + "\n", encoding="utf-8")


def _write_markdown(path: Path, doc: dict[str, Any], records: list[ChunkRecord]) -> None:
    name = str(doc.get("name") or doc.get("docnm_kwd") or "")
    lines: list[str] = []
    lines.append(f"# OCR 导出（LLM Friendly）")
    if name:
        lines.append(f"\n- document: `{name}`")
    if doc.get("id"):
        lines.append(f"- document_id: `{doc.get('id')}`")
    if doc.get("dataset_id"):
        lines.append(f"- dataset_id: `{doc.get('dataset_id')}`")

    for i, r in enumerate(records, start=1):
        lines.append("\n---\n")
        lines.append(f"## Chunk {i}")
        lines.append(f"\n- chunk_id: `{r.chunk_id}`")
        if r.image_id:
            lines.append(f"- image_id: `{r.image_id}`")
        if r.delimiter:
            lines.append(f"- delimiter: `{r.delimiter}`")
        if r.positions:
            lines.append(f"- positions: `{len(r.positions)}`")

        md_table = _rows_to_markdown_table(r.rows, max_cols=30)
        if md_table:
            lines.append("\n" + md_table)
        else:
            lines.append("\n```text\n" + (r.raw_text or "") + "\n```")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="从 RAGFlow 导出图片 OCR 解析后的 chunks，并转换为 LLM 更易解析的结构化格式。"
    )
    ap.add_argument("--base-url", required=True, help="例如：http://127.0.0.1:9380/api/v1")
    ap.add_argument("--api-key", required=True, help="RAGFlow API Key（放到 Authorization: Bearer ...）")
    ap.add_argument("--dataset-id", required=True)
    ap.add_argument("--document-id", required=True)
    ap.add_argument(
        "--format",
        choices=["jsonl", "md", "llm_md"],
        default="jsonl",
        help="导出格式：jsonl(默认) / md(逐 chunk 输出) / llm_md(合并为一张表，适合直接喂给大模型)",
    )
    ap.add_argument("--out", required=True, help="输出文件路径，例如：out.jsonl / out.md")
    ap.add_argument("--page-size", type=int, default=50)
    ap.add_argument("--timeout", type=int, default=60, help="HTTP 超时时间（秒）")
    ap.add_argument("--retries", type=int, default=2, help="遇到 502/503/504 或网络错误时的重试次数")
    ap.add_argument(
        "--curl-fallback",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="requests 多次 502/503/504 时，是否自动改用 curl 拉取（默认开启）",
    )
    ap.add_argument(
        "--llm-header",
        default="",
        help="llm_md：手工指定表头（逗号分隔），例如：'序号,姓名,岗位,班组,工作分工,备注'",
    )
    ap.add_argument(
        "--llm-header-keywords",
        default="",
        help="llm_md：用于自动识别表头的关键词（逗号分隔）。留空则用通用启发式（不依赖特定字段名）。",
    )
    ap.add_argument(
        "--llm-sort-col",
        type=int,
        default=1,
        help="llm_md：按第几列做数字排序（1-based）。<=0 表示不排序，保留原顺序。",
    )
    ap.add_argument("--keywords", default="", help="可选：仅导出命中关键词的 chunk（服务端高亮检索）")

    args = ap.parse_args(argv)

    out_path = Path(args.out)
    if out_path.parent and str(out_path.parent) not in (".", ""):
        out_path.parent.mkdir(parents=True, exist_ok=True)
    doc, chunks = _fetch_all_chunks(
        base_url=args.base_url,
        api_key=args.api_key,
        dataset_id=args.dataset_id,
        document_id=args.document_id,
        page_size=int(args.page_size),
        keywords=str(args.keywords or ""),
        timeout=int(args.timeout),
        retries=int(args.retries),
        curl_fallback=bool(args.curl_fallback),
    )

    records = [_to_chunk_record(args.dataset_id, args.document_id, c) for c in chunks]

    if args.format == "jsonl":
        _write_jsonl(out_path, doc, records)
    elif args.format == "md":
        _write_markdown(out_path, doc, records)
    else:
        header_override = None
        if str(args.llm_header or "").strip():
            header_override = [s.strip() for s in str(args.llm_header).split(",") if s.strip()]

        header_keywords = None
        if str(args.llm_header_keywords or "").strip():
            header_keywords = tuple(s.strip() for s in str(args.llm_header_keywords).split(",") if s.strip())

        _write_llm_markdown(
            out_path,
            doc,
            records,
            header_override=header_override,
            header_keywords=header_keywords,
            sort_col=int(args.llm_sort_col),
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
