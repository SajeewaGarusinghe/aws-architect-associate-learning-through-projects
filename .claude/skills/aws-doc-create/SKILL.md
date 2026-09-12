---
name: aws-doc-create
description: >-
  Create a printable AWS (or general cloud) architecture document as a single
  self-contained HTML page, centered on clean hand-drawn SVG architecture
  diagrams in a navy-and-amber "console" house style. Use when the user asks for
  an architecture write-up, reference architecture, solution design doc, HLD/LLD,
  design review packet, well-architected review, or any document whose centerpiece
  is a cloud topology diagram (VPC / multi-AZ / subnets / managed services) with
  supporting component, data-flow, decision, and non-functional sections. Produces
  a paginated (Letter/A4) print-ready doc; recolorable per brand.
license: MIT
---

# AWS Architecture Document

Build a printable **architecture document** whose centerpiece is a clean,
consistent cloud topology diagram, wrapped in a disciplined write-up: context,
components, data flow, key decisions, and the non-functional story (security,
scaling, reliability, cost). The house style is a navy + amber "console" look.

The recipe is cloud-agnostic in structure — it defaults to AWS vocabulary
(Region / VPC / AZ / public+private subnets / managed services) but recolors and
relabels for GCP, Azure, or on-prem. Everything is self-contained: **`shell.html`**
(beside this file) is a complete standalone HTML page carrying the whole `<style>`
block and the SVG diagram markers.

> This is a **print document** — a paginated (Letter/A4) HTML page that prints or
> saves to PDF directly. No framework or design-system dependency; the only
> external references are two Google fonts.

---

## 1. Shell — a complete standalone HTML page

- One `.html` file. `shell.html` IS the starting point: copy it whole, then
  replace the demo content inside `<div class="sheet">`.
- Self-contained: a `.sheet` page frame plus an `@page` rule give paginated
  Letter output with no component library.
- Fonts: **Inter** (400–800) + **JetBrains Mono** (400–600), the only external refs.
- The complete `<style>` block and the `<svg><defs>` arrow markers are already in
  `shell.html`. Keep the classes; change the content.

## 2. Palette — `:root` tokens (recolor per brand, keep the structure)

```
--ink #232F3E   (navy — cover, dividers, dark tiles, headings)
--orange #FF9900 / --orange-d #EC7211   (the single accent: rules, numbers, links)
--slate #37475A  --gray #545B64  --gray-l #879196
--wash #FAFAFA   --line #E3E7EB   (surfaces & hairlines)
--blue #2D72B8   --grn #1B9E77   --purple #8B5CF6   (diagram tiers)
```

- **One dark ground + one accent is the whole identity.** Accent is a line
  (numbers, rules, links, one border-left), never a flood. Cover/dividers are the
  dark ground with a soft accent radial glow and an accent edge bar.
- Contrast from tone, not saturation. White / `--wash` surfaces, `--line`
  hairlines, no pure black, no heavy shadows.
- Body ~10.2–11pt / `line-height 1.6`. Sub-labels 9pt uppercase accent + fading rule.

## 3. Document skeleton

Architecture docs are diagram-led. Keep the prose tight around the picture:

1. **Cover** (`.cover`) — eyebrow "Architecture Overview", `<h1>` system name,
   `.sub` one-line goal, `.meta` headline facts (AZ count, target throughput, p99).
2. **Overview** `<p>` + `.callout.tip` — scope, assumptions, what's out of scope.
3. **Contents** (`.toc`) — only for multi-section / multi-service docs.
4. One or more **architecture sections** (`.p`), each in the anatomy below.
5. **Closing** — decisions log / open questions / cost summary table.

## 4. Section anatomy (`.p`) — the diagram is the centerpiece

Order is fixed; omit what doesn't apply, never reorder:

1. `.head-row` — `<h2 class="sec">` section kicker + `↑ Contents` back-link.
2. `.p-h` — `<span class="num">Nn.</span>` + title.
3. `.lede` — "In one line" boxed summary of the architectural idea.
4. `.sub-lbl` **Context & requirements** → `.reqs` 3-col grid
   (Functional / Non-functional / Scale & constraints).
