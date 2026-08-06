# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

`aws-utils` is a small set of AWS credential and access helper shell functions for PDS engineers: importing pasted SSO console credentials, exporting a profile's credentials into the current shell, SSO login, checking the current caller identity, and SSM session connect. See the README for the full command list and workflow diagram.

## Architecture

### Shell functions, not a package

All five commands live in a single sourced file, `shell/aws-utils.sh`, as bash functions rather than a Python package or standalone scripts on `PATH`. This is a deliberate choice, not an oversight: `aws-creds-export` must `eval` into the caller's *current* shell to mutate its environment (set `AWS_ACCESS_KEY_ID` etc. in the interactive session), and a subprocess — which is all a standalone script or console_script entry point ever is — can only ever change its own environment, never its parent's. Since one of the five commands is forced to be a sourced function, all five are kept together for a single `source` line in `.bashrc`/`.zshrc`.

Do not port these to Python or split them into standalone executables; that would break `aws-creds-export`.

### Testing

There's no unit test suite — each function is a thin, directly-readable wrapper (a handful of lines, mostly a single `aws` CLI invocation), and the value of formal tests here is low relative to the overhead of a test harness. Lint with `shellcheck`:

```bash
shellcheck shell/aws-utils.sh
```

Manually smoke-test by sourcing the file and exercising each function, e.g.:

```bash
source shell/aws-utils.sh
printf '[test]\naws_access_key_id=X\naws_secret_access_key=Y\n' | aws-creds-import
```

### Secrets detection

```bash
scripts/detect_secrets_baseline.sh scan   # regenerate .secrets.baseline
scripts/detect_secrets_baseline.sh audit  # interactively review/classify detected secrets
scripts/detect_secrets_baseline.sh        # check for new secrets vs baseline (run by pre-commit)
```

Per-repo file exclusions go in `.detect-secrets-ignore` (one regex per line). Global exclusions (`.git`, `venv`, `dist`, etc.) are baked into the script.

### CI/CD

- **`branch-cicd.yaml`** — runs `shellcheck` against `shell/` on every non-`main` push.
- **`secrets-detection.yaml`** — runs `detect-secrets` against the baseline on push/PR to `main`.

There is no PyPI-publishing workflow — this repo has no Python package to publish. (The `unstable-cicd.yaml`/`stable-cicd.yaml`/`codeql-analysis.yml` workflows that ship with `template-repo-python` were removed for that reason.)
