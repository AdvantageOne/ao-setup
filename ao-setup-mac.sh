#!/bin/bash
# AdvantageOne: Claude plugins setup for Mac. One step for reps; safe to run again any time.
# Run in Terminal:   curl -fsSL <link Andrew sent> | bash
# What it does (asks before anything that needs you):
#   1. Git + Python (Apple's developer tools)   2. Pillow (logo tool)   3. Chrome/Edge check (PDF export)
#   4. GitHub sign-in with a code (no password typed here) + check you can see AO's plugins
#   5. Netlify publishing token (optional, to publish live proposal links)   6. Git name/email for records
#   7. AO plugins: turn on auto-update and bring them up to date now
# Nothing goes to sudo/admin. Tools it adds live in ~/.ao-tools. It never prints or uploads your tokens.
set -u
TEAM_SLUG="andrew-up4p-uk"
REPO="https://github.com/AdvantageOne/ao-claude-plugins"
TOOLS="$HOME/.ao-tools"; mkdir -p "$TOOLS/bin"; export PATH="$TOOLS/bin:$PATH"
CFG="$HOME/.config/ao-proposals"; mkdir -p "$CFG"
exec 3</dev/tty   # read answers from the keyboard even when piped from curl
b(){ printf "\n\033[1m%s\033[0m\n" "$1"; }; ok(){ printf "  ✅ %s\n" "$1"; }; warn(){ printf "  ⚠️  %s\n" "$1"; }; bad(){ printf "  ❌ %s\n" "$1"; }
ask(){ printf "  %s " "$1"; read -r REPLY <&3; }
DONE=1

b "AdvantageOne Claude setup (Mac)"

b "1/7 Git and Python"
if xcode-select -p >/dev/null 2>&1 && /usr/bin/git --version >/dev/null 2>&1 && /usr/bin/python3 --version >/dev/null 2>&1; then
  ok "$(/usr/bin/git --version) · $(/usr/bin/python3 --version)"
else
  xcode-select --install >/dev/null 2>&1
  warn "A window just opened to install Apple's developer tools (they include Git and Python)."
  echo "     Click Install, wait until it says it's done (5–15 min), then run this setup again."
  exit 0
fi
PY=/usr/bin/python3

b "2/7 Logo tool (Pillow)"
if $PY -c "import PIL" 2>/dev/null; then ok "Pillow installed"
else $PY -m pip install --user --quiet --disable-pip-version-check pillow 2>/dev/null && ok "Pillow installed" || { bad "Couldn't install Pillow"; DONE=0; }; fi

b "3/7 Browser for PDF export"
if [ -d "/Applications/Google Chrome.app" ] || [ -d "/Applications/Microsoft Edge.app" ] || [ -d "/Applications/Brave Browser.app" ]; then ok "Found"
else warn "Install Google Chrome (google.com/chrome) so decks can be saved as PDF."; DONE=0; fi

