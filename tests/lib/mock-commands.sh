#!/usr/bin/env bash
# Mock external commands via PATH prepend.
# Each mock logs its invocation to a .calls file for verification.

ORIGINAL_PATH=""

# setup_mock_path <tmpdir>
# Creates a mock bin directory and prepends it to PATH.
setup_mock_path() {
  local tmpdir="$1"
  local mock_bin="$tmpdir/mock-bin"
  mkdir -p "$mock_bin"
  ORIGINAL_PATH="$PATH"
  export PATH="$mock_bin:$PATH"
  echo "$mock_bin"
}

# restore_path
restore_path() {
  if [ -n "$ORIGINAL_PATH" ]; then
    export PATH="$ORIGINAL_PATH"
    ORIGINAL_PATH=""
  fi
}

# create_mock_git <mock_bin_dir> [behavior]
# Behaviors: "clean" (default), "dirty", "has-lessons"
create_mock_git() {
  local mock_bin="$1"
  local behavior="${2:-clean}"
  cat > "$mock_bin/git" << MOCKEOF
#!/usr/bin/env bash
echo "git \$*" >> "$mock_bin/git.calls"
case "\$1" in
  rev-parse)
    case "\$2" in
      --git-dir) echo ".git" ;;
      --abbrev-ref) echo "master" ;;
      --show-toplevel) echo "/tmp/test-project" ;;
      HEAD) echo "abc1234" ;;
    esac
    ;;
  remote)
    echo "https://github.com/test/repo.git"
    ;;
  log)
    echo "feat: test commit message"
    ;;
  diff)
    case "$behavior" in
      has-lessons)
        echo "+- New lesson learned"
        echo "+- Another lesson"
        ;;
      *) echo "" ;;
    esac
    ;;
  status)
    case "$behavior" in
      dirty) echo " M src/test.ts" ;;
      *) echo "" ;;
    esac
    ;;
  -C)
    shift  # consume -C flag
    shift  # consume directory argument
    case "\$1" in
      log) echo "feat: test commit" ;;
      diff)
        case "$behavior" in
          has-lessons)
            echo "+- New lesson"
            ;;
          *) echo "" ;;
        esac
        ;;
      rev-list) echo "0" ;;
      check-ignore) exit 1 ;;
      *) echo "" ;;
    esac
    ;;
  *) echo "" ;;
esac
MOCKEOF
  chmod +x "$mock_bin/git"
}

# create_mock_gh <mock_bin_dir> [ci_status]
# ci_status: "success" (default), "failure"
create_mock_gh() {
  local mock_bin="$1"
  local ci_status="${2:-success}"
  cat > "$mock_bin/gh" << MOCKEOF
#!/usr/bin/env bash
echo "gh \$*" >> "$mock_bin/gh.calls"
case "\$1" in
  run)
    case "$ci_status" in
      failure) echo '[{"status":"completed","conclusion":"failure","name":"CI"}]' ;;
      *) echo '[{"status":"completed","conclusion":"success","name":"CI"}]' ;;
    esac
    ;;
  pr)
    echo '[]'
    ;;
  *)
    echo '[]'
    ;;
esac
MOCKEOF
  chmod +x "$mock_bin/gh"
}

# hide_command <mock_bin_dir> <command_name>
# Creates a stub that exits 127 (simulates command not found).
hide_command() {
  local mock_bin="$1" cmd="$2"
  cat > "$mock_bin/$cmd" << 'MOCKEOF'
#!/usr/bin/env bash
exit 127
MOCKEOF
  chmod +x "$mock_bin/$cmd"
}

# get_mock_calls <mock_bin_dir> <command_name>
# Returns the call log for a mocked command.
get_mock_calls() {
  local mock_bin="$1" cmd="$2"
  cat "$mock_bin/${cmd}.calls" 2>/dev/null || echo ""
}

# create_mock_date <mock_bin_dir> <day_of_year>
# Creates a mock date that returns a specific day-of-year for +%j,
# but passes through to real date for all other formats.
create_mock_date() {
  local mock_bin="$1"
  local day_of_year="$2"
  local real_date
  real_date=$(which date 2>/dev/null || echo "/usr/bin/date")
  cat > "$mock_bin/date" << MOCKEOF
#!/usr/bin/env bash
echo "date \$*" >> "$mock_bin/date.calls"
for arg in "\$@"; do
  if [ "\$arg" = "+%j" ]; then
    echo "$day_of_year"
    exit 0
  fi
done
# Pass through to real date for other formats
"$real_date" "\$@"
MOCKEOF
  chmod +x "$mock_bin/date"
}
