#!/bin/bash
# AgenttiX 2nd brain: one command on a Mac, for a new install or an old one.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/Agentti-X/brain-start/main/start.sh)
#
# Public on purpose; nothing in it is secret. It installs the basics, signs you
# in to GitHub, and then runs the private installer from
# Agentti-X/2nd-brain-system with your own login, so it only gets further for
# members of the Agentti-X organisation. Safe to run again at any time.
#
# It asks whether you code; these answer in advance:
#   --code      also set up the code (agenttix-root and its apps), without asking
#   --memory    memory only, without asking
#   --dry-run   say what would happen, change nothing

set -uo pipefail
KIT=Agentti-X/2nd-brain-system
AREA="$HOME/_MEMORY/autoagentti"
CODE=""; DRY=0
for a in "$@"; do
  case "$a" in
    --code) CODE=1 ;; --memory) CODE=0 ;; --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a (try --help)" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  have     %s\n' "$*"; }
did()  { printf '  done     %s\n' "$*"; }
note() { printf '  note     %s\n' "$*"; }
die()  { printf '\n  STOPPED  %s\n\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
run()  { if [ "$DRY" = 1 ]; then printf '  would    %s\n' "$*"; else "$@"; fi; }
confirm() {  # yes with BRAIN_YES=1, otherwise ask on the terminal
  [ "${BRAIN_YES:-}" = 1 ] && return 0
  local a; read -r -p "  ?        $1 [y/N] " a </dev/tty 2>/dev/null || return 1
  [[ "$a" =~ ^[yYkK] ]]
}

[ "$(uname -s)" = Darwin ] || die "This starter is for macOS. Elsewhere, follow ONBOARDING.md in $KIT."
[ "$DRY" = 1 ] && printf '\n(dry run: nothing will be changed)\n'

step "AgenttiX 2nd brain"
if [ -z "$CODE" ]; then
  if confirm "Do you code AgenttiX, so the code should be set up on this Mac too?"; then CODE=1; else CODE=0; fi
fi
if [ "$CODE" = 1 ]; then ok "setting up memory and code"; else ok "setting up memory (run again with --code for the code)"; fi

# ------------------------------------------------------------------ basics
step "1. Homebrew, git and the GitHub CLI"
if ! have brew; then
  run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew did not install. Install it from brew.sh and run this again."
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$p" ] && eval "$("$p" shellenv)"; done
fi
have brew && ok "Homebrew"
for t in git gh; do
  if have "$t"; then ok "$t"; else run brew install "$t" && did "installed $t"; fi
done

# ------------------------------------------------------------------ github
step "2. GitHub"
if gh auth status >/dev/null 2>&1; then
  ok "signed in as $(gh api user --jq .login 2>/dev/null)"
else
  run gh auth login --hostname github.com --git-protocol https --web || die "GitHub sign-in did not complete."
fi
# git uses the same login for the private repositories, so no SSH key is needed.
run gh auth setup-git >/dev/null 2>&1 || true
if [ "$DRY" != 1 ]; then
  gh repo view "$KIT" >/dev/null 2>&1 \
    || die "The GitHub account $(gh api user --jq .login 2>/dev/null) has no access to the Agentti-X organisation.
           Ask Samuel to add you, then run this again."
fi
ok "access to $KIT"

# ------------------------------------------------------------------ claude code
step "3. Claude Code"
export PATH="$HOME/.local/bin:$PATH"
if have claude; then ok "claude $(claude --version 2>/dev/null | cut -d' ' -f1)"
else run bash -c "curl -fsSL https://claude.ai/install.sh | bash" && did "installed Claude Code"; fi

# ------------------------------------------------------------------ code tools
if [ "$CODE" = 1 ]; then
  step "4. Tools for the code"
  if ! have node; then
    run brew install node@22 && did "installed Node 22"
    grep -qs 'node@22' "$HOME/.zprofile" \
      || { [ "$DRY" = 1 ] || echo 'export PATH="$(brew --prefix node@22)/bin:$PATH"' >> "$HOME/.zprofile"; note "Node 22 added to PATH in ~/.zprofile (new terminals)"; }
    export PATH="$(brew --prefix node@22 2>/dev/null)/bin:$PATH"
  elif [ "$(node -v | sed 's/^v\([0-9]*\).*/\1/')" = 22 ]; then
    ok "Node 22"
  else
    note "Node $(node -v) is active; the code needs 22 (.nvmrc). With nvm: nvm install 22 && nvm use 22. Left as it is."
  fi
  if [ -d /Applications/Docker.app ]; then ok "Docker Desktop"
  else run brew install --cask docker && did "installed Docker Desktop"; note "open Docker Desktop once and accept its terms"; fi
  if have dotenv; then ok "dotenv-cli"
  elif have npm; then run npm install -g dotenv-cli && did "installed dotenv-cli"
  else note "dotenv-cli needs npm: install Node 22 first, then npm install -g dotenv-cli"; fi
fi

# ------------------------------------------------------------------ an existing code checkout
# A checkout elsewhere is moved, never cloned again: a move keeps .env files and local state.
code_new="$AREA/dev/agenttix-root"; code_old=""
if [ "$CODE" = 1 ] && [ ! -d "$code_new/.git" ]; then
  for c in "$HOME/DEV/agentti-x/agenttix-root" \
           $(find "$HOME" -maxdepth 4 \( -path "$HOME/Library" -o -path "$HOME/_MEMORY" -o -path "$HOME/.Trash" -o -name node_modules -o -name '.*' \) -prune -o -type d -name agenttix-root -print 2>/dev/null); do
    [ -d "$c/.git" ] && { code_old="$c"; break; }
  done
fi

# ------------------------------------------------------------------ the kit and the notes
step "5. The kit, the notes and the Obsidian vault"
tmp="$(mktemp -d)"
if [ "$DRY" = 1 ]; then
  printf '  would    fetch bin/install.sh from %s and run it\n' "$KIT"
else
  gh api "repos/$KIT/contents/bin/install.sh" -H "Accept: application/vnd.github.raw" > "$tmp/install.sh" \
    || die "could not fetch the installer from $KIT."
  flags=()
  [ "$CODE" = 1 ] && [ -z "$code_old" ] && flags+=(--with-doc)
  bash "$tmp/install.sh" ${flags[@]+"${flags[@]}"} || die "the installer stopped — see above. Running this again is safe."
fi

# ------------------------------------------------------------------ the code
if [ "$CODE" = 1 ]; then
  step "6. The code"
  if [ -n "$code_old" ]; then
    printf '  found    an existing checkout at %s\n' "$code_old"
    if [ "$DRY" = 1 ]; then
      printf '  would    ask, then move it to %s\n' "$code_new"
    elif confirm "Move it to $code_new? Stop its dev servers, Docker containers and editor first."; then
      busy=$(lsof -nP -d cwd -Fpcn 2>/dev/null | awk -v d="$code_old" '/^p/{p=substr($0,2)} /^c/{c=substr($0,2)} /^n/{n=substr($0,2); if (index(n, d)==1 && c !~ /^-?(zsh|bash|login)$/) print "    " c " (pid " p ")"}' | sort -u)
      cont=$(docker ps --format '{{.Names}} {{.Label "com.docker.compose.project.working_dir"}}' 2>/dev/null | awk -v d="$code_old" 'index($2, d)==1 {print "    container " $1}')
      if [ -n "$busy$cont" ]; then
        printf '%s\n%s\n' "$busy" "$cont"
        die "these still run in $code_old. Stop them, then run this again."
      fi
      mkdir -p "$(dirname "$code_new")" && mv "$code_old" "$code_new" && did "moved the code to $code_new"
      key() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }
      src="$HOME/.claude/projects/$(key "$code_old")/memory"; dst="$HOME/.claude/projects/$(key "$code_new")/memory"
      [ -d "$src" ] && [ ! -e "$dst" ] && mkdir -p "$(dirname "$dst")" && cp -R "$src" "$dst" && did "carried Claude's code memory over"
      note "Python virtual environments hold absolute paths: recreate them (e.g. agenttix-onboarding/.venv)."
      note "If Next.js complains about old paths, rm -rf .next in that app."
      bash "$AREA/bin/setup.sh" >/dev/null 2>&1 && did "agenttix plugin installed for agenttix-root"
    else
      note "not moved; the code stays at $code_old. Ask Claude to run ONBOARDING.md when you want it moved."
    fi
  fi
  if [ -d "$code_new/.git" ]; then
    run make -C "$code_new" setup || note "make setup stopped; the usual reason is the .env files below"
    for f in .env.db .env.local; do
      [ -f "$code_new/agenttix-infrastructure/$f" ] || note "copy $f from Google Drive (Shared drives / Tech / Data / ENV Files) into $code_new/agenttix-infrastructure/, then run: make -C $code_new setup"
    done
  fi
fi

# ------------------------------------------------------------------ done
step "Done"
cat <<DONE
  Next, by hand:
  - Open Obsidian. The vault is ~/_MEMORY/autoagentti/memory; if asked, choose
    "Trust author and enable plugins".
  - Connect Claude's connectors with your AgenttiX account: claude.ai → Settings
    → Connectors → Gmail, Google Drive, Google Calendar, Atlassian.
  - Start Claude for notes:  cd ~/_MEMORY/autoagentti && claude
$( [ "$CODE" = 1 ] && echo "  - Start Claude for code:   cd ~/_MEMORY/autoagentti/dev/agenttix-root && claude" )
  - How it all works: ~/_MEMORY/autoagentti/memory/shared/2026-11-01-muistin-uusi-rakenne-ohje.md
DONE
