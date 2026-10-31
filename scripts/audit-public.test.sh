#!/usr/bin/env bash
# A repository goes public as one fresh commit, so whatever must stay private has
# to be absent from the tree, the messages and the identities before it is made,
# and again every time it is made. A one-off search was not enough: private issue
# numbers crept back within days. The real forbidden strings live outside every
# repository, so the fixtures here use harmless samples, and strings the audit
# hunts for are assembled at runtime so this file does not trip it.
set -uo pipefail

FAILED=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $*" >&2; FAILED=1; }

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
AUDIT="$REPO/scripts/audit-public.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.test
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.test

H='#'
USERS="/Us""ers/"
EMP="SAMPLE-""EMPLOYER"
emp="sample-""employer"
SECRET="SAMPLE-SECRET-""4242"
TEAM_ID="ABCDE""12345"

LIST="$TMP/forbidden.txt"
printf '# sample list\n\n%s\n' "$EMP" > "$LIST"

# A gitleaks stand-in that finds the sample secret, so the suite needs no gitleaks
# install. It takes the path as its last argument, as `gitleaks dir|git <path>` does.
FAKEBIN="$TMP/fakebin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/gitleaks" <<EOF
#!/bin/sh
mode=\$1; for a; do path=\$a; done
case \$mode in
  dir) grep -rIq --exclude-dir=.git "$SECRET" "\$path" && { echo "Finding: $SECRET"; exit 1; } ;;
  git) git -C "\$path" log -p --all | grep -q "$SECRET" && { echo "Finding: $SECRET in history"; exit 1; } ;;
esac
exit 0
EOF
chmod +x "$FAKEBIN/gitleaks"
# System tools only, so a real gitleaks on the host cannot answer for the fake.
BASEPATH="/usr/bin:/bin"

T="$TMP/template"
mkdir -p "$T"
git init -q -b main "$T"
git -C "$T" remote add origin https://github.com/Sample/fixture.git
printf 'Apache License\n' > "$T/LICENSE"
printf 'Fixture notice\n' > "$T/NOTICE"
printf '# Fixture\n\nSee [contributing](CONTRIBUTING.md) and [security](SECURITY.md).\n' > "$T/README.md"
printf 'How to contribute\n' > "$T/CONTRIBUTING.md"
printf 'How to report\n' > "$T/SECURITY.md"
printf 'ignored.txt\n' > "$T/.gitignore"
git -C "$T" add -A && git -C "$T" commit -qm "initial"

new_repo() { local d; d=$(mktemp -d "$TMP/r.XXXXXX"); cp -R "$T/." "$d"; echo "$d"; }

commit_file() { # repo path content
    mkdir -p "$(dirname "$1/$2")"
    printf '%s\n' "$3" > "$1/$2"
    git -C "$1" add -- "$2" && git -C "$1" commit -qm "add $2"
}

run_audit() { # dir [extra env assignments...]
    local dir=$1; shift
    OUT=$(cd "$TMP" && env VITHANCO_FORBIDDEN="$LIST" PATH="$FAKEBIN:$BASEPATH" "$@" "$AUDIT" "$dir" 2>&1)
    STATUS=$?
}

passes() { # name
    if [ "$STATUS" -eq 0 ]; then pass "$1"; else fail "$1: exit $STATUS: $OUT"; fi
}

fails_with() { # name extended-regex
    if [ "$STATUS" -ne 0 ] && grep -qiE -- "$2" <<<"$OUT"; then pass "$1"
    else fail "$1: exit $STATUS, wanted /$2/: $OUT"; fi
}

# The list

r=$(new_repo)
run_audit "$r" VITHANCO_FORBIDDEN= HOME="$TMP/nohome"
fails_with "Given no list file, when audited, then it fails saying the list is missing" "forbidden.*(missing|not found)|(missing|not found).*forbidden"

r=$(new_repo)
run_audit "$r"
passes "Given a list with a comment and a blank line, when the clean default is audited, then it passes"

mkdir -p "$TMP/plain"
printf 'x\n' > "$TMP/plain/README.md"
run_audit "$TMP/plain"
fails_with "Given a directory that is not a git repository, when audited, then it fails saying so" "not a git repository"

# Forbidden strings

r=$(new_repo)
commit_file "$r" docs/a.md $'first line\nworks for '"$emp"
run_audit "$r"
fails_with "Given a tracked file containing \"sample-employer\" in lower case, then it fails naming file:line" "docs/a\.md:2"

r=$(new_repo)
printf '%s\n' "$EMP" > "$r/ignored.txt"
run_audit "$r"
passes "Given the string only in an ignored, untracked file, then it passes"

