# brain-start

One command that sets up the AgenttiX 2nd brain on a Mac, for a new install or
an old one:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Agentti-X/brain-start/main/start.sh)
```

It asks whether you code, and sets up the code too if you do. `--code` or
`--memory` answers that in advance, and `--dry-run` shows what it would do.

This repository is public on purpose and holds nothing secret. The script
installs Homebrew, git, the GitHub CLI and Claude Code if they are missing,
signs you in to GitHub in the browser, and then runs the private installer from
`Agentti-X/2nd-brain-system` with your own login. Without membership of the
Agentti-X organisation it stops at that point.

Everything about the setup itself lives in the private repository: its
`README.md`, `bin/install.sh` and `ONBOARDING.md`.
