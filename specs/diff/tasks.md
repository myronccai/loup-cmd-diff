# Tasks: diff

- [x] 1. Parse GNU diff options: clusters, `-U NUM`, long options and prefixes, `--label`, `--`, operand count
  - _Requirements: 2.2, 2.3, 2.4, 2.5, 5.1, 5.2, 5.4_
- [x] 2. Split files into lines, build comparison keys for `-i`, `-w`, `-b`, and equivalence classes
  - _Requirements: 1.3, 3.1, 3.2, 3.3_
- [x] 3. Port GNU's analysis: identical ends, confusing-line discards, Myers middle-snake search, cost cut-off, `shift_boundaries`
  - _Requirements: 1.2_
- [x] 4. Normal and unified output, including the no-newline marker and hunk merging
  - _Requirements: 1.3, 2.1, 2.2, 2.4_
- [x] 5. Compare files: identical bytes, binary and non-UTF-8 files, `-q`, `-s`, standard input
  - _Requirements: 1.1, 1.4, 1.5, 3.4, 3.5_
- [x] 6. Compare directories, recursively with `-r`; file against directory
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
- [x] 7. Missing operands and usage errors with GNU messages and status 2
  - _Requirements: 5.2, 5.3_
- [x] 8. Unit tests and end-to-end tests of the native binary, checked against GNU diff
  - _Requirements: all_
