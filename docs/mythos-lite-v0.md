# mythos-lite v0 design

A manual scaffold that externalizes what Mythos does in-model, so out-of-the-box models (Opus 4.7, GPT-5.5) can do similar work.

Last updated: 2026-05-27. Design only — no code yet.

## Anthropic-published guidance this design follows

Cross-checked against Anthropic's own engineering / research posts before locking the design:

- **[Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)** — workflow vs. agent distinction; orchestrator-workers pattern named; "start simple, add complexity only when it demonstrably improves outcomes."
- **[When to use multi-agent systems (and when not to)](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them)** — the verification subagent pattern, the "telephone game" warning, the artifact pattern.
- **[Multi-Agent Coordination Patterns](https://www.anthropic.com/engineering/multi-agent-coordination-patterns)** (April 2026) — names 5 patterns: Generator-Verifier, Orchestrator-Subagent, Agent Teams, Message Bus, Shared State. Recommended starting point: Orchestrator-Subagent.
- **[Harness Design for Long-Running Applications](https://www.anthropic.com/engineering/harness-design-long-running-apps)** — planner/generator/evaluator three-agent architecture; **evaluator gets tools (Playwright MCP)**, not text-only review.
- **[How we contain Claude across products](https://www.anthropic.com/engineering/how-we-contain-claude)** — environment-layer containment first, model layer second; deterministic boundaries beat probabilistic ones.
- **[Making Claude Code more secure and autonomous with sandboxing](https://www.anthropic.com/engineering/claude-code-sandboxing)** — Seatbelt (macOS) + bubblewrap (Linux), filesystem AND network isolation required together, 84% prompt reduction.
- **[Securely deploying AI agents](https://code.claude.com/docs/en/agent-sdk/secure-deployment)** — the sandbox ladder: built-in bash sandbox → `sandbox-runtime` → Docker → VM. **For untrusted code evaluation, Anthropic explicitly recommends Docker or VM.**
- **[Claude Code Security](https://www.anthropic.com/research/claude-code-security)** — the productized version of what mythos-lite is. Multi-stage verification, model re-examines its own findings, severity rating + confidence rating, human-in-the-loop final approval, same model (Opus 4.7) for hunter and re-examiner.
- **[Project Glasswing initial update](https://www.anthropic.com/research/glasswing-initial-update)** — Mythos's actual scaffold being shipped to partners includes Skills (custom instructions), a Harness (map codebase + spin subagents + triage + report), and a Threat Model Builder.
- **[Claude Mythos Preview System Card](https://www-cdn.anthropic.com/08ab9158070959f88f296514c21b7facce6f52bc.pdf)** §3.1, §3.3.3, §4.2.3, §7 — the in-model behavior we're externalizing.

Our scaffold uses 3 of Anthropic's 5 named coordination patterns:
- **Orchestrator-Subagent** = coordinator → parallel hunters (Phase 4)
- **Generator-Verifier** = hunter → cross-model validator (Phase 4 → 5)
- **Shared State** = SQLite engagement graph (Phases 4–7 all write here)

## Goal

Externalize Mythos's in-model behavior for models that don't have it built in:

| Mythos does in-model | mythos-lite externalizes as |
|---|---|
| Plans what to look at next | Explicit planner pass — one Opus call, max thinking, emits a job queue |
| Spawns subagents with one job each | Python coordinator that fans out N parallel Claude Code CLI sessions |
| Directs subagents, catches wrong conclusions | Cross-model validator (GPT-5.5 reviewing Opus output) + skeptical re-read |
| Holds plan + facts + rejected candidates in 1M ctx | SQLite engagement graph (6 tables, FareedKhan-style) |
| Uses sanitizers/shells/debuggers via tool calls | Tool sandbox — docker or scratch dir with target + ASan/UBSan + gdb |
| Proves the bug by writing and running a PoC | Executable verification gate — Python subprocess that must exit 0 on sentinel |

## Non-goals (v0)

- Chain reasoner / attack-graph builder (FareedKhan C10) — defer to v1
- Patch generator with chain-severance proof (C11) — defer
- Speculation / COW workspace (C12) — defer
- Variant hunter with CVE-signature seeds (C9) — defer; need per-target catalog
- Live exploitation beyond a sentinel-write PoC — out of scope, defensive only

## Pipeline (7 phases)

```
0  Language detection         → reuse Keyvanhardani lib
1  Sink slicing               → reuse Keyvanhardani lib + sinks/
2  File ranking               → reuse Keyvanhardani Python ranker
3  Engagement plan            → one Opus 4.7 call, max thinking, emits worklist
4  Parallel hunters           → Claude Code CLI session per file × pass-at-k
   ↓
5  Cross-model validator      → GPT-5.5 reviews each finding against source
   ↓ (HIGH/CRITICAL only)
6  Executable verifier        → real Python subprocess, sentinel-write PoC
7  Aggregate + FP memory      → summary.json + dismissals writeback
```

Phases 0-2 are lifted from Keyvanhardani verbatim. Phases 3-7 are the new work.

## Engagement graph (SQLite)

Schema lifted from FareedKhan with two additions (`dismissals`, `runs`). Single file `runs/<scan_id>/engagement.sqlite`:

```sql
CREATE TABLE runs (
    scan_id TEXT PRIMARY KEY, target_dir TEXT, target_id TEXT,
    started_ts REAL, ended_ts REAL,
    model_hunter TEXT, model_validator TEXT,
    pass_at_k INTEGER, budget_usd REAL
);

CREATE TABLE surface (
    id INTEGER PRIMARY KEY, kind TEXT, path TEXT, detail TEXT,
    source TEXT, ts REAL
);

CREATE TABLE facts (
    id INTEGER PRIMARY KEY, content TEXT, source TEXT, ts REAL
);

CREATE TABLE hypotheses (
    id INTEGER PRIMARY KEY, target TEXT, vuln_class TEXT, claim TEXT,
    status TEXT,  -- open | testing | confirmed | refuted | won_t_fix
    poc_sketch TEXT, source TEXT, ts REAL
);

CREATE TABLE findings (
    id INTEGER PRIMARY KEY, hyp_id INTEGER REFERENCES hypotheses(id),
    severity TEXT,  -- CRITICAL | HIGH | MEDIUM | LOW
    cwe INTEGER, title TEXT, file TEXT, lines TEXT,
    poc_path TEXT, evidence TEXT,
    corroborator_models TEXT,  -- JSON array
    verifier_result TEXT,  -- PASS | FAIL | NOT_RUN
    ts REAL
);

CREATE TABLE dead_ends (
    id INTEGER PRIMARY KEY, target TEXT, why TEXT, source TEXT, ts REAL
);

CREATE TABLE dismissals (
    id INTEGER PRIMARY KEY, target_id TEXT, sink_file TEXT, sink_line INTEGER,
    sink_function TEXT, reason TEXT, scan_id TEXT, ts REAL
);
```

`dismissals` is the cross-session FP memory keyed by `target_id = sha256(target_dir)[:16]`. Survives across runs; preloaded into hunter prompts.

## Audit log (hash-chained JSONL)

`runs/<scan_id>/audit.jsonl` — one event per line, each event includes `prev_hash` (SHA-256 of previous full line) so the chain is tamper-evident.

```json
{"ts": "...", "scan_id": "...", "type": "phase_start", "phase": 3, "prev_hash": "..."}
{"ts": "...", "scan_id": "...", "type": "hunter_launch", "file": "src/foo.c", "k": 1, "model": "claude-opus-4-7", "prev_hash": "..."}
{"ts": "...", "scan_id": "...", "type": "hunter_done", "file": "src/foo.c", "k": 1, "findings": 2, "cost_usd": 0.42, "prev_hash": "..."}
{"ts": "...", "scan_id": "...", "type": "validator_verdict", "hyp_id": 17, "verdict": "FALSE_POSITIVE", "prev_hash": "..."}
{"ts": "...", "scan_id": "...", "type": "verifier_result", "hyp_id": 19, "result": "PASS", "exit": 0, "prev_hash": "..."}
```

## Hunter (Phase 4)

Closest to Mythos. One `claude -p` session per (file, k) — Opus 4.7 with Read/Grep/Glob, plus Bash/Edit/Write if the build sandbox is ready.

**Inputs to the prompt** (assembled by coordinator):
- Mission brief (from `prompts/hunter.md`)
- Per-language VSP — vulnerability scanning playbook (reuse Keyvanhardani's `vsp-c-cpp.md` / `vsp-python.md` / etc.)
- Pre-computed sink list for this file (filtered from `slices/sinks.ndjson`)
- Cross-session dismissals block — "don't re-flag these"
- Focus hint (only when k>1) — rotates through detected sink categories and large-named functions to force diversity
- Sandbox descriptor JSON (if Phase 2.5 built one)

**Output**: strict JSON `{"findings": [{...}]}` or `{"verdict": "CLEAN"}`. Each finding has: title, severity, cwe, file, lines, vuln_class, primitive, reasoning, suggested_repro.

**Budget**: $3 per hunter call, 60 max turns. `--permission-mode bypassPermissions`, `--add-dir $TARGET_DIR` (and `--add-dir $SCRATCH` if sandbox).

**Parallelism**: Python `asyncio.gather` over file × pass-at-k, capped at `--max-concurrent` (default 4). Each hunter writes its JSON to `runs/<scan_id>/findings/<slug>__k<n>.json` and inserts hypotheses into the engagement graph via a coordinator queue.

## Cross-model validator (Phase 5)

Different model from the hunter — forces independent verification. GPT-5.5 via OpenAI SDK (`responses` API).

**Inputs**:
- Hunter's finding JSON
- Validator system prompt — *"You are an independent skeptic. The hunter is wrong by default. Demote unless every claim verifies against source."*
- Source file content (the validator does NOT have tools — text-only review for cost reasons)
- Dismissals block

**Output**: per-finding verdict — `CONFIRMED` / `DEMOTED` / `FALSE_POSITIVE` / `INSUFFICIENT_INFO`, plus adjusted_severity, missed_mitigations, exploitability_notes.

**On disagreement** (hunter HIGH, validator FALSE_POSITIVE): run a third call — Opus 4.7 moderator with both transcripts, decides. Cap one moderator call per finding to limit cost.

**Budget**: $1 per validator call.

## Executable verifier (Phase 6)

Only runs for findings the validator marked `CONFIRMED` at HIGH or CRITICAL. The verifier:

1. Asks Opus 4.7 (in the same hunter Claude Code session, but a fresh sub-call) to write a PoC Python script
2. PoC must write a sentinel file to a fixed path (`/tmp/mythos-lite-sentinel-<hyp_id>`) when the sink fires
3. Run the PoC as a Python subprocess inside the sandbox with a 60s timeout
4. PASS if exit 0 AND sentinel exists AND (for memory bugs) ASan/UBSan output present
5. FAIL otherwise — hypothesis is refuted, finding demoted

This is FareedKhan C8 but with model-generated PoCs instead of hand-written ones bound to hypothesis IDs (his approach doesn't generalize past MLflow).

**Budget**: $2 per verifier attempt, max 3 retries.

## FP memory (Phase 7)

After aggregate, walk validated findings:
- `verdict=FALSE_POSITIVE` → insert into `dismissals` table with `sink_file`, `sink_line`, `sink_function`, `reason`
- Next run on the same `target_id` preloads these into the hunter prompt

This is Keyvanhardani's dismissals pattern, normalized into SQL.

## File layout

```
~/Developer/claude-mythos-re/mythos-lite/        # the scaffold itself
  pyproject.toml
  mythos_lite/
    __init__.py
    cli.py              # entry: python -m mythos_lite scan <target>
    config.py
    coordinator.py      # asyncio fan-out of hunters → validators → verifier
    graph.py            # SQLite engagement graph helpers
    audit.py            # hash-chained JSONL writer
    sinks.py            # wrapper around Keyvanhardani sink slicer
    ranker.py           # file ranker (TIER A/B/C, vendor penalty)
    hunter.py           # claude -p session driver
    validator.py        # GPT-5.5 + Opus moderator
    verifier.py         # subprocess PoC gate
    sandbox.py          # build sandbox setup (C/C++ with ASan)
    cost.py             # per-model meter
  prompts/
    hunter.md
    validator.md
    moderator.md
    verifier-poc.md
    vsp-c-cpp.md        # copied from Keyvanhardani
    vsp-python.md
    vsp-js-ts.md
    vsp-php.md
  sinks/                # copied from Keyvanhardani scripts/lib/sinks/
  runs/<scan_id>/
    engagement.sqlite
    audit.jsonl
    slices/sinks.ndjson
    findings/<slug>__k<n>.json
    validated/<slug>.json
    pocs/<hyp_id>.py
    sandbox/
    summary.json
```

## Run command

```
python -m mythos_lite scan <target-dir> \
  --hunter-model claude-opus-4-7 \
  --validator-model gpt-5.5 \
  --max-files 8 \
  --pass-at-k 3 \
  --max-concurrent 4 \
  --hunter-budget 3.00 \
  --validator-budget 1.00 \
  --verifier-budget 2.00 \
  --total-budget 30.00 \
  --skip-verify          # optional, skip executable verifier
  --no-fp-memory
```

## Cost model

Per file × k=3, single language target (~10K LOC):

| Phase | Calls | Per-call $ | Subtotal |
|---|---|---|---|
| 3 plan | 1 Opus max-thinking | ~0.50 | 0.50 |
| 4 hunters | 8 files × k=3 = 24 Opus sessions | 0.50–3.00 (cap) | ~24 |
| 5 validators | ~30 findings × GPT-5.5 | ~0.30 | ~9 |
| 5 moderators | ~5 disputes × Opus | ~0.50 | ~2.5 |
| 6 verifiers | ~5 HIGH/CRIT × Opus | ~1.00 | ~5 |
| **Total** | | | **~$40** per 10K-LOC target |

Higher than Keyvanhardani's $1.50 (single-model, no validator) and higher than FareedKhan's $10.50 (no real hunter tools). The cost is in the **real Claude Code hunter sessions** — which is also where the capability is.

For initial testing, can drop `--pass-at-k 1` and skip verifier for ~$10/run.

## What this scaffold does NOT promise

- It does not match Mythos's exploit-construction capability (system card §3.3.3). That's a model capability gap, not a scaffold gap.
- It does not chain bugs together. A finding is per-bug, not per-attack-graph. v1 work.
- It does not generate patches. v1 work.
- It does not catch bugs that require deep cross-file dataflow beyond what the hunter can grep in 60 turns. The engagement graph helps but doesn't fix this.
- It will not beat Keyvanhardani's $1.50 cost or FareedKhan's notebook completeness. It optimizes for **honesty about what each model can do without Mythos's in-model orchestration**.

## Design decisions informed by Anthropic's published guidance

### Sandbox tech — DECISION: Docker as primary, sandbox-runtime as fallback

Anthropic's [Secure Deployment guide](https://code.claude.com/docs/en/agent-sdk/secure-deployment) explicitly says: *"Use this approach [Docker / VM] when you are evaluating untrusted code, when your security policy requires kernel-level separation between the agent and the host."* Vulnerability research on unknown source trees = evaluating untrusted code. Therefore:

**Primary**: Docker container per scan with:
- `--network none` (no network egress; vuln research doesn't need it)
- Target source mounted read-only
- Scratch dir mounted writable for builds + PoC outputs
- ASan/UBSan/gdb pre-installed in image
- Resource limits: 4 GiB RAM, 10 GiB disk, 2 CPUs (per [Hosting the Agent SDK](https://code.claude.com/docs/en/agent-sdk/hosting) baseline scaled for build workloads)

**Fallback** (no docker): `@anthropic-ai/sandbox-runtime` — Seatbelt on macOS, bubblewrap on Linux, both open-sourced by Anthropic, 84% prompt reduction reported in production Claude Code use. Filesystem + network policy via JSON allowlist. ASan still works on Linux; macOS Seatbelt is fine for non-binary targets (Python/JS/PHP).

Rejecting **plain scratch dir** (Keyvanhardani v4 default) — Anthropic's own guidance is that for evaluating arbitrary code you need *both* filesystem and network isolation, and scratch-dir alone gives neither. Keyvanhardani gets away with it because the Research Edition holds back the live-exec phase; we want the verifier from day one.

### Validator tool access — DECISION: give the validator Read/Grep/Glob

[When to use multi-agent systems](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them) on the verification subagent pattern: *"the verifier… [gets] the artifact to verify, clear success criteria, and tools to perform verification."* The Harness Design post is even more explicit — the evaluator uses Playwright MCP to *actually drive the running application*. Anthropic also flags the failure mode that decides this: *"The most significant failure mode for verification subagents is marking outputs as passing without thorough testing."* A text-only validator can't verify file:line claims and will rubber-stamp by default.

Therefore:
- **Validator tools**: Read, Grep, Glob (file:line claim verification)
- **Validator does NOT get**: Bash, Edit, Write (no need; verifier role does execution)
- **Prompt must include** (per Anthropic's guidance):
  - Concrete criteria — *"Verify every file:line claim by Reading the file. If a cited line does not contain what the report says, mark FALSE_POSITIVE."*
  - Negative tests — *"If you cannot find concrete evidence in source, mark INSUFFICIENT_INFO, not CONFIRMED."*
  - Explicit instruction — *"You MUST cite the exact line numbers you read before issuing a verdict."*

This matches Keyvanhardani's validator phase exactly (same tool set, same skeptical framing), so the precedent works.

### Single-model vs cross-model — DECISION: single-model with fresh-context Opus for v0, cross-model in v1

[Claude Code Security](https://www.anthropic.com/research/claude-code-security) is Anthropic's productized version of what mythos-lite does — and it uses **Opus 4.7 for both the hunter and the re-examiner** (same model, fresh context). The [multi-agent guide](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them) confirms: *"more capable orchestrator models (like Claude Opus 4.5) are increasingly able to evaluate subagent work directly without a separate verification step. However, verification subagents remain valuable when… you want to enforce explicit verification checkpoints in your workflow."*

So **v0 = same model (Opus 4.7), fresh context, different role prompt**. This matches Claude Code Security's pattern exactly. Cross-model validation (Opus hunter + GPT-5.5 validator) becomes a **v1 add-on** when we want orthogonal coverage of single-model blind spots — not a v0 requirement. Cost reduction: ~30% (no GPT calls + simpler dispatch).

### Findings schema — ADD confidence field

Claude Code Security exposes *"a confidence rating for each finding"* separate from severity. We mirror that:

```json
{
  "title": "...",
  "severity": "CRITICAL | HIGH | MEDIUM | LOW",
  "confidence": "HIGH | MEDIUM | LOW",
  "cwe": 122,
  ...
}
```

Hunter sets initial confidence; validator can demote it on insufficient evidence even if the bug is real-looking. Verifier-passing findings get auto-promoted to confidence HIGH.

### Add a threat model builder (Phase 3 enhancement)

Glasswing's actual scaffold includes a *"threat model builder, which maps a codebase to identify potential targets for attack and prioritizes the model's work accordingly."* This is what our Phase 3 engagement planner already is, but we should explicitly add a threat-model output before the worklist:

```
Phase 3a — threat model: one Opus call, max thinking, reads README/sink summary
            emits: trust boundaries, untrusted inputs, sensitive operations, attack surface map
Phase 3b — engagement plan: second Opus call, takes threat model as input,
            emits prioritized worklist for hunters
```

Threat model output writes to `surface` table in the engagement graph. Hunters get the relevant surface entries in their context packet.

### Artifact pattern enforced everywhere

[Anthropic's multi-agent post](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them) and [Fountain City's analysis](https://fountaincity.tech/resources/blog/anthropic-multi-agent-blueprint-production/) both name the **artifact pattern** as the antidote to the telephone game. Subagents write structured artifacts to disk + return lightweight references; coordinator never re-reads full hunter transcripts. We enforce:
- Each hunter writes `findings/<slug>__k<n>.json` (artifact)
- Hunter returns to coordinator: `{"finding_count": N, "highest_severity": "...", "path": "findings/..."}` (reference)
- Coordinator inserts hypotheses by reading the artifact path, not the model's chat response
- Same pattern between validator → verifier (validator writes `validated/<slug>.json`, verifier reads the artifact)

### Human-in-the-loop is the final gate

Claude Code Security: *"Nothing is applied without human approval."* mythos-lite v0 ends at `summary.json` + the engagement graph. **No automatic disclosure, no automatic patching.** The user reviews validated findings → decides what to escalate to maintainers per the CVD policy (see `docs/disclosure-policy.md`, todo).

## Remaining decisions — LOCKED 2026-05-27

### Pass-at-k — DECISION: k=3 (Keyvanhardani's v4 default)

Three hunter passes per file, each with a rotated focus hint (one of the file's top sink categories or a large-named function). Cache-warm runs amortize the cost; Anthropic's own pre-Mythos research noted that *"sampling diverse traces from the same input dramatically increases bug-discovery breadth"* (also surfaced via Keyvanhardani's `--pass-at-k K` rationale). Override available via `--pass-at-k N` at run time.

### Engagement graph scope — DECISION: persistent per-target

One SQLite at `engagements/<target_id>/engagement.sqlite` per target (`target_id = sha256(target_dir)[:16]`). Scans append rows; the `runs` table separates them. Benefits the hunter via accumulated `surface`, `facts`, `dead_ends`, and `dismissals` — closer to Mythos-style in-context memory accumulation than Keyvanhardani's per-scan filesystem or FareedKhan's notebook-scoped DB.

Coordinator on session start:
1. Open or create `engagements/<target_id>/engagement.sqlite`
2. Insert a fresh row in `runs`
3. Read prior `surface`, `facts`, `dead_ends`, `dismissals` for context-packet assembly
4. New `hypotheses`/`findings`/`chains` are tagged with the current `scan_id`

Schema addition over the original draft — every row gets a `scan_id` foreign key for run-level filtering.

### Verifier PoC autonomy — DECISION: model writes PoC in a fresh Claude Code session

For each HIGH/CRITICAL finding the validator confirmed, the verifier opens a **separate short Claude Code session** (Opus 4.7, Bash/Write/Edit allowed inside the docker sandbox) with:
- The validated finding JSON
- The relevant source slice
- A verifier-role system prompt — *"Write a Python PoC that exercises the sink. On sink fire, write the sentinel file `/work/sentinel-<hyp_id>`. Exit 0 on success."*
- Build sandbox descriptor (target compiled binary path, ASan env vars, etc.)
- Budget: $2/attempt, 30 turns, 3 max retries

Verifier writes `pocs/<hyp_id>.py` artifact + returns to coordinator: `{"hyp_id": ..., "result": "PASS|FAIL|TIMEOUT", "exit": N, "sentinel_written": bool, "asan_output": "..."}`.

Closer to what the system card emphasizes (§3.3.3): *"develop the identified vulnerabilities into working proof-of-concept exploits."* Model-generated PoCs adapt to per-bug specifics that templates can't cover (e.g., the system card's Firefox 147 case where the model "leverages four distinct bugs" — that diversity can't be templated).

Cost note: this is the single most expensive phase. Mitigations:
- Skip-by-default for MEDIUM and below
- `--skip-verify` flag for cheap exploratory runs
- Cache: if a hypothesis with the same `(file, vuln_class, primitive)` already has a passing PoC in the graph, reuse it

### Threat-model gate — DECISION: soft (worklist first, override on high sink density)

Phase 3 emits two outputs:

1. **Worklist** (priority 1): files the threat model builder selected from trust boundaries / sensitive operations. Hunter starts here.
2. **Follow-up queue** (priority 2): files NOT in the worklist whose TIER_A sink count exceeds a threshold (default: ≥3 distinct TIER_A categories). Hunter pulls from this queue after the worklist if `total_budget` permits.

A simple check at coordinator dispatch time: `if remaining_budget > avg_hunter_cost * 2 and worklist_done: dispatch follow_up_queue`. The model-decides flavor of Mythos without giving up Glasswing's threat-driven prioritization. Override via `--strict-worklist` or `--no-threat-model` flags.

Implementation: both lists go into the `surface` table with a `priority` column. Coordinator reads sorted by priority.

## Cost model — updated for v0 decisions

Per file × k=3, single-language target ~10K LOC, with the decisions above:

| Phase | Calls | Per-call $ | Subtotal |
|---|---|---|---|
| 3a threat model | 1 Opus max-thinking | ~0.50 | 0.50 |
| 3b plan | 1 Opus | ~0.30 | 0.30 |
| 4 hunters (worklist) | 8 files × k=3 = 24 Opus sessions | 0.50–3.00 | ~24 |
| 4 hunters (follow-up) | ~3 files × k=3 = 9 sessions (budget-dependent) | 0.50–3.00 | ~9 |
| 5 validators | ~40 findings × Opus fresh-ctx (single-model) | ~0.30 | ~12 |
| 6 verifiers | ~5 HIGH/CRIT × Opus Claude Code session | ~2.00 | ~10 |
| **Total** | | | **~$56** per 10K-LOC target with full settings |

Cheaper variants:
- `--pass-at-k 1 --skip-verify`: ~$15
- `--pass-at-k 1`: ~$25
- `--strict-worklist`: ~$45 (drops follow-up queue)

Higher than Keyvanhardani's $1.50 (single-model, no validator, no verifier) and higher than FareedKhan's $10.50 (no real hunter tools, hand-written PoCs). The cost is in:
1. Real Claude Code hunter sessions with tools
2. Real Claude Code verifier sessions with model-generated PoCs
3. k=3 diversity

This is the **honest cost of externalizing Mythos's in-model behavior**. Mythos itself does all of this in one $25-input-token-per-M context. We're paying ~$56 for what Mythos does for cents because we have to spin up fresh Claude Code processes for parallelism + fresh context for verification — the things Mythos handles in a single agentic loop.

## v0 build order (when we move from design to code)

1. `mythos_lite/graph.py` — SQLite engagement graph + audit log writer (no model calls; deterministic)
2. `mythos_lite/sandbox.py` — Docker container management with `--network none`
3. `mythos_lite/sinks.py` + `ranker.py` — wrap Keyvanhardani's sink slicer + ranker
4. `mythos_lite/hunter.py` — `claude -p` session driver with focus-hint rotation
5. `mythos_lite/validator.py` — fresh-context Opus validator with Read/Grep/Glob
6. `mythos_lite/verifier.py` — fresh Claude Code session with Bash/Write/Edit in sandbox
7. `mythos_lite/threat_model.py` — Phase 3a builder
8. `mythos_lite/coordinator.py` — asyncio orchestration tying it all together
9. `mythos_lite/cli.py` — `python -m mythos_lite scan` entry point
10. End-to-end smoke test on a small fixture (e.g., a known-vulnerable jq snapshot)

The order matters: graph + sandbox + sinks are deterministic foundations that need to be solid before any model-calling code is written. Following Anthropic's "start simple, measure, then add complexity" rule.
