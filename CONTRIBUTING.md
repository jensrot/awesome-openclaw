# Contributing to Awesome OpenClaw

Contributions are welcome! Please take a moment to review this document before submitting a pull request.

## Guidelines

- **Quality over Quantity:** We only accept high-quality resources that are relevant to the OpenClaw ecosystem.
- **Formatting:** Ensure your entry follows the existing format:
  - `[Name](Link) - Description.`
- **Descriptions:** Keep descriptions concise and clear. Start with a capital letter and end with a period.
- **Categorization:** Place your resource in the most appropriate section. If a section doesn't exist, feel free to suggest one.
- **No Scams:** Avoid adding links to unverified "get rich quick" agent schemes or "pump and dump" tokens.
- **Check Links:** Make sure the link is active and points directly to the resource.

## How to Contribute

1. **Fork** the repository.
2. **Create a new branch** for your contribution.
3. **Add your resource** to the `README.md` file.
4. **Ensure alphabetical order** within each section where applicable.
5. **Run the linter** to validate your changes (see below).
6. **Commit your changes** with a descriptive message (e.g., `Add MoltWorker to Infrastructure`).
7. **Submit a Pull Request**.

## Linting

All pull requests are automatically validated by our linter. You can run it locally before submitting:

```bash
# Install dependencies
npm install

# Run local markdown lint
npm run lint:local

# Run full validation (format, alphabetical order, duplicates, etc.)
bash scripts/validate-readme.sh

# Auto-fix alphabetical order issues
bash scripts/validate-readme.sh --fix
```

This checks formatting, alphabetical order, duplicates, and other quality standards. Use `--fix` to automatically sort entries alphabetically within each section.

## Contribution Criteria

To maintain the quality of this "Awesome List," we look for:
- Tools that are active and maintained.
- Skills that follow the standard [AgentSkills spec](https://docs.openclaw.ai/skills).
- Resources that have a clear benefit to the OpenClaw community.