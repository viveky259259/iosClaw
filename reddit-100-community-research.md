# iosClaw Reddit research and content validation — 100 communities

Research date: 2026-09-13. This package covers exactly 100 unique subreddit names across Apple/mobile development, QA and automation, AI/agents, developer infrastructure, open source, indie/startup, and India-focused communities. The existing `content-plan.md` was not modified.

## Deliverables

- [Batch A — Apple, mobile engineering, and QA](reddit-research-batch-a.md): 30 community-specific plans and drafts.
- [Batch B — QA, automation, reliability, DevOps, and developer tools](reddit-research-batch-b.md): 30 plans and drafts.
- [Batch C — AI, indie, open source, and India](reddit-research-batch-c.md): 30 plans and drafts.
- [Root batch — cross-platform and additional engineering communities](reddit-research-batch-root.md): 10 plans and drafts.
- [Supplement — AR, infrastructure, product, and UX](reddit-research-supplement.md): 11 plans and drafts.
- [Supplement 2 — four final communities](reddit-research-supplement-2.md): 4 plans and drafts.

The batch files contain the requested per-community loop: audience and recent format, public rule/feed evidence, promotion constraints, an iosClaw-specific content angle, a generated title/body, and a green/yellow/red preflight verdict.

## Exact coverage

`r/AgentsOfAI`, `r/Agile`, `r/AI_Agents`, `r/AI_Programming`, `r/AndroidApps`, `r/AndroidDev`, `r/ansible`, `r/appdev`, `r/appium`, `r/apple`, `r/appledevelopers`, `r/AppleWatch`, `r/ARKit`, `r/ARKitCreators`, `r/ArtificialIntelligence`, `r/automatedtesting`, `r/automation`, `r/buildinpublic`, `r/ChatGPT`, `r/cicd`, `r/ClaudeAI`, `r/continuousintegration`, `r/crossplatform`, `r/Cypress`, `r/developersIndia`, `r/devops`, `r/DevSecOps`, `r/devtools`, `r/docker`, `r/Entrepreneur`, `r/fastlane`, `r/FlutterDev`, `r/github`, `r/githubactions`, `r/gitlab`, `r/IMadeThis`, `r/IndianProgrammers`, `r/IndianStartups`, `r/indiedev`, `r/indiehackers`, `r/iOS`, `r/iOSApps`, `r/iosbeta`, `r/iosdev`, `r/iOSGaming`, `r/iOSProgramming`, `r/iPad`, `r/iPhone`, `r/jenkinsci`, `r/kubernetes`, `r/LangChain`, `r/launch`, `r/LLMDevs`, `r/LocalLLaMA`, `r/macapps`, `r/macOS`, `r/macosprogramming`, `r/macsysadmin`, `r/MCP`, `r/micro_saas`, `r/mobiledev`, `r/mobiletesting`, `r/ObjectiveC`, `r/Observability`, `r/OpenAI`, `r/opensource`, `r/platformengineering`, `r/Playwright`, `r/ProductManagement`, `r/programming`, `r/PromptEngineering`, `r/qa`, `r/QualityAssurance`, `r/reactnative`, `r/SaaS`, `r/SDET`, `r/selenium`, `r/selfhosted`, `r/SideProject`, `r/softwaretesters`, `r/softwaretesting`, `r/sre`, `r/Startup_Ideas`, `r/StartUpIndia`, `r/startups`, `r/swift`, `r/SwiftUI`, `r/sysadmin`, `r/terraform`, `r/testautomation`, `r/TestFlight`, `r/testing`, `r/Unity3D`, `r/UnrealEngine`, `r/UXDesign`, `r/visionOS`, `r/watchOS`, `r/webdev`, `r/Xcode`, `r/XCUITest`.

## What “validated” means

This is a preflight content validation, not a promise of moderator approval. A draft is **green** only when the topic is directly relevant, the body is useful without the project link, and the community’s observed format allows a technical discussion or designated showcase thread. **Yellow** means a narrow topic, a required flair/megathread/karma gate, or a sparse rules endpoint needs a same-day human check. **Red** means no standalone promotion: use a neutral educational post, a permitted thread, or ask moderators first.

The strongest recurring signals were:

- QA communities often prohibit vendor links, product advertising, or requests to test software; use a vendor-neutral method post instead.
- Developer communities reward source, logs, benchmarks, and a concrete question; link-first “I built this” copy is commonly filtered.
- Founder/maker communities accept projects when the story includes problem, failed assumptions, trade-offs, and honest evidence; they reject disguised promotion and inflated metrics.
- Some communities allow promotion only in a weekly thread or on a specific day. Those constraints dominate the verdict even when the audience fit is strong.
- Public Reddit JSON may return an empty rule array or an inaccessible feed. That is an evidence gap, not permission.

## Iteration loop

1. **Select one community and one evidence pack.** Do not broadcast the same title, body, image, and link.
2. **Re-check live rules, wiki, pinned posts, flair, and the newest 20–50 posts.** Do this on the day of publication while logged out when possible.
3. **Run the content gate.** The opening line names the community’s problem; the body includes one artifact or measurement; the project relationship and AI/model use are disclosed; the post remains useful if every link is removed; the ask is one concrete question.
4. **Route by verdict.** Green can proceed to human approval; yellow requires a narrower rewrite or the designated thread; red is education-only or moderator-confirmation-only.
5. **Publish manually and observe.** No automated posting, voting, commenting, DMs, account rotation, or retry-after-removal behavior.
6. **Record the outcome.** Log title, flair, link/no-link, evidence pack, comments, removal reason, moderator feedback, and the next revision. Stop immediately after a removal or warning.

## Product-specific safety boundaries

- Never claim iosClaw can bypass iOS security, permissions, or app sandboxing.
- Never ask a subreddit to test, install, star, upvote, or join a waitlist when its rules prohibit that behavior.
- Do not call a Mac-local runtime “self-hosted” unless a user-operable control plane and documentation actually exist.
- Do not publish unsupported latency, accuracy, revenue, or adoption numbers. Include baseline, sample size, and date for any measurement.
- Treat generated drafts as starting points; edit them into the author’s own voice. Several communities explicitly remove content that reads like LLM output.

## Research limitations

The 100-community universe is broad by design. The public feeds are moving snapshots and do not provide a reliable approval timestamp for every visible post. Some small or restricted subreddits expose sparse rules or inaccessible feeds. Those rows are deliberately marked yellow/red and require a final human check; they should not be interpreted as guaranteed posting destinations.

No Reddit post, comment, vote, DM, account action, or moderation action was performed during this research.
