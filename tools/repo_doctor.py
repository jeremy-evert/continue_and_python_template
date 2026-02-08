#!/usr/bin/env python3
"""
Repo Doctor v1 (anti-molasses)

What it does:
- Top 10 biggest Python files (LOC)
- Top 10 longest functions (LOC)
- Boundary check: core/ must not import forbidden modules:
  - requests
  - subprocess
  - sqlite3
- Writes reports/project_health.csv
- Prints a short terminal summary (rich if available)

Exit codes:
  0 = OK
  2 = Boundary violations found
  1 = Unexpected error
"""

from __future__ import annotations

import ast
import csv
import os
import sys
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

FORBIDDEN_CORE_IMPORTS = {"requests", "subprocess", "sqlite3"}

# Keep this intentionally conservative and "template-safe"
DEFAULT_EXCLUDE_DIRS = {
    ".git",
    ".venv",
    "venv",
    "ENV",
    "env",
    "__pycache__",
    ".pytest_cache",
    ".ruff_cache",
    ".mypy_cache",
    ".tox",
    ".nox",
    "build",
    "dist",
    "site",
    "node_modules",
    "runs",
    "reports",  # we still write reports, but we don't scan them
    ".idea",
    ".vscode",
}


@dataclass(frozen=True)
class FileStat:
    relpath: str
    loc: int


@dataclass(frozen=True)
class FunctionStat:
    relpath: str
    func_name: str
    start_line: int
    end_line: int
    loc: int


@dataclass(frozen=True)
class Violation:
    relpath: str
    kind: str
    detail: str
    line: int | None = None


def _repo_root() -> Path:
    # Tools lives at repo_root/tools/repo_doctor.py
    return Path(__file__).resolve().parents[1]


def _is_excluded_dir(dirname: str) -> bool:
    return dirname in DEFAULT_EXCLUDE_DIRS or dirname.startswith(".")


def iter_python_files(root: Path) -> Iterator[Path]:
    for dirpath, dirnames, filenames in os.walk(root):
        # prune excluded dirs in-place for os.walk
        dirnames[:] = [d for d in dirnames if not _is_excluded_dir(d)]
        for fn in filenames:
            if fn.endswith(".py"):
                yield Path(dirpath) / fn


def count_loc(text: str) -> int:
    # LOC = non-empty, non-whitespace lines
    return sum(1 for line in text.splitlines() if line.strip())


def safe_read_text(path: Path) -> str:
    # UTF-8 first; fall back to replacement to avoid crashing on odd encodings
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace")


def module_name_from_import(node: ast.AST) -> str | None:
    if isinstance(node, ast.Import):
        # import foo.bar as baz -> foo
        if not node.names:
            return None
        return node.names[0].name.split(".")[0]
    if isinstance(node, ast.ImportFrom):
        # from foo.bar import baz -> foo
        if node.module is None:
            return None
        return node.module.split(".")[0]
    return None


def find_core_boundary_violations(py_file: Path, relpath: str) -> list[Violation]:
    # Only enforce on files under src/**/core/** (common layout)
    parts = Path(relpath).parts
    if "core" not in parts:
        return []

    text = safe_read_text(py_file)
    try:
        tree = ast.parse(text, filename=relpath)
    except SyntaxError as e:
        return [
            Violation(
                relpath=relpath,
                kind="syntax_error",
                detail=str(e),
                line=e.lineno,
            )
        ]

    violations: list[Violation] = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            base = module_name_from_import(node)
            if base and base in FORBIDDEN_CORE_IMPORTS:
                line = getattr(node, "lineno", None)
                violations.append(
                    Violation(
                        relpath=relpath,
                        kind="core_forbidden_import",
                        detail=f"core/ imports forbidden module '{base}'",
                        line=line,
                    )
                )
    return violations


def function_stats_from_file(py_file: Path, relpath: str) -> list[FunctionStat]:
    text = safe_read_text(py_file)
    try:
        tree = ast.parse(text, filename=relpath)
    except SyntaxError:
        return []

    stats: list[FunctionStat] = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            start = getattr(node, "lineno", None)
            end = getattr(node, "end_lineno", None)
            if start is None or end is None:
                continue
            loc = (end - start) + 1
            stats.append(
                FunctionStat(
                    relpath=relpath,
                    func_name=node.name,
                    start_line=start,
                    end_line=end,
                    loc=loc,
                )
            )
    return stats


def ensure_reports_dir(root: Path) -> Path:
    reports_dir = root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    return reports_dir


