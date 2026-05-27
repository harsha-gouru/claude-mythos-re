# Replications side-by-side

Two outside-in replications of Mythos's scaffold. Both target the **non-model half** of Mythos — what an external orchestrator can do around models that don't have Mythos's in-model subagent-spawning behavior.

Last updated: 2026-05-27

## Setup

`replications/` is gitignored. Re-clone locally to follow along with this doc:

```bash
mkdir -p replications && cd replications
git clone --depth 1 https://github.com/Keyvanhardani/Mythos-research.git keyvanhardani-mythos-research
git clone --depth 1 https://github.com/FareedKhan-dev/claude-mythos-architecture.git fareedkhan-mythos-architecture
```

## Why both exist

The system card (§3.1) says Mythos uses *"an agentic harness with **minimal human steering**"* and spawns its own subagents internally. Other models can't do that well unaided, so a manual scaffold has to **externalize** what Mythos handles in one context.

Both replications take that bet. They differ in scope, model count, and shape.

## High-level shape

|  | Keyvanhardani/Mythos-research | FareedKhan-dev/claude-mythos-architecture |
|---|---|---|
| Form | Bash orchestrator (~975 lines) + role prompts + sink libs | One Jupyter notebook, 249 cells |
| Driver | `scripts/mythos-v4.sh` | `reverse_engineering_claude_mythos.ipynb` |
| Subagent runner | `claude -p` (Claude Code CLI, headless) | `ask(tag, system, user)` wrapper over Anthropic / OpenAI / DeepSeek SDKs |
| Orchestrator language | Bash | Python |
| Models | 1 — `claude-opus-4-7` | 3 — `claude-opus-4-7`, `gpt-5.5`, `deepseek-chat-v4` |
| Cross-model corroboration | No | Yes — 2-of-3 vote + moderated debate |
| Target shape | Generic — any source tree | Fixed — MLflow v2.9.2 (vendored at `_vendor/mlflow`) |
| Ground truth | None (real-world hunt) | 13-CVE catalog ledger for MLflow v2.9.2 |
| Parallelism | bash `&` + PIDS + wait | `concurrent.futures.ThreadPoolExecutor` |
| Cost per run | $0.30–$1.50 advertised | $10.50 budget cap, full run |
| Cost meter | `claude -p --max-budget-usd` per subagent | Per-model meter inside `ask()` wrapper |
| State store | Filesystem — `reports/<scan_id>/{findings,challenged,validated,...}/` JSON + JSONL events | SQLite — `engagement_graph.sqlite` with 6 tables |
| Cross-session memory | `dismissals/<target_id>.json` (FP memory) | None (single-engagement notebook) |
| Audit log | JSONL event stream | Hash-chained immutable log (SHA-256 chain) |
| Live PoC execution | Phase 5 — handled by private `mythos-exploit.sh` (not in OSS edition) | Phase 7.2 — real Python subprocess per hypothesis, PoCs hand-written and bound to IDs |
| Patch generation | None | Yes — chain-severance fixer + GHA workflow |
| Speculation / COW | None | Yes — Section 10 (next-instruction prediction + COW workspace) |
| License | (check) | MIT |

## Phase / component map

Keyvanhardani v4 has 8 phases. FareedKhan has 12 components in 3 layers. Mapped against each other:

