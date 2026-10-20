# Requirements: diff

## Introduction

`diff` compares two files line by line and prints the lines that differ, or
compares two directories entry by entry. This repository recreates the core
of GNU diffutils `diff` in Loup: normal and unified output, the
white-space and case options, brief and identical-file reports, and
recursive directory comparison, with GNU's exit statuses. It is one of the
Linux text tools in the loup-cmd series.

## Requirements

### Requirement 1: Comparing two files

**User Story:** As a developer, I want to see which lines changed between
two versions of a file so that I can review or apply the change.

#### Acceptance Criteria

1. WHEN the two files are byte-for-byte the same, THE program SHALL print
   nothing and exit with status 0.
2. WHEN the files differ, THE program SHALL print a minimal set of changes
   and exit with status 1, choosing the same hunks as GNU diff for the same
   input.
3. WHEN a file does not end with a newline and its last line is printed,
   THE program SHALL follow it with `\ No newline at end of file`.
4. WHEN an operand is `-`, THE program SHALL read standard input; when both
   are `-`, THE program SHALL treat them as the same file.
5. WHEN either file contains a NUL byte or is not valid UTF-8, THE program
   SHALL print `Binary files A and B differ` if the bytes differ.

### Requirement 2: Output formats

**User Story:** As a developer, I want GNU's output formats so that tools
such as `patch` and code review can read them.

#### Acceptance Criteria

1. THE program SHALL print the normal format by default: `LaR`, `RcR`, `RdL`
   commands followed by `< ` and `> ` lines separated by `---`.
2. WHEN `-u`, `-U NUM` or `--unified[=NUM]` is given, THE program SHALL print
   unified format: `--- A` and `+++ B` headers and `@@ -l,s +l,s @@` hunks
   with NUM (default 3) lines of context, merging hunks closer than
   2 × NUM + 1 lines.
3. WHEN several context lengths are given, THE program SHALL use the largest.
4. WHEN `--label LABEL` is given once or twice, THE program SHALL use the
   labels in the unified headers instead of the file names.
5. WHEN `--normal` and a unified option are both given, THE program SHALL
   report `conflicting output style options`.

### Requirement 3: Comparison options

**User Story:** As a developer, I want to ignore differences that do not
matter so that the output shows only real changes.

#### Acceptance Criteria

1. WHEN `-i` is given, THE program SHALL treat upper and lower case as equal.
2. WHEN `-b` is given, THE program SHALL treat any run of white space as
   equal to any other and ignore white space (including a missing final
   newline) at the end of a line.
3. WHEN `-w` is given, THE program SHALL ignore all white space.
4. WHEN `-q` is given and the inputs differ, THE program SHALL print only
   `Files A and B differ`.
5. WHEN `-s` is given and two files are the same, THE program SHALL print
   `Files A and B are identical`.

### Requirement 4: Directories

**User Story:** As a developer, I want to compare two directory trees so
that I can see every file that was added, removed or changed.

#### Acceptance Criteria

1. WHEN both operands are directories, THE program SHALL compare the entries
   with the same name in name order and print `Only in DIR: NAME` for
   entries found on one side only.
2. WHEN a pair of files differs inside a directory comparison, THE program
   SHALL introduce its output with `diff OPTIONS A B`.
3. WHEN both entries are directories, THE program SHALL print
   `Common subdirectories: A and B`, or compare them recursively under `-r`.
4. WHEN one entry is a directory and the other a file, THE program SHALL
   print `File A is a directory while file B is a regular file` (or the
   reverse).
5. WHEN one operand is a file and the other a directory, THE program SHALL
   compare the file with the directory's entry of the same name.

### Requirement 5: Command line and exit statuses

**User Story:** As a script author, I want GNU's option syntax and exit
statuses so that existing scripts keep working.

#### Acceptance Criteria

1. THE program SHALL accept combined short options (`-ru`, `-U3`), options
   after the operands, `--` to end options, and long options abbreviated to
   a unique prefix.
2. WHEN an option is unknown, ambiguous, missing its value or has a bad
   value, or the number of operands is not two, THE program SHALL print GNU's
   message and `diff: Try 'diff --help' for more information.` on standard
   error and exit with status 2.
3. WHEN an operand does not exist, THE program SHALL print
   `diff: NAME: No such file or directory` and exit with status 2.
4. WHEN `--help` or `--version` is given, THE program SHALL print the help
   text or `diff (loup-cmd-diff) 0.1.0` and exit with status 0.
