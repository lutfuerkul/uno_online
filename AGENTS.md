# uno_online

## Cursor Cloud specific instructions

State of the repository (as of this note): this is an **empty scaffold**. The
only tracked file besides this one is `README.md` (contents: `# uno_online`).
There is no product code, no dependency manifest (`package.json`,
`requirements.txt`, etc.), no build system, no tests, and no services to run.

Implications for future cloud agents:

- There is nothing to build, lint, test, or run yet. Do not expect an
  application to start until a tech stack is chosen and product code is added.
- The repo name and README imply the intended product is an online UNO card
  game, but no implementation exists. The stack has not been chosen.
- The environment update script is written defensively: it auto-installs
  dependencies only if a recognized manifest appears later (npm/pnpm/yarn
  lockfiles or `package.json`, and Python `requirements.txt`). On the current
  empty repo it is a safe no-op.
- Available runtimes in the VM: Node.js 22, npm 10, Python 3.12, pip 24.

When product code is added, update this section with the real
build/lint/test/run commands (prefer referencing `package.json` scripts, a
`Makefile`, or similar rather than duplicating commands here).
