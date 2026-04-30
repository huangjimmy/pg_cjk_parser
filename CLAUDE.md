# CLAUDE.md

## Git workflow

- Use `git worktree add <path> -b <branch>` for feature branches — never switch branches in the main working directory.
- No `Co-Authored-By` lines in commit messages.
- Activate the pre-commit hook once per clone: `git config core.hooksPath .githooks`
- Commit messages must have a title and a body. The body explains **what** changed and **why**.

## Bug reports and issue docs

- Write issue docs as markdown files under `issues/`.
- Prefix filenames with the date: `YYYY-MM-DD-bug-NNN-<short-description>.md`.

## Testing

- Add tests that actually run and reveal the bug — do not just infer correctness from reading code.
- Run the tests against the buggy code first to confirm they fail, then fix the bug and confirm they pass.
- Correctness before anything else (style, refactoring, etc.).
- The pre-commit hook also runs a compiler-warning lint pass (PG16 build). Zero warnings required.
