# imprintomeR AI Agent Skill

This folder contains an optional Codex-style AI agent skill for working with the `imprintomeR` R package.

## Install

Copy the skill folder into your local Codex skills directory:

```bash
mkdir -p ~/.codex/skills
cp -r skills/imprintomer ~/.codex/skills/
```

On Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse -Force skills\imprintomer "$env:USERPROFILE\.codex\skills\"
```

## Use

Ask your AI agent to use the skill:

```text
Use $imprintomer to create an imprintomeR workflow from IDAT files.
```

Example requests:

- Use `$imprintomer` to draft a GEO vignette with QC and imprintome analysis.
- Use `$imprintomer` to review an export or visualization change.
- Use `$imprintomer` to create CLI examples for `run_meth_QC.R` and `run_imprintomeR.R`.
- Use `$imprintomer` to explain how to generate standard workflow plots.

The skill is guidance for AI agents; it is not required for installing or running the R package.