r=$(new_repo)
git -C "$r" commit -q --allow-empty -m "for $EMP"
git -C "$r" commit -q --allow-empty -m "again $emp"
run_audit "$r"
fails_with "Given two commit messages containing the string, then it fails reporting 2 commits" "message.*2 commits"

r=$(new_repo)
GIT_AUTHOR_EMAIL=someone@$emp.test git -C "$r" commit -q --allow-empty -m one
GIT_AUTHOR_EMAIL=someone@$emp.test git -C "$r" commit -q --allow-empty -m two
run_audit "$r"
fails_with "Given two commits authored by an address at sample-employer.test, then it fails reporting 2 commits by author" "author.*2 commits"

r=$(new_repo)
GIT_COMMITTER_EMAIL=someone@$emp.test git -C "$r" commit -q --allow-empty -m one
run_audit "$r"
if [ "$STATUS" -ne 0 ] && grep -qiE "committer.*1 commit" <<<"$OUT" && ! grep -qiE "author.*1 commit" <<<"$OUT"; then
    pass "Given one commit whose committer, not author, has that address, then it fails reporting 1 commit by committer"
else
    fail "Given one commit whose committer, not author, has that address, then it fails reporting 1 commit by committer: exit $STATUS: $OUT"
fi

r=$(new_repo)
commit_file "$r" "docs/Why Sample.md" "$EMP"
run_audit "$r"
fails_with "Given a forbidden string in \"docs/Why Sample.md\", then the report names that path in full" "docs/Why Sample\.md:1"

# Always forbidden

r=$(new_repo)
commit_file "$r" notes.md "built in ${USERS}someone/src"
run_audit "$r"
fails_with "Given a tracked file containing a ${USERS}<name>/ path, then it fails naming file:line" "notes\.md:1"

r=$(new_repo)
commit_file "$r" sign.sh "ID=\"Developer ID Application: Sample Person (${TEAM_ID})\""
run_audit "$r"
fails_with "Given a signing identity \"Developer ID Application: Sample Person (${TEAM_ID})\", then it fails naming file:line" "sign\.sh:1"

r=$(new_repo)
commit_file "$r" sign.sh 'echo "set a Developer ID Application: identity first"'
run_audit "$r"
passes "Given \"Developer ID Application:\" with no team ID after it, then it passes"

# Issue numbers

r=$(new_repo)
commit_file "$r" Sources/a.swift "// keeps order (${H}232)"
run_audit "$r"
fails_with "Given \"(${H}232)\" in a comment, then it fails naming file:line" "Sources/a\.swift:1"

r=$(new_repo)
commit_file "$r" docs/b.md "For the background see ${H}7."
run_audit "$r"
fails_with "Given \"see ${H}7\" in a doc, then it fails naming file:line" "docs/b\.md:1"

r=$(new_repo)
commit_file "$r" docs/c.md "Fixed upstream in elementary-ui${H}85."
run_audit "$r"
passes "Given \"elementary-ui#85\", then it passes"

r=$(new_repo)
commit_file "$r" style.css $'a { color: #fff; }\nb { background: #5a564e; }'
run_audit "$r"
passes "Given colours \"#fff\" and \"#5a564e\", then it passes"

r=$(new_repo)
commit_file "$r" page.html "Tom &${H}38; Jerry"
run_audit "$r"
passes "Given the HTML entity \"&#38;\", then it passes"

r=$(new_repo)
commit_file "$r" page.css "${H}vg-editor-status { display: none; }"
run_audit "$r"
passes "Given a CSS id \"#vg-editor-status\", then it passes"

r=$(new_repo)
commit_file "$r" docs/example.vgl "node a \"Delivery is late (UDE ${H}1)\""
run_audit "$r"
passes "Given a counter \"(UDE #1)\", then it passes"

r=$(new_repo)
commit_file "$r" Tests/ColourTest.swift "let invalid = \"\\\"${H}12\\\"\""
run_audit "$r"
passes "Given a quoted \"#12\" in a test fixture, then it passes"

r=$(new_repo)
commit_file "$r" docs/adr/0001.md "Decided in OLD""-232."
run_audit "$r"
passes "Given \"OLD""-232\", then it passes"

r=$(new_repo)
commit_file "$r" docs/d.md "Context in https://github.com/Sample/fixture/issues/118 here."
run_audit "$r"
fails_with "Given a link to issue 118 of the repository's own origin, then it fails naming file:line" "docs/d\.md:1"