b "4/7 GitHub sign-in"
GH="$(command -v gh || true)"
if [ -z "$GH" ]; then
  ARCH=$( [ "$(uname -m)" = "arm64" ] && echo arm64 || echo amd64 )
  URL=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | $PY -c "import json,sys;print([a['browser_download_url'] for a in json.load(sys.stdin)['assets'] if a['name'].endswith('_macOS_$ARCH.zip')][0])" 2>/dev/null)
  if [ -n "$URL" ] && curl -fsSL "$URL" -o "$TOOLS/gh.zip" && /usr/bin/unzip -qo "$TOOLS/gh.zip" -d "$TOOLS/gh-tmp"; then
    cp "$TOOLS"/gh-tmp/*/bin/gh "$TOOLS/bin/gh" && chmod +x "$TOOLS/bin/gh"; rm -rf "$TOOLS/gh.zip" "$TOOLS/gh-tmp"; GH="$TOOLS/bin/gh"; ok "GitHub tool installed"
  else bad "Couldn't download the GitHub tool. Check your internet and run this again."; exit 1; fi
fi
if ! "$GH" auth status --hostname github.com </dev/null >/dev/null 2>&1; then
  echo "  Your browser will open. Sign in with your AdvantageOne GitHub account, enter the code shown below,"
  echo "  click Authorize, and if it asks about AdvantageOne SSO, authorize that too."
  "$GH" auth login --hostname github.com --git-protocol https --web --skip-ssh-key </dev/tty || { bad "GitHub sign-in didn't finish. Run this again."; exit 1; }
fi
"$GH" auth setup-git --hostname github.com </dev/null >/dev/null 2>&1
LOGIN=$("$GH" api user --jq .login 2>/dev/null </dev/null)
if /usr/bin/git ls-remote "$REPO" HEAD >/dev/null 2>&1; then ok "Signed in as $LOGIN and can see AO's plugins"
else bad "Signed in as $LOGIN, but this account can't see AO's plugins. Send Andrew your GitHub name ($LOGIN)."; DONE=0; fi

b "5/7 Publishing live links (Netlify)"
nl_check(){ NETLIFY_AUTH_TOKEN="$1" $PY - "$TEAM_SLUG" <<'PYEOF'
import json,os,sys,urllib.request
t=os.environ["NETLIFY_AUTH_TOKEN"]; h={"Authorization":"Bearer "+t,"User-Agent":"ao-setup"}
try:
    u=json.load(urllib.request.urlopen(urllib.request.Request("https://api.netlify.com/api/v1/user",headers=h),timeout=20))
    s=[a["slug"] for a in json.load(urllib.request.urlopen(urllib.request.Request("https://api.netlify.com/api/v1/accounts",headers=h),timeout=20))]
except Exception: print("bad"); sys.exit()
print("ok "+u.get("email","") if sys.argv[1] in s else "noteam "+u.get("email",""))
PYEOF
}
SAVED=$(grep -s '^NETLIFY_TOKEN=' "$CFG/netlify.env" | cut -d= -f2-)
R=$( [ -n "$SAVED" ] && nl_check "$SAVED" || echo none )
if [ "${R%% *}" = "ok" ]; then ok "Ready to publish as ${R#ok }"
else
  ask "Set up publishing now? Needed to send customers a live link. (y/n)"; 
  if [ "${REPLY:-n}" = "y" ] || [ "${REPLY:-n}" = "Y" ]; then
    open "https://app.netlify.com/user/applications#personal-access-tokens" 2>/dev/null
    echo "  In the Netlify page that opened (sign in with your work email if asked):"
    echo "    New access token → Description: AO proposals → Expiration: longest available → Generate → Copy"
    printf "  Paste the token here (hidden, then Enter): "; read -rs TOK <&3; echo
    R=$(nl_check "$TOK")
    case "${R%% *}" in
      ok) umask 077; printf 'NETLIFY_TOKEN=%s\n' "$TOK" > "$CFG/netlify.env"; chmod 600 "$CFG/netlify.env"; ok "Saved. Ready to publish as ${R#ok }";;
      noteam) umask 077; printf 'NETLIFY_TOKEN=%s\n' "$TOK" > "$CFG/netlify.env"; chmod 600 "$CFG/netlify.env"; warn "Saved, but ${R#noteam } isn't on AO's Netlify team yet. Accept Andrew's Netlify invite email (or ask him for one)."; DONE=0;;
      *) bad "Netlify didn't accept that token. Run this again and copy the whole token."; DONE=0;;
    esac
    unset TOK
  else warn "Skipped. Proposals still build (folder + PDF); run this again later to publish live links."; fi
fi

b "6/7 Your name on knowledge-base records"
if [ -z "$(/usr/bin/git config --global user.email)" ]; then
  NAME=$("$GH" api user --jq '.name // ""' 2>/dev/null </dev/null); EMAIL=$("$GH" api user --jq '.email // ""' 2>/dev/null </dev/null)
  case "$EMAIL" in *@advtracking.net|*@advtracking.ca|*@advantageone.tech) ;; *) ask "Your work email (for your name on records):"; EMAIL="$REPLY";; esac
  [ -z "$NAME" ] && { ask "Your full name:"; NAME="$REPLY"; }
  case "$EMAIL" in *@*) /usr/bin/git config --global user.email "$EMAIL";; esac
  [ -n "$NAME" ] && /usr/bin/git config --global user.name "$NAME"
fi
ok "$(/usr/bin/git config --global user.name) <$(/usr/bin/git config --global user.email)>"

b "7/7 AO plugins up to date"
# Claude keeps a copy of AO's plugins and only refreshes it when auto-update is on for the "advantageone" source.
# This turns it on, then updates now. Uses the GitHub sign-in from step 4; nothing is typed here.
CL="$(command -v claude || true)"
[ -z "$CL" ] && CL="$(ls -t "$HOME/Library/Application Support/Claude/claude-code"/*/*/claude.app/Contents/MacOS/claude 2>/dev/null | head -1)"
KM="$HOME/.claude/plugins/known_marketplaces.json"
if [ -z "$CL" ] || [ ! -f "$KM" ]; then
  warn "Not installed yet. Finish the steps below (open Claude, say: set up AO proposals), then run this again."
else
  $PY - "$KM" <<'PYEOF'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
if "advantageone" in d and d["advantageone"].get("autoUpdate") is not True:
    d["advantageone"]["autoUpdate"]=True; json.dump(d,open(p,"w"),indent=2)
PYEOF
  if CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1 "$CL" plugin marketplace update advantageone </dev/null >/dev/null 2>&1; then
    for P in ao-proposals ao-briefing ao-orders; do "$CL" plugin update "$P@advantageone" </dev/null >/dev/null 2>&1; done
    V=$("$CL" plugin list --json </dev/null 2>/dev/null | $PY -c "import json,sys;print(', '.join(p['id'].split('@')[0]+' '+str(p.get('version')) for p in json.load(sys.stdin) if p['id'].endswith('@advantageone')))" 2>/dev/null)
    if [ -n "$V" ]; then ok "Up to date, auto-update on: $V"; else ok "Auto-update on (plugins install when you say: set up AO proposals)"; fi
  else bad "Couldn't reach AO's plugins on GitHub. Check step 4 above, then run this again."; DONE=0; fi
fi

if [ $DONE = 1 ]; then b "All set ✅"; else b "Almost there: fix the ⚠️/❌ lines above, then run this again."; fi
echo "  Next: quit Claude completely (Cmd+Q), reopen it, go to the Code tab and say:  set up AO proposals"
echo "  (Already set up? Quitting and reopening Claude loads the updated plugins.)"
