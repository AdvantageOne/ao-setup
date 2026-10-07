# AdvantageOne: Claude setup

Gets an AdvantageOne laptop ready for our Claude plugins. It covers:
- Git and Python
- the logo tool
- a browser check for PDF export
- GitHub sign-in with a code
- an optional Netlify token, so you can publish live links

It's safe to run again: it only fixes what's missing, needs no admin password, and never prints or uploads your tokens.

**Mac:** open Terminal and paste:
```
curl -fsSL https://raw.githubusercontent.com/AdvantageOne/ao-setup/main/ao-setup-mac.sh | bash
```

**Windows:** open PowerShell and paste:
```
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/AdvantageOne/ao-setup/main/ao-setup-windows.ps1 | iex"
```

**Then:** quit and reopen Claude, go to the **Code** tab, and say **set up AO proposals**.

The files here are copies. The source of truth is `setup/` in AdvantageOne's private plugin repo, so make changes there and copy them across.