5. `.sub-lbl` **High-level design** → `.svc` component map (colored `.dot` +
   service name + role, each ending in a bold **Why:**). This names every node
   that appears in the diagram.
6. **`figure.dg` — the architecture diagram (§5).** The centerpiece; give it room.
7. `.sub-lbl` **Data flow** → numbered request/response walk-through keyed to the
   diagram's edges (1 → 2 → 3 …).
8. `.sub-lbl` **Key decisions** → `.why` trade-off tables (`.opt.no` ✗ rejected /
   `.opt.yes` ✓ chosen) + `.callout.key` for the pivotal concept.
9. `.sub-lbl` **Security · scaling · reliability · cost** → `.svc` list, one row
   each: data protection, scaling strategy, failure modes + blast radius, cost levers.
10. `.spine` — **operational notes**: dark-header block with a `.tl` timeline
    (e.g. Deploy / Observe / Fail over), a `.three` "watch these three things"
    list, and a `.flag` "red flag — don't" anti-pattern.

Callouts: `.callout.key` (blue), `.callout.tip` (accent), `.callout.warn` (red).

## 5. The architecture diagram — one visual language

This is the reason the doc exists. Hand-author inline `<svg>` in `figure.dg` with
a `<figcaption class="cap">` (bold **Fig Nn** + one-line read). Hold the language
identical across every figure.

- **Draw real cloud topology.** Nest dashed grouping frames: `.region` → `.vpc`
  → `.az` (repeat for multi-AZ) → `.sub-pub` (green public subnet) / `.sub-priv`
  (blue private subnet) / `.zbox`. Label each with `.zone-lbl`. Show the actual
  placement — load balancer in public subnets, compute + data in private, managed
  services outside the VPC reached via endpoints.
- **Tile colour = tier** (define once in a `.blocks` legend, reuse everywhere):
  `.tile-g` edge/entry (CDN, WAF, ALB), `.tile` (dark) compute, `.tile-p` async
  (queues, streams, workers), `.tile-b` data stores, `.tile-o` client/highlight,
  `.tile-w` external/managed (white w/ stroke).
- **Line style = flow:** `.ln` sync request (grey), `.ln-o` primary path (accent),
  `.ln-async` (dashed) async/event. Arrow markers `#arrow` / `#arrow-o` / `#arrow-a`.
- **Text:** `.t-lbl`/`.t-lbli` tile labels, `.t-sub` sub-labels, `.flow`/`.flow-a`
  edge annotations.
- **Annotate flows with real values** — throughput (`~4,000 rd/s`), latency
  (`p99 < 50 ms`, `single-digit ms`), protocol (`HTTPS · presigned`), correctness/
  availability cues (`Multi-AZ`, `≈99% cache hits`, `no oversell`). Place them in
  empty zones; never overlap tiles. The numbers should match the `.meta` and
  `.reqs` figures elsewhere in the section.
- Keep one topology per figure. If a system has distinct sync and async paths (or
  read vs write), it's fine to show both in one diagram using the line styles, or
  split into two figures — but never mix two unrelated systems in one frame.

## 6. Content rules

- Real, defensible AWS specifics: correct service names, plausible capacity math,
  honest trade-offs (why the rejected option is worse). No filler, no invented
  numbers that don't derive from stated scale.
- Every node in the diagram must appear in the `.svc` component map, and vice
  versa — the picture and the prose describe the same system.
- `break-inside:avoid` is on every block so figures/tables don't split across
  pages; `.part` dividers use `break-before:page`.

## 7. Workflow

1. Clarify what's missing: system/workload, scale targets, cloud + regions,
   compliance constraints, brand colors (or keep navy/amber), single-service vs
   multi-section.
2. Copy `shell.html` to a new `.html` file; recolor `:root` if rebranding.
3. Draft the component map first, then draw the diagram so every node has a home,
   then write the flow / decisions / non-functional sections around it.
4. Print-ready as-is: browser Print → Save as PDF produces the paginated document.

## Files in this skill

- `SKILL.md` — this recipe.
- `shell.html` — the complete standalone starting page (all CSS + diagram markers,
  with a scaffolded architecture section). Copy it and fill in the content.
