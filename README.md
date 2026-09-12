# AWS Architect Associate — Learning Through Projects

A hands-on learning repo for the AWS Certified Solutions Architect – Associate
path: real, small projects instead of flashcards, plus the tooling used to
document each one.

## Reference: `aws-doc-create` Claude Code skill

[`.claude/skills/aws-doc-create/`](.claude/skills/aws-doc-create/) contains a
Claude Code skill for generating printable AWS architecture documents —
self-contained HTML pages with hand-drawn SVG topology diagrams (VPC / AZ /
subnets / managed services) in a navy-and-amber "console" house style.

Kept here as a reference so future readers of this repo (including future me)
can regenerate a consistent architecture write-up — context, component map,
data flow, key decisions, and the security/scaling/reliability/cost story —
for each project added below.

- `SKILL.md` — the recipe: palette, document anatomy, diagram conventions, workflow.
- `shell.html` — a complete, ready-to-copy starting HTML page (fonts + styles +
  SVG arrow markers) with a scaffolded architecture section.

To use it in Claude Code, invoke the `aws-doc-create` skill, or copy
`shell.html` directly and fill in a project's architecture.

## Projects

_(coming soon)_
