#!/bin/bash

# Public function using system git
cherry_pick_n_commit() {
  __do_cherry_pick_n_commit git -- "$@"
}

# Public function using dotfiles git setup
dotfiles_cherry_pick_n_commit() {
  __do_cherry_pick_n_commit /usr/bin/git --git-dir="$HOME/dotfiles/" --work-tree="$HOME" -- "$@"
}

# Internal helper that accepts the git command to use, separated by `--`
__do_cherry_pick_n_commit() {
  local git_cmd=()
  while [[ "$1" != "--" ]]; do
    git_cmd+=("$1")
    shift
  done
  shift  # remove the --

  local source_branch="$1"
  local num_commits="$2"

  echo "[INFO] git_cmd '${git_cmd[*]}'"
  echo "[INFO] source_branch '$source_branch'"
  echo "[INFO] num_commits '$num_commits'"

  if [[ -z "$source_branch" || -z "$num_commits" ]]; then
    echo "Usage: <function> <source_branch> <number_of_commits>"
    return 1
  fi

  echo "[INFO] Fetching branch '$source_branch'..."
  "${git_cmd[@]}" fetch origin "$source_branch" >/dev/null 2>&1

  if ! "${git_cmd[@]}" rev-parse --verify --quiet "$source_branch" >/dev/null; then
    echo "[ERROR] Branch '$source_branch' not found after fetch."
    return 1
  fi

  echo "[INFO] Getting the latest $num_commits commit(s) from '$source_branch'..."
  local commits
  eval "${git_cmd[@]} log '$source_branch' -n '$num_commits' --oneline"
  commits=$("${git_cmd[@]}" log "$source_branch" -n "$num_commits" --format="%H")

  if [[ -z "$commits" ]]; then
    echo "[WARN] No commits found on branch '$source_branch'"
    return 0
  fi

  echo "[INFO] Starting cherry-pick..."

  echo "$commits" | tail -r | while read -r commit; do
    if "${git_cmd[@]}" cherry -v HEAD "$commit" | grep -q "^+"; then
      echo "[SKIP] Commit $commit already applied. Skipping."
    else
      echo "[PICK] Cherry-picking $commit..."
      if "${git_cmd[@]}" cherry-pick "$commit"; then
        echo "[OK] Successfully cherry-picked $commit"
      else
        echo "[FAIL] Conflict during cherry-pick of $commit. Resolve manually."
        return 1
      fi
    fi
  done

  echo "[DONE] Cherry-picking complete."
}
