# AdvantageOne: Claude plugins setup for Windows. One step for reps; safe to run again any time.
# Run in PowerShell:   powershell -ExecutionPolicy Bypass -c "irm <link Andrew sent> | iex"
# What it does (asks before anything that needs you):
#   1. Git + Python   2. Pillow (logo tool)   3. Browser check (PDF export)
#   4. GitHub sign-in with a code (no password typed here) + check you can see AO's plugins
#   5. Netlify publishing token (optional, to publish live proposal links)   6. Git name/email for records
#   7. AO plugins: turn on auto-update and bring them up to date now
# Tools it adds without admin rights live in %USERPROFILE%\.ao-tools. It never prints or uploads your tokens.

$TeamSlug = "andrew-up4p-uk"
$Repo = "https://github.com/AdvantageOne/ao-claude-plugins"
$Tools = Join-Path $HOME ".ao-tools"; New-Item -ItemType Directory -Force -Path (Join-Path $Tools "bin") | Out-Null
$Cfg = Join-Path $HOME ".config\ao-proposals"; New-Item -ItemType Directory -Force -Path $Cfg | Out-Null
$Done = $true
function H($t) { Write-Host ""; Write-Host $t -ForegroundColor Cyan }
function Ok($t) { Write-Host "  [OK] $t" -ForegroundColor Green }
function Warn($t) { Write-Host "  [!]  $t" -ForegroundColor Yellow; $script:Done = $false }
function Bad($t) { Write-Host "  [X]  $t" -ForegroundColor Red; $script:Done = $false }
function RefreshPath { $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User") + ";" + (Join-Path $Tools "bin") }
function Has($c) { [bool](Get-Command $c -ErrorAction SilentlyContinue) }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
RefreshPath

H "AdvantageOne Claude setup (Windows)"

H "1/7 Git and Python"
$winget = Has "winget"
if (-not (Has "git")) {
  if ($winget) { Write-Host "  Installing Git (click Yes if Windows asks)..."; winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements | Out-Null; RefreshPath }
}
if (-not (Has "py")) {
  if ($winget) { Write-Host "  Installing Python..."; winget install --id Python.Python.3.12 -e --silent --scope user --accept-source-agreements --accept-package-agreements | Out-Null; RefreshPath }
}
if ((Has "git") -and (Has "py")) { Ok ((git --version) + " / " + (py -3 --version 2>&1)) }
else {
  if (-not $winget) { Bad "Windows' installer (winget) is missing. Install 'App Installer' from the Microsoft Store, then run this again." }
  else { Bad "Git or Python didn't install. Close PowerShell, open it again and rerun this (new installs need a fresh window)." }
  Read-Host "Press Enter to close"; return
}

H "2/7 Logo tool (Pillow)"
py -3 -c "import PIL" 2>$null
if ($LASTEXITCODE -eq 0) { Ok "Pillow installed" }
else { py -3 -m pip install --user --quiet --disable-pip-version-check pillow 2>$null; if ($LASTEXITCODE -eq 0) { Ok "Pillow installed" } else { Bad "Couldn't install Pillow" } }

H "3/7 Browser for PDF export"
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ }
if ($edge) { Ok "Found" } else { Warn "Install Google Chrome or Microsoft Edge so decks can be saved as PDF." }

H "4/7 GitHub sign-in"
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) {
  try {
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
    $rel = Invoke-RestMethod "https://api.github.com/repos/cli/cli/releases/latest" -Headers @{ "User-Agent" = "ao-setup" }
    $url = ($rel.assets | Where-Object { $_.name -like "*_windows_$arch.zip" } | Select-Object -First 1).browser_download_url
    $zip = Join-Path $Tools "gh.zip"; $tmp = Join-Path $Tools "gh-tmp"
    Invoke-WebRequest $url -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $tmp -Force
    Copy-Item (Get-ChildItem $tmp -Recurse -Filter gh.exe | Select-Object -First 1).FullName (Join-Path $Tools "bin\gh.exe") -Force
    Remove-Item $zip, $tmp -Recurse -Force
    $gh = Join-Path $Tools "bin\gh.exe"; Ok "GitHub tool installed"
  } catch { Bad "Couldn't download the GitHub tool. Check your internet and run this again."; Read-Host "Press Enter to close"; return }
}
& $gh auth status --hostname github.com *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "  Your browser will open. Sign in with your AdvantageOne GitHub account, enter the code shown below,"
  Write-Host "  click Authorize, and if it asks about AdvantageOne SSO, authorize that too."
  & $gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key
  if ($LASTEXITCODE -ne 0) { Bad "GitHub sign-in didn't finish. Run this again."; Read-Host "Press Enter to close"; return }
}
& $gh auth setup-git --hostname github.com *> $null
$login = & $gh api user --jq .login 2>$null
git ls-remote $Repo HEAD *> $null
if ($LASTEXITCODE -eq 0) { Ok "Signed in as $login and can see AO's plugins" }
else { Bad "Signed in as $login, but this account can't see AO's plugins. Send Andrew your GitHub name ($login)." }