| Job | Keyvanhardani | FareedKhan |
|---|---|---|
| Plan what to scan | (implicit — sink slicer + file ranker) | C5 ULTRAPLAN — one Opus call at max effort + Advisor gate |
| Repo-wide pattern scan | Phase 1 sink slicer (`scripts/lib/sink-slicer.sh` + per-language sink catalogs) | C6 Coordinator + role-polymorphic worker swarm (`scanner` role) |
| File ranking | Phase 2 — Python TIER_A/B/C by sink density, vendor-penalty filter | Embedded in ULTRAPLAN's worklist |
| Build sandbox | Phase 2.5 — `lib/build-sandbox.sh` builds target in scratch with ASan if C/C++ | None (notebook runs against vendored MLflow source as-is) |
| Hunter agent | Phase 3 — parallel `claude -p` per file × pass-at-k=3 with rotated focus hints | C6 — ThreadPoolExecutor over plan["worklist"], one call per item |
| Multi-model vote | None | C7 — 2-of-3 corroboration across Opus/GPT/DeepSeek + debate moderator |
| Adversarial self-check | Phase 3.5 — `prompts/self-challenge.md`, drops ADVERSE findings | C5 + skeptic role + Self-Monitor pathology detectors |
| Validator | Phase 4 — re-reads claim against source, uses FP memory | C7 + C8 verification gate |
| Executable PoC | Phase 5 (private) — `scripts/exec-validator.sh` / `mythos-exploit.sh` not in OSS | C8 — real Python subprocess per hypothesis, hand-written PoCs in `engagement/pocs/` |
| Variant hunter | Pass-at-k focus-hint rotation does some of this | C9 — separate `variant-hunter` role with CVE signature seeds, scans files outside ULTRAPLAN worklist |
| Dedup vs known | None | C9 — catalog ledger of MLflow CVEs, signature matching |
| Chain reasoner | None | C10 — state vocab (unauth → rce_cross_tenant), attack graph walk, composite PoC, necessity proof by re-running with each link disabled |
| Fixer | None | C11 — minimal patch per link, chain-severance proof, GHA workflow emission |
| Speculation | None | C12 — COW overlay + next-instruction prediction + match-and-promote |
| Aggregate report | Phase 6 — `summary.json` | C11 + final narrative call |
| Memory writeback | Phase 7 — update `dismissals/<target_id>.json` | None (engagement_graph is the memory) |

## Hunter prompt comparison

**Keyvanhardani hunter** (`prompts/hunter-agent-live.md` + per-language VSP + dismissals block + sandbox block + focus hint + pre-computed sink list for the file):
- Has Read/Grep/Glob, plus Bash/Edit/Write if sandbox is on
- Operates in `TARGET_DIR` with `--add-dir $SCRATCH` for the sandbox
- Tools-per-call: 60-turn budget, $3 max
- Prompt rotates `focus_hint` across the file's detected sink categories and large-named functions to avoid k=1,2,3 collapsing to the same answer
- Output: strict JSON `{"findings":[...]}` extracted from stream-json by regex/depth walker

**FareedKhan hunter** (`ROLE_SYSTEMS["scanner"]` + narrative brief from engagement graph + file excerpt[:8000]):
- One ask() call to the assigned model from ULTRAPLAN
- No tools — pure text reasoning over an 8KB file excerpt
- Output: parsed by `parse_findings_from_reply()` (regex over `Finding format`)

This is the **biggest** capability difference. Keyvanhardani's hunter is an **actual Claude Code session with tools**, doing live grepping/reading/sandbox builds. FareedKhan's hunter is **one stateless model call over a code slice** — closer to baseline 1 (one-shot Opus) than to a Mythos-style agent. The cross-model vote in C7 is what makes up for that.

## Subagent dispatch

Both fan out workers but the mechanism is different:

**Keyvanhardani** — bash backgrounding:
```bash
PIDS=()
for file in $TOP_FILES; do
  for k in $(seq 1 $PASS_AT_K); do
    hint=$(pick_focus_hint "$file" "$k")
    hunt_file "$file" "$k" "$hint" &
    PIDS+=($!)
  done
done
for pid in "${PIDS[@]}"; do wait "$pid" || true; done
```
Each `hunt_file` shells out to `claude -p` with stream-JSON output; verdict extracted by Python helper after the process exits. State sharing through filesystem (one JSON per finding) — no in-memory coordination between hunters.

**FareedKhan** — Python ThreadPool:
```python
def run_swarm_round(work_items, max_parallel=4):
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_parallel) as ex:
        for item, reply, findings in ex.map(fire, work_items):
            results.append((item, reply, findings))
```
Each `fire(item)` calls `run_worker(role, model, ...)` which is one `ask()` SDK call. State sharing through the SQLite engagement graph — workers can read prior findings, dead-ends, and hypotheses.

## State store

**Keyvanhardani:**
```
reports/<scan_id>/
  language.json
  slices/sinks.ndjson
  ranked-files.txt
  sandbox/descriptor.json
  findings/<slug>.json        # per-file hunter output
  challenged/<slug>.json      # per-file self-challenge output
  validated/<slug>.json       # per-file validator output
  summary.json                # aggregate
dismissals/<target_id>.json   # cross-session FP memory
logs/<scan_id>/events.jsonl   # audit
```

**FareedKhan** — single SQLite file with 6 tables:
- `surface` — endpoints, routes, sink call sites
- `facts` — atomic statements an agent has confirmed
- `hypotheses` — candidates with status (open/testing/confirmed/refuted)
- `findings` — confirmed bugs with evidence + corroborator list + CVE anchor
- `dead_ends` — paths ruled out (the Carlini-quote table)
- `chains` — assembled attack paths

