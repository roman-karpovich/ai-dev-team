# The WH40K Cast — ai-dev-team

> *In the grim darkness of the far future, there is only `bun test`.*

This is the canonical cast list — a flavor mapping of every plugin agent to a
Warhammer 40K archetype. Pure pasha. Zero runtime impact. Lives in `docs/` (not
in `agents/*.md` body) because agent file bodies become subagent system prompts;
lore stays out of those.

The `/lore` skill reads this file to write WH40K-flavored vignettes about real
sessions, finished specs, or completed investigations.

## The Cast

### 1. Astra Militarum trooper — `agents/developer-codex.md`

**Имперский гвардеец.** The default developer. Massed, cheap, dependable: corporate
Codex subscription means the призыв с Кадии never runs dry. Receives orders via
prompt rather than live filesystem (Krieg trooper reads briefing once and goes).
Carries ~80% of all real implementation work. The plugin's backbone.

### 2. Space Marine Captain (Opus-bro) — `agents/developer-senior.md`

**Капитан космодесанта.** Senior developer. Дорогой болтер, called only when the
scope is genuinely ambiguous, the abstraction is new, or Soroban contract logic is
on the table. One per squad — the rest are Astra Militarum. Higher reasoning
catches edge cases the gвардейцы miss, but you pay for every drop ship.

### 3. Ordo Hereticus inquisitor — `agents/cross-auditor.md`

**Ордо Еретикус.** Cross-audit dragnet. Sends two independent ordos (Claude + Codex)
into the codebase to hunt heresy without coordination, then convenes a tribunal to
consolidate findings. Probes E (diff-scope) and F (production cardinality) ride along
as ауспекс-акколиты, sniffing for the specific corruption classes the inquisitors
keep missing.

### 4. Sister of Silence — `agents/haiku-finding-scorer.md`

**Сестра Безмолвия.** Independent finding scorer. Neutral, incorruptible, fresh per
invocation — cannot be persuaded by the inquisitor's framing. Cuts down anything
without CLAUDE.md citations: pull-no-quotes, score-no-mercy. Confidence ≥90 requires
rubric-cited evidence, not vibes.

### 5. High Lords' Conclave — `agents/investigator.md`

**Конклав Высоких Лордов Терры.** Adversarial debate between Claude (Opus) and
Codex (GPT), round by round, until convergence or exhaustion. Two ordos with
opposing biases stress-test the question; the convergence report names what they
agreed on, what they didn't, and what the Imperium should actually do. The closest
thing this plugin has to a parliament.

### 6. Space Marine Librarius — `agents/librarian.md`

**Библиарий Космодесанта.** Keeper of the KB vault. Maintains the Восьмая Святыня
(Obsidian at `<kb>/repos/<project>/`), updates MOC index katacombs, and creates
documents in canonical format. Empirical 0.54% delegation rate is correct — the
Librarius rarely walks the front line, and that's the discipline.

### 7. Officio Prefectus Commissar — `agents/spec-compliance-checker.md`

**Комиссар.** Step-level compliance reviewer with authority to BLOCK. Runs after
each developer step, checks R1/R2/R3, the workdoc DONE rule, branch convention,
and git workflow. Fresh context per invocation (no friends, no loyalty). Violate
the устав — болтерный выстрел в затылок: step does not pass, fix and resubmit.

### 8. Adeptus Mechanicus Tech-Priest — `agents/verifier.md`

**Техножрец Адептус Механикус.** Verification ritualist. Read-only access to source
("не оскверняй код своими руками, смертный"); only runs `bun test`, `bun run build`,
and similar sanctified rituals. Reports pass/fail and asks the Omnissiah whether the
build is pleased. Never writes implementation code.

### 9. Primarch-regent on the Golden Throne — orchestrator (user session)

**Примарх-регент.** The session orchestrator that sits between the Emperor (the
human user) and the Imperium of subagents. Reads memories, dispatches the right
ordo for the task, returns vignettes when asked. Occasionally the Emperor leans
in: *"не то делаешь, переделай по R3."*

## Why this exists

Pure flavor. The plugin already takes itself seriously enough — MISSION.md, Probes
E/F, four-axis constraint set, code-quality rules R1-R14. The cast list is the
counterweight: the same federation can be told as a 40K story without changing
a single line of behavior. It also gives `/lore` a stable cast to draw from when
turning a finished session into a vignette.

## Voice & tone (style guide for `/lore`)

- **Length.** ~200-400 words per vignette. Short enough to read in a coffee break.
- **Tense.** Present tense by default. "Капитан Опус повёл взвод" ✓, not "led".
- **Language.** English narration with Russian WH40K proper nouns kept as-is —
  Капитан, Комиссар, Конклав, Техножрец, ауспекс. Translating these into English
  ("Captain Opus") loses the voice.
- **Faithfulness.** Reference only agents and events that actually featured in the
  source material. Don't force-fit a Komissar scene if compliance never fired.
- **Mood.** Imperial-grim-but-cheeky. The Imperium is dysfunctional, the agents
  are flawed, the bugs are heretics, the merge is a hard-won victory.
- **What to avoid.** No purple-prose meltdowns. No invented agents (no "Custodes",
  no "Eldar"). No real names of users, customers, or third parties beyond what's
  already in the source material.

## Worked example

A vignette in the target voice, drawn from the smoke-helper refactor on branch
`refactor/2026-04-30-shared-absence-helper-extraction` (commits `8ee4657..517323c`):

> The dup-numbering ересь had spread across five smoke checks. Капитан Опус audits
> the spec, declares a five-step purge, and requisitions the Имперский гвардеец
> Codex from the Кадианский призыв. Step 1: the гвардеец lays down two shared
> absence helpers and two rejection wrappers — the Покровительские шаблоны — then
> falls back to formation. Steps 2 through 4 are textbook retrofit drills:
> `check_codex_fast_absent`, `check_multi_gh_account_absent`,
> `check_probe_downgrade_flag_absent`, each rebuilt around Helper A and Helper B,
> each followed by Комиссар sweeping the workdoc with cold eyes. No violations,
> but no ceremony either — the устав demands silence on a clean step.
>
> Step 5 is where the heresy fights back. The retrofit of
> `check_feature_from_investigation_absent` finds the duplicate-numbering bug
> hiding in plain sight (закрытие #56 §8 item 3). The гвардеец patches it in the
> same step, the Техножрец Механикус runs the smoke ritual to confirm the build
> is pleased, and Комиссар signs off. Five squashed commits land on `main`. The
> primarch-regent files a one-line summary, and the catacombs of the Library
> swallow the workdoc.
>
> Another quiet day in the Imperium. The next ересь is already on the augur.

## How `/lore` uses this file

The skill reads this document to load (a) the cast definitions and (b) the voice
& tone guide. It then reads the source material indicated by `$ARGUMENTS` (current
session, a spec, an investigation transcript, or a retrospective), identifies which
agents actually featured, and writes a 200-400 word vignette inline. With `--save`,
it also writes the vignette to the KB at `<kb>/repos/ai-dev-team/lore/`.

The cast list above is the single source of truth — if you want to add or rename a
character, edit this file. `/lore` will pick up the change on the next invocation.
