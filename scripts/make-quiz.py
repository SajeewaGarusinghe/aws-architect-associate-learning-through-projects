#!/usr/bin/env python3
"""Build a lab's interactive exam drill from its quiz.json.

    ./scripts/make-quiz.py labs/02-alb-autoscaling

Reads LAB/quiz.json and writes LAB/docs/exam-quiz.html plus an artifact-ready
copy (no wrapper tags) under the scratchpad path given by --artifact-out.

quiz.json shape:
    {"eyebrow": "...", "title": "...", "intro": "...",
     "questions": [{"q": "...", "options": ["...", ...],
                    "answer": 0, "why": "..."}]}
Question, option and explanation text may contain inline HTML such as <code>.
"""
import json, sys, pathlib, argparse

TEMPLATE = """<title>{title}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap">

<style>
  :root{{
    --bg:#F7F6F4; --surface:#FFFFFF; --surface-2:#FBFAF9;
    --ink:#232F3E; --body:#3A4552; --muted:#6B7480; --line:#E4E2DE;
    --accent:#C25A08; --accent-br:#FF9900; --navy:#232F3E;
    --good:#13795B; --good-bg:#E9F6F1; --good-line:#A8DCC8;
    --bad:#B0332A; --bad-bg:#FCECEA; --bad-line:#EFBDB6;
    --shadow:0 1px 2px rgba(35,47,62,.06), 0 8px 24px rgba(35,47,62,.05);
  }}
  @media (prefers-color-scheme: dark){{
    :root:not([data-theme="light"]){{
      --bg:#141B24; --surface:#1D2631; --surface-2:#222C38;
      --ink:#EAEEF3; --body:#C2CBD5; --muted:#8B96A3; --line:#2F3A47;
      --accent:#FFA92B; --accent-br:#FF9900; --navy:#0F151C;
      --good:#3FD3A3; --good-bg:#123026; --good-line:#1E5943;
      --bad:#F58374; --bad-bg:#321A18; --bad-line:#6B2C25;
      --shadow:0 1px 2px rgba(0,0,0,.3), 0 8px 24px rgba(0,0,0,.25);
    }}
  }}
  :root[data-theme="dark"]{{
    --bg:#141B24; --surface:#1D2631; --surface-2:#222C38;
    --ink:#EAEEF3; --body:#C2CBD5; --muted:#8B96A3; --line:#2F3A47;
    --accent:#FFA92B; --accent-br:#FF9900; --navy:#0F151C;
    --good:#3FD3A3; --good-bg:#123026; --good-line:#1E5943;
    --bad:#F58374; --bad-bg:#321A18; --bad-line:#6B2C25;
    --shadow:0 1px 2px rgba(0,0,0,.3), 0 8px 24px rgba(0,0,0,.25);
  }}

  *{{box-sizing:border-box}}
  body{{background:var(--bg);color:var(--body);margin:0;
    font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
    -webkit-font-smoothing:antialiased;line-height:1.6;}}
  .wrap{{max-width:720px;margin:0 auto;padding-block:0 56px;padding-left:16px;padding-right:16px;}}
  code{{font-family:'JetBrains Mono',ui-monospace,monospace;font-size:.88em;
    background:var(--surface-2);border:1px solid var(--line);border-radius:4px;padding:1px 5px;color:var(--ink);}}

  header{{background:var(--navy);margin:0 -16px 28px;padding:30px 16px 26px;position:relative;overflow:hidden;}}
  header::after{{content:"";position:absolute;left:0;right:0;bottom:0;height:4px;background:var(--accent-br);}}
  header::before{{content:"";position:absolute;right:-100px;top:-130px;width:360px;height:360px;border-radius:50%;
    background:radial-gradient(circle,rgba(255,153,0,.15),transparent 68%);}}
  .eyebrow{{font-size:10px;letter-spacing:.2em;text-transform:uppercase;color:var(--accent-br);font-weight:600;margin-bottom:10px;}}
  header h1{{margin:0 0 6px;font-size:26px;font-weight:800;letter-spacing:-.015em;color:#fff;text-wrap:balance;}}
  header p{{margin:0;color:#A8B2BD;font-size:14px;max-width:52ch;}}

  .bar{{display:flex;align-items:center;gap:14px;margin-top:20px;position:relative;}}
  .track{{flex:1;height:5px;background:rgba(255,255,255,.16);border-radius:3px;overflow:hidden;}}
  .fill{{height:100%;width:0;background:var(--accent-br);border-radius:3px;transition:width .35s ease;}}
  .tally{{font-size:12px;color:#A8B2BD;font-variant-numeric:tabular-nums;white-space:nowrap;font-weight:500;}}
  .tally b{{color:#fff;font-weight:700;}}

  .card{{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:22px;box-shadow:var(--shadow);}}
  .qnum{{font-size:10px;letter-spacing:.16em;text-transform:uppercase;color:var(--accent);font-weight:700;margin-bottom:10px;}}
  .qtext{{font-size:17px;color:var(--ink);font-weight:500;margin:0 0 18px;line-height:1.5;text-wrap:pretty;}}

  .opts{{display:flex;flex-direction:column;gap:8px;}}
  .opt{{display:flex;gap:12px;align-items:flex-start;text-align:left;width:100%;
    background:var(--surface-2);border:1.5px solid var(--line);border-radius:9px;padding:12px 14px;
    font:inherit;font-size:14.5px;color:var(--body);cursor:pointer;transition:border-color .15s,background .15s;}}
  .opt:hover:not(:disabled){{border-color:var(--accent);}}
  .opt:focus-visible{{outline:2px solid var(--accent);outline-offset:2px;}}
  .opt:disabled{{cursor:default;}}
  .opt .key{{flex:none;width:22px;height:22px;border-radius:5px;background:var(--line);color:var(--ink);
    font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;margin-top:1px;}}
  .opt.right{{background:var(--good-bg);border-color:var(--good-line);}}
  .opt.right .key{{background:var(--good);color:#fff;}}
  .opt.wrong{{background:var(--bad-bg);border-color:var(--bad-line);}}
  .opt.wrong .key{{background:var(--bad);color:#fff;}}

  .why{{margin-top:16px;border-left:3px solid var(--accent-br);background:var(--surface-2);
    border-radius:0 8px 8px 0;padding:13px 16px;font-size:14px;color:var(--body);}}
  .why .vl{{display:block;font-size:10px;letter-spacing:.14em;text-transform:uppercase;font-weight:700;margin-bottom:5px;}}
  .why.ok .vl{{color:var(--good);}}
  .why.no .vl{{color:var(--bad);}}
  .why strong{{color:var(--ink);font-weight:600;}}

  .actions{{display:flex;gap:10px;margin-top:18px;flex-wrap:wrap;}}
  .btn{{font:inherit;font-size:14px;font-weight:600;padding:10px 20px;border-radius:8px;cursor:pointer;
    border:1.5px solid transparent;background:var(--navy);color:#fff;transition:opacity .15s;}}
  .btn:hover{{opacity:.88;}}
  .btn:focus-visible{{outline:2px solid var(--accent);outline-offset:2px;}}
  .btn.ghost{{background:transparent;border-color:var(--line);color:var(--body);}}

  .done{{text-align:center;padding:14px 0 4px;}}
  .score{{font-size:52px;font-weight:800;color:var(--ink);line-height:1;font-variant-numeric:tabular-nums;}}
  .score span{{color:var(--muted);font-size:24px;font-weight:600;}}
  .verdict{{font-size:15px;color:var(--body);margin:12px auto 0;max-width:46ch;}}
  .missed{{margin-top:22px;text-align:left;}}
  .missed h3{{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:var(--accent);margin:0 0 10px;font-weight:700;}}
  .missed li{{font-size:14px;margin-bottom:7px;color:var(--body);}}
  .missed li::marker{{color:var(--bad);}}

  footer{{margin-top:26px;font-size:12.5px;color:var(--muted);text-align:center;}}

  @media (prefers-reduced-motion: reduce){{*{{transition:none!important;}}}}
  @media (max-width:480px){{ header h1{{font-size:22px;}} .qtext{{font-size:16px;}} .card{{padding:18px;}} }}
</style>

<div class="wrap">
  <header>
    <div class="eyebrow">{eyebrow}</div>
    <h1>{title}</h1>
    <p>{intro}</p>
    <div class="bar">
      <div class="track"><div class="fill" id="fill"></div></div>
      <div class="tally" id="tally"><b>0</b>/{n} correct</div>
    </div>
  </header>

  <div id="stage"></div>

  <footer>{footer}</footer>
</div>

<script>
const Q = {questions};

const KEYS = ["A","B","C","D","E"];
const stage = document.getElementById("stage");
const fill = document.getElementById("fill");
const tally = document.getElementById("tally");
let i = 0, score = 0, missed = [];

function progress(){{
  fill.style.width = (i / Q.length * 100) + "%";
  tally.innerHTML = "<b>" + score + "</b>/" + Q.length + " correct";
}}

// Options are shuffled on every run so the correct answer never settles into a
// predictable position. `order[pos]` gives the original index shown at pos.
function shuffle(item){{
  const order = item.options.map((_, n) => n);
  for (let k = order.length - 1; k > 0; k--){{
    const j = Math.floor(Math.random() * (k + 1));
    [order[k], order[j]] = [order[j], order[k]];
  }}
  item.order = order;
}}

function render(){{
  if (i >= Q.length) return finish();
  const item = Q[i];
  if (!item.order) shuffle(item);
  const card = document.createElement("div");
  card.className = "card";
  card.innerHTML =
    '<div class="qnum">Question ' + (i+1) + ' of ' + Q.length + '</div>' +
    '<p class="qtext">' + item.q + '</p><div class="opts"></div>';
  const box = card.querySelector(".opts");
  item.order.forEach((orig, pos) => {{
    const b = document.createElement("button");
    b.className = "opt";
    b.id = "q" + i + "opt" + pos;
    b.innerHTML = '<span class="key">' + KEYS[pos] + '</span><span>' + item.options[orig] + '</span>';
    b.addEventListener("click", () => choose(card, box, pos));
    box.appendChild(b);
  }});
  stage.replaceChildren(card);
  progress();
}}

function choose(card, box, pickedPos){{
  const item = Q[i];
  const correctPos = item.order.indexOf(item.answer);
  const correct = pickedPos === correctPos;
  if (correct) score++; else missed.push(i);

  [...box.children].forEach((b, pos) => {{
    b.disabled = true;
    if (pos === correctPos) b.classList.add("right");
    else if (pos === pickedPos) b.classList.add("wrong");
  }});

  const why = document.createElement("div");
  why.className = "why " + (correct ? "ok" : "no");
  why.innerHTML = '<span class="vl">' +
    (correct ? "Correct — " + KEYS[correctPos] : "Not quite — the answer is " + KEYS[correctPos]) +
    '</span>' + item.why;
  card.appendChild(why);

  const acts = document.createElement("div");
  acts.className = "actions";
  const next = document.createElement("button");
  next.className = "btn";
  next.textContent = i === Q.length - 1 ? "See results" : "Next question";
  next.addEventListener("click", () => {{ i++; render(); }});
  acts.appendChild(next);
  card.appendChild(acts);
  next.focus();
  progress();
}}

function finish(){{
  fill.style.width = "100%";
  const pct = Math.round(score / Q.length * 100);
  const verdict = pct >= 85 ? "Comfortably above the ~72% needed to pass. This domain is solid."
    : pct >= 72 ? "Around passing standard. Re-read the ones you missed — the margin is thin."
    : pct >= 50 ? "The concepts are landing but the details are not yet reliable. Worth a second pass."
    : "Worth rebuilding the lab and working through the console tour before drilling again.";

  const card = document.createElement("div");
  card.className = "card done";
  let html = '<div class="score">' + pct + '<span>%</span></div>' +
    '<p class="verdict"><strong>' + score + ' of ' + Q.length + ' correct.</strong> ' + verdict + '</p>';
  if (missed.length){{
    html += '<div class="missed"><h3>Review these</h3><ul>' +
      missed.map(n => '<li>Q' + (n+1) + ' — ' + Q[n].q.replace(/<[^>]+>/g, "").slice(0, 95) + '…</li>').join("") +
      '</ul></div>';
  }}
  html += '<div class="actions" style="justify-content:center"><button class="btn ghost" id="again">Run it again</button></div>';
  card.innerHTML = html;
  stage.replaceChildren(card);
  document.getElementById("again").addEventListener("click", () => {{
    i = 0; score = 0; missed = [];
    Q.forEach(q => delete q.order);   // reshuffle every option on a fresh run
    render();
  }});
  tally.innerHTML = "<b>" + score + "</b>/" + Q.length + " correct";
}}

render();
</script>
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("lab")
    ap.add_argument("--artifact-out", help="also write a copy here (same content)")
    args = ap.parse_args()

    lab = pathlib.Path(args.lab.rstrip("/"))
    spec = json.loads((lab / "quiz.json").read_text())

    for n, q in enumerate(spec["questions"], 1):
        if not 0 <= q["answer"] < len(q["options"]):
            sys.exit(f"question {n}: answer index {q['answer']} out of range")

    html = TEMPLATE.format(
        title=spec["title"],
        eyebrow=spec["eyebrow"],
        intro=spec["intro"],
        footer=spec.get("footer", ""),
        n=len(spec["questions"]),
        questions=json.dumps(spec["questions"], indent=1),
    )

    out = lab / "docs" / "exam-quiz.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html)
    print(f"wrote {out} ({len(spec['questions'])} questions, {len(html)} bytes)")

    if args.artifact_out:
        pathlib.Path(args.artifact_out).write_text(html)
        print(f"wrote {args.artifact_out}")


if __name__ == "__main__":
    main()
