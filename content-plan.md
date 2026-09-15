# iosClaw content plan for r/Codex

## Research scope

This plan is based on the most recent public `r/Codex` submissions available from Reddit’s `/new.json` listing on 2026-09-12, selecting the first 50 visible submissions without public removal markers. Public Reddit data does not expose a reliable “approved by moderator” timestamp for every post, so “approved” here means publicly visible and not marked removed at collection time.

Sources:

- [Recent r/Codex listing](https://www.reddit.com/r/codex/new.json?limit=100&raw_json=1)
- [Moderator notice about relevance enforcement](https://www.reddit.com/r/codex/comments/1ubc0oj/notice_rcodex_rolling_out_moderation_bots_today/)
- [Weekly Showcase thread](https://www.reddit.com/r/codex/comments/1wavxwy/show_us_all_what_youve_been_building_with_codex/)

## What the feed rewards

The current feed is not one single content category. It mixes:

1. **Concrete questions** — model choice, limits, plan mode, usage, caching, and setup.
2. **Evidence-heavy investigations** — logs, token counts, timings, configuration changes, and explicit methodology.
3. **Build stories** — what someone made with Codex, the problem, the implementation, and what changed during iteration.
4. **Workflow/configuration advice** — small snippets that another Codex user can try immediately.
5. **Product news and commentary** — announcements, plan changes, model comparisons, and reactions.
6. **Humor and visual posts** — screenshots, memes, or a short caption tied to Codex behavior.

The strongest examples are specific and personal. They explain what the author did, show enough evidence to be useful, acknowledge uncertainty, and end with a question that invites other users to compare results. Long posts can work when they contain measurements, logs, code, or a real build narrative; polished marketing copy without evidence is a poor fit.

## Why the original iosClaw post is vulnerable to removal

The original draft is relevant, but it reads like a product launch:

- The Codex-specific work arrives after a long product description.
- “Open-source runtime,” “use cases,” and a website link create a promotional signature.
- The post has many claims but few concrete artifacts from the Codex session.
- It is long enough to resemble generated promotional content.
- Reposting similar versions can look like spam even when the project is legitimate.

The subreddit’s moderator notice says its bot enforces direct relevance to Codex and expects comparative detail when comparisons are made. The subreddit also maintains a weekly thread specifically for projects built with Codex. Use that thread for the first iosClaw showcase rather than creating several standalone attempts.

## Positioning for iosClaw

### Category

**A Codex-built experiment in making LLM-powered iOS QA repeatable.**

Do not lead with “automation product,” “platform,” or “launch.” Lead with the engineering question:

> What should an LLM plan, and what should a deterministic runtime execute?

### Audience

- Codex users building agents or developer tools.
- iOS developers testing Simulator and real-device workflows.
- QA engineers dealing with flaky visual automation.
- People interested in MCP, agent safety, and record/replay systems.

### One-sentence positioning

> I used Codex to test whether an LLM can plan an iOS test while a local runtime handles the repeatable steps and verification.

### Proof to emphasize

- Codex helped implement and iterate the Mac SwiftUI app.
- The runtime observes iPhone Simulator or iPhone Mirroring.
- Semantic targets are resolved from live accessibility/visual evidence instead of stored tap coordinates.
- Recorded flows can be compiled so the model is not called between every known step.
- Each transition has a postcondition and ambiguity causes a safe stop.
- The current scope is intentionally small; the initial WhatsApp flow stops before Send.

### Claims to avoid

- “Works with every iOS app.”
- “Production-ready QA platform.”
- Unmeasured latency, reliability, or cost percentages.
- “Apple-approved” or “App Store compatible.”
- Implied ability to bypass passwords, OTPs, Face ID, CAPTCHA, or permissions.
- Comparisons that attack Codex, OpenAI, or another project.

## Content mix

Use this ratio over the first 10–12 posts/comments:

| Pillar | Share | Purpose | iosClaw examples |
|---|---:|---|---|
| Codex experiments | 35% | Show a question, method, and result | “Can Codex repair a flow after a layout change?” |
| Build logs | 25% | Share engineering decisions and trade-offs | “Why I split the LLM planner from the iPhone executor” |
| Reproducible workflows | 20% | Give readers something to try | Simulator setup, MCP call, record/replay format |
| Evidence and failures | 15% | Earn trust through limitations | Permission failure, duplicate selector, postcondition stop |
| Product/update notes | 5% | Announce meaningful milestones | New app adapter or release, only with evidence |

The first public post should be an experiment/build story, not an announcement that iosClaw exists.

## Post format

### Title formula

Use a direct, non-advertising title with “Codex” and one technical question or result:

- `Built an iOS QA runtime with Codex: LLM planning, deterministic replay`
- `I used Codex to test a different boundary for iOS automation`
- `Can Codex plan an iOS test without executing every tap itself?`
- `What I learned building semantic iOS record/replay with Codex`
- `I moved the repeated iOS steps out of the LLM loop`

Avoid:

- `Introducing iosClaw`
- `The future of iOS QA`
- `My revolutionary AI automation platform`
- Titles that contain only the product name or a launch verb.

### Body structure

1. **One-sentence itch** — a problem you personally hit.
2. **Codex connection** — what you asked Codex to design, implement, test, or critique.
3. **Small technical slice** — one flow, one adapter, one measurement, or one failure.
4. **Evidence** — a short log, config excerpt, screenshot, timing, or before/after.
5. **Honest limitation** — what still fails or is intentionally unsupported.
6. **Discussion question** — ask for another user’s experience or preferred boundary.

Aim for 180–450 words. Use short paragraphs and at most one small code/config block. Do not bury the Codex connection below a long product description.

### Link policy

- First post: no external link, or one link at the very bottom after the technical content.
- Prefer a repository link once the public source repository exists; the website is secondary.
- Do not repeat the same link in the title, body, and first comment.
- If the post survives and people ask for details, reply with the website/repository link once.

## First 12 content ideas

### 1. Boundary experiment

**Title:** `I moved the repeated iOS steps out of the LLM loop`

Show a short before/after: model-driven transitions versus a compiled local flow. Report what was measured and what was not.

### 2. Failure story

**Title:** `The iOS automation bug that made me stop storing tap coordinates`

Show a layout change or duplicate match and explain how semantic evidence plus a safe stop handled it.

### 3. Permission reality

**Title:** `What Codex helped me learn about macOS permissions for iPhone automation`

Explain Screen Recording versus Accessibility, what failed, and why the app does not try to work around either permission.

### 4. Simulator workflow

**Title:** `I asked Codex to drive a Simulator test, then made the replay deterministic`

Use one small synthetic app and include the exact test boundary and postcondition.

### 5. Record/replay design

**Title:** `Recording an iOS flow is easy; replaying it without stale state is not`

Explain semantic recording, run-only inputs, fresh capture, and state validation.

### 6. MCP experiment

**Title:** `I gave Codex a loopback MCP bridge for iPhone QA instead of unrestricted UI control`

Show the allowed tool surface, what the bridge refuses, and why the boundary matters.

### 7. Selector repair

**Title:** `Can an LLM repair a changed iOS selector without guessing?`

Compare a failed exact match, a bounded repair proposal, and the final human-approved update.

### 8. Timing investigation

**Title:** `Where the seconds go in an LLM-driven iOS test`

Measure capture, OCR, planning, input, and verification separately. Do not publish a speed claim without the method.

### 9. QA trade-off

**Title:** `When should an iOS QA agent stop asking the model for help?`

Use iosClaw as a case study, but make the post about the architecture decision rather than the product.

### 10. Real-device adapter

**Title:** `What changes when the same iOS flow runs through WebDriverAgent`

Explain why the physical-device adapter is developer-only and how loopback, signing, and device leasing affect the design.

### 11. Security boundary

**Title:** `The iOS actions I deliberately refuse to automate`

Discuss secrets, OTPs, Face ID, payments, and destructive actions as safety design—not as a feature list.

### 12. Open-source build log

**Title:** `I used Codex to turn a fragile iPhone macro into an open-source runtime`

Share the repository status, one architecture diagram, one known limitation, and one request for contributors.

## Publishing sequence

### Before the first post

- Wait until there has been no recent removal or duplicate attempt.
- Read the current rules and recent posts again.
- Use the weekly Showcase thread when it is available.
- Choose the closest flair; do not invent one.
- Prepare one screenshot, log, config excerpt, or small diagram.

### On submission

- Post once.
- Keep the first paragraph about the Codex problem or experiment.
- Use no more than one external link.
- Do not ask for upvotes, promotion, downloads, or “early users.”
- Do not mention that earlier versions were removed.

### After submission

- Do not edit the post immediately unless there is a factual error.
- Reply to questions with evidence, not repeated marketing copy.
- If it is removed, save the exact removal reason and use modmail; do not repost the same text.
- If the bot appears to have misclassified it, ask the moderators whether a technical showcase is allowed and which thread/flair they prefer.

## Success metrics

For the first six posts, optimize for conversation quality rather than clicks:

- At least one substantive technical reply.
- Questions from iOS QA or Codex users.
- Requests for methodology, logs, or source—not only reactions.
- No removal, duplicate, or spam warning.
- Evidence that readers understood the LLM/deterministic split.

Track title, pillar, format, link/no-link, flair, removal status, comments, and the most useful question received. Keep a short learning note after each post and use it to choose the next experiment.

---

# Multi-community expansion plan

## Research scope and interpretation

This extension covers four adjacent communities that match the product’s audiences:

- **r/developersIndia** — Indian software developers and career-focused engineers.
- **r/ClaudeAI** — Claude users sharing workflows, agents, tools, and experiments.
- **r/indiehackers** — founders discussing the build, distribution, validation, and business journey.
- **r/SideProject** — makers showing a working project and asking for constructive feedback.

The feed observations below use the recent public `/new.json` listings and moderator/pinned guidance available on 2026-09-13. Reddit does not expose a dependable approval timestamp for every post, so “recent approved posts” means publicly visible posts without a public removal marker at collection time. Treat the rules and flairs as a pre-submit check; they can change.

Research sources:

- [Recent r/developersIndia listing](https://www.reddit.com/r/developersIndia/new.json?limit=100&raw_json=1), [self-promotion guidance](https://www.reddit.com/r/developersIndia/comments/1jtnw5e), and [showcase-post guidance](https://www.reddit.com/r/developersIndia/comments/1ca5bn4)
- [Recent r/ClaudeAI listing](https://www.reddit.com/r/ClaudeAI/new.json?limit=100&raw_json=1), [Claude-specific rule update](https://www.reddit.com/r/claude/comments/1ryalp3/rclaude_has_new_rules_heres_what_changed_and_why/), and [ClaudeAI promotion guidance](https://www.reddit.com/r/ClaudeAI/comments/1i06cc0)
- [Recent r/indiehackers listing](https://www.reddit.com/r/indiehackers/new.json?limit=100&raw_json=1) and [community reorganisation/self-promotion guidance](https://www.reddit.com/r/indiehackers/comments/1uzsfzy/community_reorganisation_new_posting_guidelines/)
- [Recent r/SideProject listing](https://www.reddit.com/r/SideProject/new.json?limit=100&raw_json=1) and [maker discussion on promotion](https://www.reddit.com/r/SideProject/comments/1u6jx35/how_do_you_promote_your_projects/)

## The product story we should reuse

Keep one factual core and change the lead for each community:

> iosClaw is a Mac-first, local iOS QA runtime. An LLM proposes a bounded plan; live accessibility/visual evidence resolves targets; a deterministic executor runs known steps; postconditions and ambiguity stops keep the run inspectable. Record/replay compiles repeatable work so the model is not called for every action.

The story must name the current boundary: Simulator and iPhone Mirroring are the primary paths, the project is early, and sensitive actions (passwords, OTPs, Face ID, payments, CAPTCHA, and destructive confirmations) are not bypassed.

## Audience and message matrix

| Community | What readers tend to value | Best iosClaw angle | Primary ask |
|---|---|---|---|
| r/developersIndia | Practical engineering, career-relevant projects, stack trade-offs, real constraints | “Here is the engineering behind a useful iOS QA system built from India” | Review the architecture or suggest a missing edge case |
| r/ClaudeAI | Claude-specific workflows, agent/tool design, MCP, context and token efficiency | “How the planner/executor split changes an LLM agent’s reliability and cost” | Compare Claude’s planning/recovery behavior on one reproducible flow |
| r/indiehackers | Problem, founder journey, validation, distribution, honest metrics | “A narrow iOS QA wedge, what has been hard, and what I need to validate” | Interview/feedback from teams who ship iOS apps |
| r/SideProject | Working demo, clear scope, screenshots/video, constructive feedback | “Open-source local tool that makes iOS record/replay less brittle” | Try one documented Simulator flow and report a concrete failure |

## r/developersIndia plan

### Feed fit

Recent posts lean toward career, compensation, resumes, practical help, India-specific developer operations, and occasional project/resource showcases. The moderators explicitly ask project posts to explain the problem, stack, challenges, trade-offs, and lessons; traffic-driving posts and repeated promotion are treated as low quality. Showcase guidance prefers a short video and a direct project link.

### Recommended format

- Use **I Made This**, **General**, or the active monthly **Showcase Sunday** thread only after checking the current sidebar.
- 250–500 words, one short demo or architecture image, and one repository link at the bottom.
- Put engineering detail before the link: Swift/SwiftUI, ScreenCaptureKit, accessibility, OCR, selector resolution, deterministic replay, and permission boundaries.
- Add an India-relevant constraint only when true (device fragmentation, small QA teams, cost of physical devices, or local developer workflow). Do not force a “built in India” angle.

### Title patterns

- `I built a local iOS QA runtime to understand what an LLM should execute`
- `What I learned building semantic record/replay for iPhone tests`
- `Open-source Mac tool: replacing brittle tap coordinates with live iOS evidence`

### Content ideas

1. A postmortem on stale coordinates after an iOS layout change.
2. Simulator versus iPhone Mirroring: capture, permissions, and failure modes.
3. Why the runtime uses accessibility first and OCR only as a bounded fallback.
4. A cost/latency breakdown showing where an LLM call is unnecessary.
5. A small Swift architecture walkthrough and the trade-offs behind local-only storage.
6. A Showcase Sunday demo with one synthetic app and a reproducible test script.

### Guardrails

Do not lead with “startup,” “launch,” “sign up,” or a marketing page. Do not ask for stars, installs, or waitlist entries. Participate in other engineering threads before sharing; if removed, use modmail and do not repost the same draft.

## r/ClaudeAI plan

### Feed fit

The public feed contains Claude Code projects, skills, MCP/tool workflows, automation questions, screenshots, and model-use experiments. The community guidance is stricter than a general AI forum: keep the post Claude/Anthropic-specific, avoid lazy crossposts, disclose affiliation, and do not repeatedly promote the same service. Promotion is safest inside an explicitly marked showcase thread.

### Recommended format

- Frame iosClaw as a **Claude experiment**, not as a generic AI product ad.
- State exactly what Claude did (plan, selector repair proposal, test critique, or code generation) and what the local runtime did deterministically.
- Include a tiny transcript/config excerpt, a before/after timing table, or a failure trace. Remove personal data from screenshots.
- If Claude has not been tested on the flow, do not imply compatibility; instead ask whether readers want to reproduce the benchmark with Claude.
- Use a ClaudeAI showcase thread when available; otherwise ask moderators before a standalone tool post.

### Title patterns

- `I tested a planner/executor split for Claude on iOS QA`
- `Can Claude recover an iOS selector without guessing?`
- `What I moved out of the Claude loop to make iOS replay faster`

### Content ideas

1. Claude plans one flow while iosClaw executes and verifies it locally.
2. A token and latency comparison: every-step planning versus compiled replay.
3. MCP surface design: the small set of actions Claude is allowed to call.
4. A failed selector repair and the evidence required before accepting a change.
5. Claude Code generating a test adapter, followed by human review and a simulator run.
6. A model-neutral benchmark invitation comparing Claude, Codex, and another planner without winner claims.

### Guardrails

Disclose that you are the creator. No referral links, vote manipulation, fake user comments, or monthly reposts of the same promotion. Avoid “Claude is better than X” unless the post contains a reproducible method and balanced results.

## r/indiehackers plan

### Feed fit

Recent posts mix founder stories, launch retrospectives, distribution experiments, validation, and product metrics. The moderators have separated founder stories from **Self Promotion** and warn against disguised pitches, unverified MRR claims, fake Q&A, and repeated cross-posting. A story can mention the product, but the story—not the link—must be the value.

### Recommended format

- Use **Sharing story/journey/experience** for a genuine build log; use **Self Promotion** only when the purpose is explicitly to share the product.
- 400–700 words with a timeline: trigger → prototype → failed assumptions → current wedge → next validation step.
- Share real numbers only when you can define the denominator and measurement window (e.g., replay success over N Simulator runs). Never invent traction.
- Include one specific customer question, not “would you use this?”

### Title patterns

- `I spent months making iOS automation less flaky; here is the narrow wedge I found`
- `The assumption that slowed my iOS QA tool down (and the deterministic fix)`
- `Building an open-source iOS QA runtime as a solo developer: what I still need to validate`

### Content ideas

1. Why “LLM controls every tap” failed as a product premise.
2. The first user/problem interview script for iOS QA teams.
3. Build-versus-buy: accessibility, OCR, WebDriverAgent, and local execution.
4. The path from demo to a paid team workflow (without claiming product-market fit).
5. A weekly build log: one adapter, one failure, one learning.
6. Early pricing hypotheses tied to saved QA time, with an explicit “not validated” label.

### Guardrails

Do not disguise a launch post as a founder story. Do not cross-post the same copy to several founder communities on the same day. If a post includes revenue or usage, keep a dated measurement note ready; otherwise discuss the experiment qualitatively.

## r/SideProject plan

### Feed fit

This is the most natural home for a direct project showcase. Recent examples explain the feature set, link the repository, show a working release, and ask for specific UI or edge-case feedback. Community discussions repeatedly recommend contribution before promotion, problem-first framing, and the correct **Self Promotion** tag where required.

### Recommended format

- Use a direct project post with a 30–60 second Simulator video or annotated screenshot.
- Open with what works today, then list three known limitations.
- Give a quick “try this” path that does not require a physical iPhone: install the Mac app, boot a Simulator, run the sample flow.
- Link the GitHub repository first; put the website second. Ask for one concrete feedback type (e.g., “Which state-change failure should be prioritized?”).

### Title patterns

- `I built an open-source local iOS QA runtime with record/replay`
- `A Mac tool that turns iOS visual flows into deterministic tests`
- `Feedback wanted: semantic iPhone automation that stops when state is ambiguous`

### Content ideas

1. Full demo: open a sample app, enter data, verify a postcondition, replay it.
2. Before/after video showing coordinate macros versus semantic targets.
3. The local audit page: what is stored, what is redacted, and how to delete it.
4. Permission recovery UX after a newly signed build changes its identity.
5. Optional iPhone companion versus Mac-only deployment decision.
6. Contributor call focused on one adapter or one gesture, not a vague “help build this.”

### Guardrails

Use the correct flair and disclose open-source status. Keep the demo self-contained; do not make readers click through a landing page to understand the project. Never claim universal app coverage or guaranteed reliability.

## Cross-community publishing sequence

1. **r/Codex weekly showcase** — publish the Codex/LLM boundary experiment already prepared.
2. **r/SideProject** — publish the clearest working demo and repository.
3. **r/indiehackers** — publish the build/validation story after there is one concrete user or usage learning.
4. **r/developersIndia** — publish the engineering trade-offs in the appropriate showcase thread.
5. **r/ClaudeAI** — publish only when the post contains a real Claude-specific experiment or a clearly scoped comparison.

Use at least 7–10 days between standalone posts about the same milestone. Change the evidence and the question, not just the headline. Maintain a 9:1 contribution-to-self-promotion target as an operating guideline, not a claim about any subreddit’s formal rule.

## Reusable post production checklist

Before drafting:

- Read the subreddit’s current rules, pinned posts, and required flair.
- Pick one audience and one technical slice.
- Gather one artifact: video, screenshot, log, config, diff, or measured table.
- Decide whether the link is necessary; if not, offer it only when asked.

Before publishing:

- Write in your own voice and remove generic AI-marketing phrases.
- State affiliation and the current limitations.
- Use one clear question that a reader can answer from experience.
- Search the subreddit for near-duplicates.

After publishing:

- Respond to technical questions with evidence and corrections.
- Do not ask friends or agents to manufacture votes or comments.
- Record flair, link/no-link, comments, removals, and the best learning.
- If removed, stop, save the reason, and ask moderators for the permitted format instead of reposting.

## 30-day content calendar

| Week | Community | Asset | Core question |
|---|---|---|---|
| 1 | r/Codex showcase | timing table + short log | What belongs in the model loop? |
| 2 | r/SideProject | 60-second Simulator demo | Which edge case should be fixed first? |
| 3 | r/indiehackers | founder/build retrospective | Is this a painful enough QA wedge? |
| 4 | r/developersIndia | Swift architecture + trade-offs | How would you design this for a small QA team? |
| 5 (optional) | r/ClaudeAI | Claude-specific benchmark | How does your planner handle recovery and ambiguity? |

## Success criteria

Primary signals are substantive replies, reproducible bug reports, architecture suggestions, and qualified conversations with iOS QA engineers. Secondary signals are repository visits and demo clicks. A removal, duplicate warning, or vague “cool project” thread is a signal to improve fit—not a reason to repost faster.

For the broader candidate universe and per-community inspection workflow, see [reddit-discovery-map.md](reddit-discovery-map.md).
