# loup-cmd-diff

GNU `diff` recreated in [Loup](https://code-craft.ai/references/loup): compare
files line by line with the Myers O(ND) algorithm, in normal or unified
format, and compare directory trees.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

The diff engine follows GNU diffutils step by step (common prefix and suffix,
discarding lines that match nothing, the linear-space middle-snake search,
GNU's cost cut-off for very different files, and `shift_boundaries`), so for
the same options it chooses the same hunks as GNU diff.

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                 # native binary: build/diff
make ci                    # check, unit tests, build, end-to-end tests
make run ARGS="-u tests/fixtures/old.txt tests/fixtures/new.txt"   # run from source
```

```text
$ build/diff tests/fixtures/old.txt tests/fixtures/new.txt
1c1
< # Packing list
---
> # Packing list (weekend)
6d5
< lighter
13a13
> sun hat
$ build/diff -u tests/fixtures/old.txt tests/fixtures/new.txt
--- tests/fixtures/old.txt
+++ tests/fixtures/new.txt
@@ -1,9 +1,8 @@
-# Packing list
+# Packing list (weekend)
 tent
 sleeping bag
 stove
 fuel
-lighter
 water filter
 first aid kit
 map
@@ -11,3 +10,4 @@
 headlamp
 spare batteries
 rain jacket
+sun hat
$ build/diff -r tests/fixtures/tree1 tests/fixtures/tree2
diff -r tests/fixtures/tree1/changed.txt tests/fixtures/tree2/changed.txt
2c2
< two
---
> 2
File tests/fixtures/tree1/kind is a regular file while file tests/fixtures/tree2/kind is a directory
Only in tests/fixtures/tree1: left.txt
Only in tests/fixtures/tree2: right.txt
diff -r tests/fixtures/tree1/sub/inner.txt tests/fixtures/tree2/sub/inner.txt
1c1
< inner
---
> inner, changed
$ build/diff -q tests/fixtures/tree1 tests/fixtures/tree2
Files tests/fixtures/tree1/changed.txt and tests/fixtures/tree2/changed.txt differ
File tests/fixtures/tree1/kind is a regular file while file tests/fixtures/tree2/kind is a directory
Only in tests/fixtures/tree1: left.txt
Only in tests/fixtures/tree2: right.txt
Common subdirectories: tests/fixtures/tree1/sub and tests/fixtures/tree2/sub
$ printf 'Hello  World\n' | build/diff -i -b - <(echo 'hello world'); echo "status $?"
status 0
$ build/diff missing.txt old.txt; echo "status $?"
diff: missing.txt: No such file or directory
diff: old.txt: No such file or directory
status 2
```

`diff [OPTION]... FILE1 FILE2`, where the operands are two files, two
directories, or a file and a directory (the file is compared with the
directory's entry of the same name). `-` reads standard input.

| Option | Meaning |
|---|---|
| `-u`, `-U NUM`, `--unified[=NUM]` | unified output with NUM (default 3) lines of context |
| `--normal` | normal output (the default) |
| `--label LABEL` | name shown in the `---`/`+++` header (give it twice for both files) |
| `-q`, `--brief` | only say whether the files differ |
| `-s`, `--report-identical-files` | say when two files are the same |
| `-i`, `--ignore-case` | ignore case differences |
| `-b`, `--ignore-space-change` | treat runs of white space as equal; ignore trailing white space |
| `-w`, `--ignore-all-space` | ignore all white space |
| `-r`, `--recursive` | compare subdirectories recursively |
| `--help`, `--version` | print help or the version and exit |

Short options combine (`-ru`, `-U3`), options may follow the operands, long
options may be abbreviated to a unique prefix (`--rec`), and `--` ends the
options.

Exit status: `0` if the inputs are the same, `1` if they differ, `2` on
trouble (a missing file, a usage error).

## Differences from the original

- **No timestamps in unified headers.** Loup 1.26 has no `stat()`, so the
  `---`/`+++` lines show only the file name (`--- old.txt`), exactly as GNU
  prints them when `--label` is given. `patch` accepts either form.
- **Files must be UTF-8 text.** A file with a NUL byte is binary, as in GNU
  diff; a file that is not valid UTF-8 is also reported as binary
  (`Binary files A and B differ`), because Loup strings are Unicode text and
  invalid bytes cannot be printed back unchanged.
- `-i` folds case with Loup's `toLowerCase`, which also folds non-ASCII
  letters (GNU folds single bytes only).
- Directory entries are listed in byte order (GNU uses the locale's
  collation; the two agree in the C locale).
- Only the options in the table above exist. Other GNU options (`-c`, `-y`,
  `-N`, `-x`, `--color`, ...) are usage errors, and an ambiguous long option
  lists only these options. `too many file label options` also prints the
  `Try 'diff --help'` line.
- Each input is read whole. An unreadable (as opposed to missing) file
  aborts the run with Loup's own `IoError` message and status 1, because a
  native Loup 1.26 build cannot catch that exception.
- `--version` prints a single line.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/args.loup          # GNU getopt-style option parsing
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, help/version, run_diff, exit status
source/commands/diff.loup     # operands (files, directories, stdin), printing
source/commands/compare.loup  # comparing two files or two directories
source/engine/lines.loup      # lines, comparison keys, equivalence classes
source/engine/myers.loup      # the Myers O(ND) algorithm, as in GNU diff
source/engine/format.loup     # normal and unified output
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests of build/diff (make e2e)
tests/fixtures/               # files and directory trees the tests compare
specs/diff/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
