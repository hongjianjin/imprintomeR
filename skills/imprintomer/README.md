# imprintomeR Agent Skill

An Agent Skills open-standard skill for reproducible `imprintomeR` methylation QC and genomic-imprinting analysis.

The skill guides agents through the two MCP analysis tools:

- `run_methylation_qc` — process metadata and raw IDAT files and verify the exported `*_qcset.rds`.
- `run_imprintome_analysis` — run post-QC imprintomeR analysis from a QC RDS or beta plus metadata.

## Installation

The required skill file is [`SKILL.md`](SKILL.md). Install or link the `skills/imprintomer/` directory according to the target agent's Agent Skills support. For example, with the Vercel universal skills CLI:

```bash
npx skills add ./skills/imprintomer
```

The MCP server must be configured separately. See [`mcp_server/README.md`](../../mcp_server/README.md) for local clone, client registration, remote deployment, and example requests.

## Use

Ask a compatible agent to use the `imprintomer` skill and MCP server, for example:

```text
Use the imprintomeR skill and MCP server to run QC, verify the exported qcset.rds, then run imprintome analysis with the selected probeset on hg19.
```

The skill is guidance; the MCP server executes the R workflows and returns output artifacts.