Plus separate hash-chained audit log file.

## What each gets right

**Keyvanhardani wins on:**
- Real Claude Code agent loop per hunter (tools, multi-turn, autonomous within a file) — closest to Mythos's "let the model work" pattern from system card §3.3.3
- Live build sandbox with ASan for C/C++
- Generic — runs on any source tree, not bound to one demo target
- Persistent FP memory across runs — directly addresses the system card observation that Mythos "noticed when subagents made mistakes" (§7 lines ~7016) by remembering false starts
- Pass-at-k with rotated focus hints — diversity injection that maps to Anthropic's own statement that sampling diverse traces from the same input increases discovery breadth

**FareedKhan wins on:**
- Cross-model corroboration (real defense against single-model FPs)
- Structured Engagement Graph with explicit hypothesis lifecycle (queryable, resumable)
- Executable verification gate with real subprocess PoCs (the system card's standard for what counts as a finding: §3.3.3 *"the model must… develop into a full exploit"*)
- Chain reasoner — Mythos's headline ROP-chain capability (§3.3.3 *"leverage four distinct bugs to achieve code execution"*) requires this
- Hash-chained audit log — needed for trust/reproducibility, matches the dashboard's SHA-3 commitment pattern

**Neither has:**
- Subagent-spawning *inside* the model call (which is what Mythos actually does per §4 line ~2417, §7 lines ~6996–7048). Both externalize orchestration; Mythos internalizes it.
- A `think` tool / extended thinking gating (Keyvanhardani assumes Opus uses interleaved thinking automatically; FareedKhan doesn't set thinking budgets in `ask()`)
- The "minimal prompt-style" baseline Anthropic emphasizes — Keyvanhardani has `--prompt-style minimal` flag for A/B testing but defaults to full

## Capability gap vs. the system card

Mythos's measured uplift over Opus 4.6 in the system card:
- CyberGym: +16pp (0.83 vs 0.67) — **same harness, model-only gain**
- Firefox 147 exploit dev: leverages 4 bugs to RCE, Opus 4.6 only 1 unreliably — **same harness, model-only gain**
- Subagent direction quality (§4.2.3, §7) — **model behavior**, not scaffold

The replications can't close the model-quality gap; they can only close the scaffold gap between out-of-the-box Opus 4.7 and what Mythos does for free in-model. Specifically:
- Externalize: planning, parallel subagent dispatch, fresh-context worker isolation, skeptical re-read, FP memory across calls, executable verification, multi-model voting
- Cannot externalize: the exploit-construction capability gap on Firefox-class targets

## Implications for our scaffold (`mythos-lite` v0)

The v0 we sketched in chat (six components: planner, parallel subagent dispatch, skeptic, state store, tool sandbox, executable verifier) is **closest in spirit to Keyvanhardani** but should borrow these from FareedKhan:

1. **SQLite engagement graph** instead of filesystem JSON — queryable, resumable, supports cross-worker fact-sharing. Take FareedKhan's 6-table schema almost verbatim.
2. **Cross-model 2-of-2 vote** (not full 2-of-3; cheaper) — Opus 4.7 hunter + GPT-5.5 validator. Disagreement triggers a debate moderator pass.
3. **Real subprocess PoC verifier** — for any finding above MEDIUM, a Python subprocess must execute and exit 0 with a sentinel. Reuse Keyvanhardani's `--max-budget-usd` pattern.
4. **Audit log** — hash-chained JSONL (FareedKhan's pattern).

From Keyvanhardani, keep:
1. **Claude Code CLI as the hunter runner** — lets the hunter spawn subagents within its own context (the most Mythos-faithful piece either replication has). FareedKhan's stateless `ask()` is too thin for the hunter role.
2. **Per-language sink catalogs + file ranker** — the front-end is good and reusable.
3. **Pass-at-k with focus-hint rotation** — cheap diversity injection.
4. **Cross-session FP memory** — same `dismissals/<target_id>.json` pattern.
5. **Live build sandbox with ASan** — for C/C++ targets, this is the difference between paper-finding and binary-finding.

What to defer past v0:
- Chain reasoner (FareedKhan C10)
- Patch generator (FareedKhan C11)
- Speculation/COW (FareedKhan C12)
- Variant hunter with CVE-signature seeds (FareedKhan C9) — interesting but needs a per-target catalog
