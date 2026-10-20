# AGENTS.md

This repository recreates GNU `diff` in the Loup programming language, as part
of the loup-cmd series of example applications: line-by-line comparison with
the Myers O(ND) algorithm (ported step by step from GNU diffutils), normal and
unified output, and recursive directory comparison. The program is `host.dual`
Loup built as a native executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses (0 same, 1 differ, 2 trouble)
│   ├── cli/
│   │   ├── args.loup            # struct Options, parse_args(): GNU getopt_long rules
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, --help/--version, run_diff, exit status
│   ├── commands/
│   │   ├── diff.loup            # diff_paths(): resolve operands; run_diff(): print the report
│   │   └── compare.loup         # Report, compare_files(), compare_dirs(), binary/UTF-8 checks
│   └── engine/
│       ├── lines.loup           # Text, Ignore, split_text(), line_key(), classify()
│       ├── myers.loup           # Change, diff_sequences(): GNU's analyze.c + diffseq.h
│       └── format.loup          # normal_output(), unified_output()
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   ├── e2e.sh                   # end-to-end tests of the native binary
│   └── fixtures/                # old.txt, new.txt, tree1/, tree2/
├── specs/diff/                  # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="-u tests/fixtures/old.txt tests/fixtures/new.txt"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup` |
| Run matching tests | `make test TEST_ARGS="--filter unified"` | tests whose name contains `unified` |
| Run one test file | `make test TEST_ARGS="--file tests/args_test.loup"` | |
| Build | `make build` | native binary at `build/diff` |
| Run the binary | `build/diff --help` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/diff`: output compared byte for byte |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/diff --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

## Making a change

1. Update the spec in `specs/diff/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/diff/tasks.md`.

Keep behaviour in pure functions that return values (`diff_paths` returns a
`Report` with the output pieces, error lines and status) so unit tests can
check it; only `run_diff` prints. Unit tests run from the repository root, so
they open fixtures as `tests/fixtures/...`.

`source/engine/myers.loup` mirrors GNU diff's `analyze.c` and gnulib's
`diffseq.h` function by function. Keep it that way: the hunks match GNU's
only because every heuristic (discarding confusing lines, the
`too_expensive` cut-off, `shift_boundaries`) is reproduced. Check a change
against GNU diff on many random inputs, not only the tests.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Struct fields read from another module must be `pub`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`); use
  `len() == 0`.
- Native-build pitfalls this code works around: construct a struct only in
  the module that defines it (hence `make_ignore`, `new_report`); do not put
  escapes such as `\n` inside `i"..."` (write `i"..." + "\n"`); index
  `bytes` (`data[k]`) instead of iterating them with `for`; `IoError` cannot
  be caught, so check `exists()` before reading.
- Struct fields that are assigned after construction must be `pub var`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
