# Design: diff

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the arguments
into `Options`, handles `--help` and `--version`, and calls
`commands.diff.run_diff`. `diff_paths` resolves the operands and fills a
`Report` (output pieces, error lines, status); `run_diff` prints it. Every
step below `run_diff` returns values, so the tests need no output capture.

## Modules

| Module | Contents |
|---|---|
| `source/cli/args.loup` | `Options`, `parse_args` (GNU getopt_long rules: clusters, permutation, unique prefixes, `--`), `parse_count`, `resolve_long` |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run()`: usage errors and exceptions give status 2 |
| `source/commands/diff.loup` | `diff_paths` (missing operands, file vs directory, `-`), `run_diff` |
| `source/commands/compare.loup` | `Report`, `compare_files`, `compare_dirs`, `is_binary`, `is_utf8`, `changes_between` |
| `source/engine/lines.loup` | `Text` (lines and the missing-newline flag), `Ignore`, `line_key`, `classify` |
| `source/engine/myers.loup` | `Change`, `diff_sequences`, `shift_boundaries` |
| `source/engine/format.loup` | `normal_output`, `unified_output`, range formatting |

## The algorithm

Lines are first reduced to keys (`line_key`: lower-cased for `-i`, white
space removed for `-w` or collapsed for `-b`; a final line without a newline
gets a different key unless `-w` or `-b` is on), and equal keys share an
equivalence-class number (`classify`). `diff_sequences` then follows GNU
diff's `analyze.c` and gnulib's `diffseq.h`:

1. Strip the lines the files share exactly (byte for byte) at the start and
   end, keeping `horizon` lines of each (the unified context), as GNU's
   `find_identical_ends` does.
2. `discard_marks` / `settle_marks`: lines with no match in the other file
   are changes for certain, and runs of lines with very many matches are
   left out of the search (`discard_confusing_lines`).
3. `Analysis.compareseq` and `Analysis.diag`: the linear-space Myers search.
   Forward and backward searches extend one edit at a time over the
   diagonals (`fd`, `bd`) until they meet in a middle snake; the problem is
   split there and solved recursively. After `too_expensive` steps
   (about the square root of the input size, at least 4096) the search
   settles for a good split instead of a minimal one, as GNU does.
4. `shift_boundaries`: slide each run of changes down as far as possible,
   or back to line up with a run of changes in the other file.
5. `build_script`: collect the runs into `Change` values.

Formatting walks the changes. Unified hunks join changes separated by fewer
than 2 × context + 1 unchanged lines; context lines are printed from the
first file.

## Differences from the original

- Unified headers show no timestamps: Loup 1.26 has no `stat()` (roadmap
  constraint T1). The header is what GNU prints with `--label`.
- A file that is not valid UTF-8 is treated as binary, because Loup strings
  are Unicode text (GNU only looks for NUL bytes).
- `-i` uses `toLowerCase`, which folds non-ASCII letters too.
- Directory entries are sorted by byte order, not the locale's collation.
- Only the options listed in the README exist; GNU's ambiguous-option
  message therefore lists fewer candidates.
- An unreadable file aborts with Loup's `IoError` and status 1 (native
  builds cannot catch it); a missing file is reported normally.
- `--version` prints one line.

## Error handling

Usage errors return `Err(message)` from `parse_args`; `run` prints the
message and the `Try` line and returns 2. Missing operands are checked with
`exists()` before reading, because a native build cannot catch `IoError`.
Any other exception is printed as `diff: MESSAGE` with status 2.

## Native-build workarounds

- Each struct is constructed only in its defining module (`make_ignore`,
  `new_report`): Loup 1.26 native builds corrupt a struct built elsewhere.
- No escapes inside `i"..."` strings (they are not decoded natively).
- `bytes` are indexed, not iterated with `for`.

## Testing

- `tests/args_test.loup`: clusters, permutation, context rules, labels,
  prefixes, every usage error.
- `tests/lines_test.loup`: splitting, keys under `-i`/`-w`/`-b`, classes.
- `tests/myers_test.loup`: edit scripts, minimality (Myers' ABCABBA example),
  where insertions land, `shift_boundaries`, the exact prefix.
- `tests/format_test.loup`: ranges, normal commands, the no-newline marker,
  hunk merging and splitting, empty files.
- `tests/compare_test.loup`: options through `changes_between`, paths,
  binary checks, file and directory reports.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: 55 cases against the native binary (formats, options,
  stdin, binary files, directory trees, error messages and statuses). The
  expected outputs were checked against GNU diffutils 3.10, and during
  development thousands of random file pairs gave output identical to GNU
  diff in normal, unified, `-i`, `-b`, `-w`, `-q` and `-s` modes.