def write_csv(
    report_path: Path,
    file_stats: list[FileStat],
    func_stats: list[FunctionStat],
    violations: list[Violation],
) -> None:
    """
    Single CSV with typed rows so it's easy to filter/sort in Excel.

    Columns:
      section, relpath, metric, value, detail, line
    """
    with report_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["section", "relpath", "metric", "value", "detail", "line"])

        for fs in file_stats:
            w.writerow(["file", fs.relpath, "loc", fs.loc, "", ""])

        for fn in func_stats:
            w.writerow(
                [
                    "function",
                    fn.relpath,
                    "loc",
                    fn.loc,
                    f"{fn.func_name} ({fn.start_line}-{fn.end_line})",
                    fn.start_line,
                ]
            )

        for v in violations:
            w.writerow(
                [
                    "violation",
                    v.relpath,
                    v.kind,
                    "1",
                    v.detail,
                    v.line if v.line is not None else "",
                ]
            )


def _try_rich():
    try:
        from rich.console import Console
        from rich.table import Table

        return Console, Table
    except Exception:
        return None, None


def print_summary(
    biggest_files: list[FileStat],
    longest_funcs: list[FunctionStat],
    violations: list[Violation],
    report_path: Path,
) -> None:
    Console, Table = _try_rich()

    if Console and Table:
        console = Console()
        console.print(
            f"[bold]Repo Doctor v1[/bold] -> wrote "
            f"[cyan]{report_path.as_posix()}[/cyan]"
        )

        t1 = Table(title="Top 10 Biggest Python Files (LOC)")
        t1.add_column("LOC", justify="right")
        t1.add_column("File")
        for fs in biggest_files:
            t1.add_row(str(fs.loc), fs.relpath)
        console.print(t1)

        t2 = Table(title="Top 10 Longest Functions (LOC)")
        t2.add_column("LOC", justify="right")
        t2.add_column("Function")
        t2.add_column("File")
        t2.add_column("Lines", justify="right")
        for fn in longest_funcs:
            t2.add_row(
                str(fn.loc),
                fn.func_name,
                fn.relpath,
                f"{fn.start_line}-{fn.end_line}",
            )
        console.print(t2)

        if violations:
            t3 = Table(title="Boundary Violations (core/)")
            t3.add_column("File")
            t3.add_column("Line", justify="right")
            t3.add_column("Issue")
            for v in violations:
                t3.add_row(v.relpath, str(v.line or ""), v.detail)
            console.print(t3)
            console.print("[bold red]Result:[/bold red] boundary violations found.")
        else:
            console.print(
                "[bold green]Result:[/bold green] no boundary violations found."
            )
        return

    # Plain text fallback
    print(f"Repo Doctor v1 -> wrote {report_path.as_posix()}")
    print("\nTop 10 Biggest Python Files (LOC)")
    for fs in biggest_files:
        print(f"  {fs.loc:>5}  {fs.relpath}")

    print("\nTop 10 Longest Functions (LOC)")
    for fn in longest_funcs:
        print(
            f"  {fn.loc:>5}  {fn.func_name}  {fn.relpath}:{fn.start_line}-{fn.end_line}"
        )

    if violations:
        print("\nBoundary Violations (core/)")
        for v in violations:
            line = v.line if v.line is not None else ""
            print(f"  {v.relpath}:{line}  {v.detail}")
        print("\nResult: boundary violations found.")
    else:
        print("\nResult: no boundary violations found.")


def main() -> int:
    try:
        root = _repo_root()
        py_files = list(iter_python_files(root))

        file_stats_all: list[FileStat] = []
        func_stats_all: list[FunctionStat] = []
        violations_all: list[Violation] = []

        for p in py_files:
            rel = p.relative_to(root).as_posix()
            text = safe_read_text(p)
            file_stats_all.append(FileStat(relpath=rel, loc=count_loc(text)))
            func_stats_all.extend(function_stats_from_file(p, rel))
            violations_all.extend(find_core_boundary_violations(p, rel))

        biggest_files = sorted(file_stats_all, key=lambda x: x.loc, reverse=True)[:10]
        longest_funcs = sorted(func_stats_all, key=lambda x: x.loc, reverse=True)[:10]

        reports_dir = ensure_reports_dir(root)
        report_path = reports_dir / "project_health.csv"
        write_csv(report_path, biggest_files, longest_funcs, violations_all)

        print_summary(biggest_files, longest_funcs, violations_all, report_path)

        return 2 if violations_all else 0
    except Exception as e:
        print(f"Repo Doctor failed: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