r=$(new_repo)
printf 'ab\0cd %s123 ef\0' "$H" > "$r/blob.bin"
git -C "$r" add blob.bin && git -C "$r" commit -qm blob
run_audit "$r"
passes "Given a binary file whose bytes contain \"#123\", then it passes"

r=$(new_repo)
commit_file "$r" docs/e.md "The indicator is ${H}808078 in light mode."
run_audit "$r"
passes "Given a six-digit colour \"#808078\" in prose, then it passes"

r=$(new_repo)
commit_file "$r" Sources/b.swift "/// Usually transparent (${H}00000000) for a boundary."
run_audit "$r"
passes "Given an eight-digit colour \"#00000000\", then it passes"

r=$(new_repo)
commit_file "$r" docs/f.md "so a bare \`${H}42\` may be either"
run_audit "$r"
passes "Given \"#42\" in backticks, then it passes"

# Required files

missing_ok=1
for f in LICENSE NOTICE README.md CONTRIBUTING.md SECURITY.md; do
    r=$(new_repo)
    git -C "$r" rm -q "$f" && git -C "$r" commit -qm "drop $f"
    run_audit "$r"
    if [ "$STATUS" -eq 0 ] || ! grep -qF -- "$f" <<<"$OUT"; then missing_ok=0; echo "  missing $f: exit $STATUS: $OUT" >&2; fi
done
if [ $missing_ok -eq 1 ]; then pass "Given any one of LICENSE, NOTICE, README.md, CONTRIBUTING.md, SECURITY.md missing, then it fails naming that file"
else fail "Given any one of LICENSE, NOTICE, README.md, CONTRIBUTING.md, SECURITY.md missing, then it fails naming that file"; fi

r=$(new_repo)
printf '\nRead the [guide](docs/missing.md).\n' >> "$r/README.md"
git -C "$r" commit -qam "link"
run_audit "$r"
fails_with "Given a README link to a missing local file, then it fails naming the link" "docs/missing\.md"

r=$(new_repo)
printf '\nSee [how](CONTRIBUTING.md#how) and [web](https://example.com/x).\n' >> "$r/README.md"
git -C "$r" commit -qam "links"
run_audit "$r"
passes "Given README links to an existing file with an #anchor and to an https URL, then it passes"

r=$(new_repo)
commit_file "$r" "docs/With Space.md" "policy"
printf '\nSee [policy](docs/With%%20Space.md).\n' >> "$r/SECURITY.md"
git -C "$r" commit -qam "link"
run_audit "$r"
passes "Given a SECURITY link to an existing path containing a space, then it passes"

# Size

r=$(new_repo)
head -c 600000 /dev/zero > "$r/big.bin"
git -C "$r" add big.bin && git -C "$r" commit -qm big
run_audit "$r"
if [ "$STATUS" -eq 0 ] && grep -qF "big.bin" <<<"$OUT"; then
    pass "Given a tracked file over 500 KB and nothing else wrong, then it lists the file and passes"
else
    fail "Given a tracked file over 500 KB and nothing else wrong, then it lists the file and passes: exit $STATUS: $OUT"
fi

# Secrets

r=$(new_repo)
commit_file "$r" config.env "TOKEN=$SECRET"
run_audit "$r"
fails_with "Given a sample secret in a tracked file, then it fails with the gitleaks finding" "Finding: $SECRET"

r=$(new_repo)
commit_file "$r" config.env "TOKEN=$SECRET"
git -C "$r" rm -q config.env && git -C "$r" commit -qm "remove"
run_audit "$r"
fails_with "Given a sample secret only in an earlier commit, since removed, then it fails" "Finding: $SECRET in history"

r=$(new_repo)
OUT=$(cd "$TMP" && env VITHANCO_FORBIDDEN="$LIST" PATH="$BASEPATH" "$AUDIT" "$r" 2>&1); STATUS=$?
fails_with "Given gitleaks not installed, then it fails saying so" "gitleaks.*(not installed|not found|missing)"

# Reporting

r=$(new_repo)
commit_file "$r" a.md "$EMP"
commit_file "$r" b.md "${USERS}someone"
git -C "$r" rm -q NOTICE && git -C "$r" commit -qm "drop NOTICE"
run_audit "$r"
if [ "$STATUS" -ne 0 ] && grep -qF "a.md:1" <<<"$OUT" && grep -qF "b.md:1" <<<"$OUT" && grep -qF "NOTICE" <<<"$OUT"; then
    pass "Given three different findings, then all three are reported in one run"
else
    fail "Given three different findings, then all three are reported in one run: exit $STATUS: $OUT"
fi

exit $FAILED