H "5/7 Publishing live links (Netlify)"
function NlCheck($tok) {
  try {
    $h = @{ Authorization = "Bearer $tok"; "User-Agent" = "ao-setup" }
    $u = Invoke-RestMethod "https://api.netlify.com/api/v1/user" -Headers $h
    $slugs = (Invoke-RestMethod "https://api.netlify.com/api/v1/accounts" -Headers $h) | ForEach-Object { $_.slug }
    if ($slugs -contains $TeamSlug) { return @("ok", $u.email) } else { return @("noteam", $u.email) }
  } catch { return @("bad", "") }
}
$envFile = Join-Path $Cfg "netlify.env"
$saved = ""; if (Test-Path $envFile) { $saved = ((Get-Content $envFile | Where-Object { $_ -like "NETLIFY_TOKEN=*" }) -replace "^NETLIFY_TOKEN=", "") }
$r = if ($saved) { NlCheck $saved } else { @("none", "") }
if ($r[0] -eq "ok") { Ok "Ready to publish as $($r[1])" }
else {
  $ans = Read-Host "  Set up publishing now? Needed to send customers a live link. (y/n)"
  if ($ans -match "^[yY]") {
    Start-Process "https://app.netlify.com/user/applications#personal-access-tokens"
    Write-Host "  In the Netlify page that opened (sign in with your work email if asked):"
    Write-Host "    New access token -> Description: AO proposals -> Expiration: longest available -> Generate -> Copy"
    $sec = Read-Host "  Paste the token here (hidden), then Enter" -AsSecureString
    $tok = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    $r = NlCheck $tok
    if ($r[0] -eq "ok" -or $r[0] -eq "noteam") { Set-Content -Path $envFile -Value "NETLIFY_TOKEN=$tok" -Encoding ASCII }
    switch ($r[0]) {
      "ok" { Ok "Saved. Ready to publish as $($r[1])" }
      "noteam" { Warn "Saved, but $($r[1]) isn't on AO's Netlify team yet. Accept Andrew's Netlify invite email (or ask him for one)." }
      default { Bad "Netlify didn't accept that token. Run this again and copy the whole token." }
    }
    $tok = $null
  } else { Write-Host "  [!]  Skipped. Proposals still build (folder + PDF); run this again later to publish live links." -ForegroundColor Yellow }
}

H "6/7 Your name on knowledge-base records"
if (-not (git config --global user.email)) {
  $name = & $gh api user --jq '.name // ""' 2>$null; $email = & $gh api user --jq '.email // ""' 2>$null
  if ($email -notmatch "@(advtracking\.net|advtracking\.ca|advantageone\.tech)$") { $email = Read-Host "  Your work email (for your name on records)" }
  if (-not $name) { $name = Read-Host "  Your full name" }
  if ($email -match "@") { git config --global user.email $email }
  if ($name) { git config --global user.name $name }
}
Ok "$(git config --global user.name) <$(git config --global user.email)>"

H "7/7 AO plugins up to date"
# Claude keeps a copy of AO's plugins and only refreshes it when auto-update is on for the "advantageone" source.
# This turns it on, then updates now. Uses the GitHub sign-in from step 4; nothing is typed here.
$Cl = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $Cl) { $Cl = (Get-ChildItem (Join-Path $env:APPDATA "Claude\claude-code") -Recurse -Filter claude.exe -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
$Km = Join-Path $HOME ".claude\plugins\known_marketplaces.json"
if (-not $Cl -or -not (Test-Path $Km)) {
  Warn "Not installed yet. Finish the steps below (open Claude, say: set up AO proposals), then run this again."
} else {
  try {
    $d = Get-Content $Km -Raw | ConvertFrom-Json
    if ($d.advantageone -and $d.advantageone.autoUpdate -ne $true) {
      $d.advantageone | Add-Member -NotePropertyName autoUpdate -NotePropertyValue $true -Force
      [IO.File]::WriteAllText($Km, ($d | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
    }
  } catch { }
  $env:CLAUDE_CODE_PLUGIN_PREFER_HTTPS = "1"
  & $Cl plugin marketplace update advantageone *> $null
  if ($LASTEXITCODE -eq 0) {
    foreach ($P in "ao-proposals", "ao-briefing") { & $Cl plugin update "$P@advantageone" *> $null }
    $V = @()
    try { $V = @((& $Cl plugin list --json 2>$null | Out-String | ConvertFrom-Json) | Where-Object { $_.id -like "*@advantageone" } | ForEach-Object { ($_.id -split "@")[0] + " " + $_.version }) } catch { }
    if ($V) { Ok ("Up to date, auto-update on: " + ($V -join ", ")) } else { Ok "Auto-update on (plugins install when you say: set up AO proposals)" }
  } else { Bad "Couldn't reach AO's plugins on GitHub. Check step 4 above, then run this again." }
}

if ($Done) { H "All set!" } else { H "Almost there: fix the [!]/[X] lines above, then run this again." }
Write-Host "  Next: quit Claude completely (right-click its taskbar icon -> Quit), reopen it, go to the Code tab and say:  set up AO proposals"
Write-Host "  (Already set up? Quitting and reopening Claude loads the updated plugins.)"
Read-Host "Press Enter to close"
