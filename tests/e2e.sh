#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones.
#
# usage: tests/e2e.sh BINARY
#
# The cases run inside tests/fixtures so that file names in the expected
# output stay short; scratch files go in $TMP.

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$(dirname "$0")/fixtures" || exit 2
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... and compares standard error (and the exit status).
check_err() {
    local name=$1 want_status=$2 want=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > /dev/null 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ "$(cat "$TMP/err")" == "$want" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# --- normal output ---------------------------------------------------------

check "normal" 1 '1c1
< # Packing list
---
> # Packing list (weekend)
6d5
< lighter
13a13
> sun hat
' old.txt new.txt

check "identical files"   0 '' old.txt old.txt
printf 'a\nb\nc\n' > "$TMP/abc"
printf 'b\nc\nd\n' > "$TMP/bcd"
: > "$TMP/empty"
check "--normal"          1 $'1d0\n< a\n3a3\n> d\n' --normal "$TMP/abc" "$TMP/bcd"
check "delete then add"   1 $'1d0\n< a\n3a3\n> d\n' "$TMP/abc" "$TMP/bcd"
check "from empty file"   1 $'0a1,3\n> a\n> b\n> c\n' "$TMP/empty" "$TMP/abc"
check "to empty file"     1 $'1,3d0\n< a\n< b\n< c\n' "$TMP/abc" "$TMP/empty"

printf 'x\ny' > "$TMP/noeol"
printf 'x\ny\n' > "$TMP/eol"
check "no newline at end" 1 $'2c2\n< y\n\\ No newline at end of file\n---\n> y\n' "$TMP/noeol" "$TMP/eol"

# --- unified output --------------------------------------------------------

check "-u" 1 '--- old.txt
+++ new.txt
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
' -u old.txt new.txt

check "-U 1" 1 '--- old.txt
+++ new.txt
@@ -1,2 +1,2 @@
-# Packing list
+# Packing list (weekend)
 tent
@@ -5,3 +5,2 @@
 fuel
-lighter
 water filter
@@ -13 +12,2 @@
 rain jacket
+sun hat
' -U 1 old.txt new.txt

check "-U0 and labels" 1 '--- before
+++ after
@@ -1 +1 @@
-# Packing list
+# Packing list (weekend)
@@ -6 +5,0 @@
-lighter
@@ -13,0 +13 @@
+sun hat
' -U0 --label before --label=after old.txt new.txt

check "--unified=2"       1 $'--- abc\n+++ bcd\n@@ -1,3 +1,3 @@\n-a\n b\n c\n+d\n' \
    --unified=2 --label abc --label bcd "$TMP/abc" "$TMP/bcd"
check "-u empty file"     1 $'--- e\n+++ abc\n@@ -0,0 +1,3 @@\n+a\n+b\n+c\n' \
    -u --label e --label abc "$TMP/empty" "$TMP/abc"
check "-u no newline"     1 $'--- a\n+++ b\n@@ -1,2 +1,2 @@\n x\n-y\n\\ No newline at end of file\n+y\n' \
    -u --label a --label b "$TMP/noeol" "$TMP/eol"
check "-u largest -U wins" 1 $'--- a\n+++ b\n@@ -1,3 +1,3 @@\n-a\n b\n c\n+d\n' \
    -U 1 -u --label a --label b "$TMP/abc" "$TMP/bcd"

# --- comparison options ----------------------------------------------------

printf 'Hello World\nsame\n' > "$TMP/case1"
printf 'hello world\nsame\n' > "$TMP/case2"
check "case differs"      1 $'1c1\n< Hello World\n---\n> hello world\n' "$TMP/case1" "$TMP/case2"
check "-i"                0 '' -i "$TMP/case1" "$TMP/case2"

printf 'if (x)  {\n\treturn 1;\n}\n' > "$TMP/space1"
printf 'if (x) {\n    return 1;  \n}\n' > "$TMP/space2"
printf 'if(x){\nreturn 1;\n}\n' > "$TMP/space3"
check "-b"                0 '' -b "$TMP/space1" "$TMP/space2"
check "-b keeps space vs none" 1 $'1,2c1,2\n< if (x)  {\n< \treturn 1;\n---\n> if(x){\n> return 1;\n' \
    -b "$TMP/space1" "$TMP/space3"
check "-w"                0 '' -w "$TMP/space1" "$TMP/space3"
check "-w no newline"     0 '' -w "$TMP/noeol" "$TMP/eol"
check "--ignore-case abbreviated" 0 '' --ignore-c "$TMP/case1" "$TMP/case2"

check "-q"                1 'Files old.txt and new.txt differ
' -q old.txt new.txt
check "-q same"           0 '' -q old.txt old.txt
check "-s"                0 'Files old.txt and old.txt are identical
' -s old.txt old.txt
check "-s -b"             0 "Files $TMP/space1 and $TMP/space2 are identical
" -s -b "$TMP/space1" "$TMP/space2"

printf 'a\0b\n' > "$TMP/bin1"
printf 'a\0c\n' > "$TMP/bin2"
printf 'caf\351\n' > "$TMP/latin1"
check "binary"            1 "Binary files $TMP/bin1 and $TMP/bin2 differ
" "$TMP/bin1" "$TMP/bin2"
check "binary -q"         1 "Files $TMP/bin1 and $TMP/bin2 differ
" -q "$TMP/bin1" "$TMP/bin2"
check "binary same"       0 '' "$TMP/bin1" "$TMP/bin1"
check "not UTF-8"         1 "Binary files $TMP/latin1 and $TMP/abc differ
" "$TMP/latin1" "$TMP/abc"

# --- standard input --------------------------------------------------------

IN="$TMP/bcd" check "stdin first"  1 $'0a1\n> a\n3d3\n< d\n' - "$TMP/abc"
IN="$TMP/bcd" check "stdin second" 1 $'--- abc\n+++ -\n@@ -1,3 +1,3 @@\n-a\n b\n c\n+d\n' \
    -u --label abc "$TMP/abc" -
IN="$TMP/abc" check "stdin both"   0 'Files - and - are identical
' -s - -

# --- directories -----------------------------------------------------------

check "directories" 1 'Files tree1/changed.txt and tree2/changed.txt differ
File tree1/kind is a regular file while file tree2/kind is a directory
Only in tree1: left.txt
Only in tree2: right.txt
Common subdirectories: tree1/sub and tree2/sub
' -q tree1 tree2

check "-r" 1 'diff -r tree1/changed.txt tree2/changed.txt
2c2
< two
---
> 2
File tree1/kind is a regular file while file tree2/kind is a directory
Only in tree1: left.txt
Only in tree2: right.txt
diff -r tree1/sub/inner.txt tree2/sub/inner.txt
1c1
< inner
---
> inner, changed
' -r tree1 tree2

check "-r -U 0 -s" 1 'diff -r -U 0 -s tree1/changed.txt tree2/changed.txt
--- tree1/changed.txt
+++ tree2/changed.txt
@@ -2 +2 @@
-two
+2
File tree1/kind is a regular file while file tree2/kind is a directory
Only in tree1: left.txt
Only in tree2: right.txt
Files tree1/same.txt and tree2/same.txt are identical
diff -r -U 0 -s tree1/sub/inner.txt tree2/sub/inner.txt
--- tree1/sub/inner.txt
+++ tree2/sub/inner.txt
@@ -1 +1 @@
-inner
+inner, changed
' -r -U 0 -s tree1 tree2

check "-qr trailing slash" 1 'Files tree1/changed.txt and tree2/changed.txt differ
File tree1/kind is a regular file while file tree2/kind is a directory
Only in tree1/: left.txt
Only in tree2: right.txt
Files tree1/sub/inner.txt and tree2/sub/inner.txt differ
' -qr tree1/ tree2
check "same directory"    0 '' -r tree1 tree1
check "file and directory" 1 $'2c2\n< two\n---\n> 2\n' tree1/changed.txt tree2
check "directory and file" 1 $'1c1\n< inner\n---\n> inner, changed\n' tree1/sub tree2/sub/inner.txt

# --- errors and usage ------------------------------------------------------

check_err "missing file"      2 'diff: nope.txt: No such file or directory' nope.txt old.txt
check_err "missing in dir"    2 'diff: tree1/new.txt: No such file or directory' new.txt tree1
check_err "stdin and dir"     2 "diff: cannot compare '-' to a directory" - tree1
check_err "missing operand"   2 "diff: missing operand after 'old.txt'
diff: Try 'diff --help' for more information." old.txt
check_err "no operands"       2 "diff: missing operand after 'diff'
diff: Try 'diff --help' for more information."
check_err "extra operand"     2 "diff: extra operand 'x'
diff: Try 'diff --help' for more information." old.txt new.txt x
check_err "invalid option"    2 "diff: invalid option -- 'k'
diff: Try 'diff --help' for more information." -uk old.txt new.txt
check_err "unknown long"      2 "diff: unrecognized option '--frob'
diff: Try 'diff --help' for more information." --frob old.txt new.txt
check_err "ambiguous long"    2 "diff: option '--re' is ambiguous; possibilities: '--recursive' '--report-identical-files'
diff: Try 'diff --help' for more information." --re tree1 tree2
check_err "bad context"       2 "diff: invalid context length 'x'
diff: Try 'diff --help' for more information." -U x old.txt new.txt
check_err "-U needs value"    2 "diff: option requires an argument -- 'U'
diff: Try 'diff --help' for more information." old.txt new.txt -U
check_err "style conflict"    2 "diff: conflicting output style options
diff: Try 'diff --help' for more information." -u --normal old.txt new.txt
check_err "flag with value"   2 "diff: option '--brief' doesn't allow an argument
diff: Try 'diff --help' for more information." --brief=yes old.txt new.txt
check "options after operands" 1 'Files old.txt and new.txt differ
' old.txt new.txt -q
check "double dash"       1 $'1d0\n< a\n3a3\n> d\n' -- "$TMP/abc" "$TMP/bcd"
check "version"           0 $'diff (loup-cmd-diff) 0.1.0\n' --version

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
