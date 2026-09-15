# iosClaw Reddit discovery map

## Purpose

This is a discovery map for finding conversations about iOS QA, mobile automation, LLM agents, developer tools, and indie software. It is not a list of places to paste the same launch message. Every candidate must pass a live rules, flair, activity, and audience check before we post.

## What was scanned

On 2026-09-13, I used Reddit’s public subreddit search metadata and recent public feeds to build a 120+ candidate universe, then reviewed recent posts and moderator guidance for the highest-fit communities. Public Reddit data does not expose a reliable approval timestamp for every post; visible, non-removed posts are used as the practical proxy. The current research evidence includes:

- [iOS-related subreddit search](https://www.reddit.com/subreddits/search.json?q=ios%20testing&limit=100&raw_json=1)
- [QA automation subreddit search](https://www.reddit.com/subreddits/search.json?q=qa%20automation&limit=100&raw_json=1)
- [AI-agent subreddit search](https://www.reddit.com/subreddits/search.json?q=ai%20agents&limit=100&raw_json=1)
- [r/iOSProgramming description and FAQ](https://www.reddit.com/r/iOSProgramming/)
- [r/softwaretesting recent moderation examples](https://www.reddit.com/r/softwaretesting/comments/1rmcqzs/removed/)
- [r/GitHub self-promotion megathread](https://www.reddit.com/r/github/comments/1jy8rea/promote_your_projects_here_selfpromotion/)

The scan found an important distinction: a large audience is not automatically a good channel. Communities containing the product’s actual technical problem should outrank generic startup-promotion lists.

## Priority model

Score each community before use:

| Dimension | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| Problem fit | No clear fit | Adjacent interest | Recurring iOS/QA/agent discussion | Core audience has the problem |
| Evidence fit | Link drops only | Screenshots accepted | Technical walkthroughs expected | Reproducible logs/demos are rewarded |
| Conversation access | Private/inactive | Rare posts | Comment participation possible | Active threads and recurring megathreads |
| Promotion friction | Unknown | Rules unclear | Self-promo constrained | Clear showcase route |

**Tier A (test first):** problem fit ≥2 and a clear technical or showcase route.

**Tier B (comment/monitor):** adjacent fit, high friction, or insufficient evidence. Earn context through comments before considering a post.

**Tier C (do not target yet):** generic growth lists, inactive communities, consumer audiences without a QA problem, or communities whose rules prohibit the relevant post type.

## Tier A: first-wave communities

| Cluster | Communities | Best contribution |
|---|---|---|
| Apple engineering | [r/iOSProgramming](https://www.reddit.com/r/iOSProgramming/), [r/swift](https://www.reddit.com/r/swift/), [r/SwiftUI](https://www.reddit.com/r/SwiftUI/), [r/macosprogramming](https://www.reddit.com/r/macosprogramming/), [r/Xcode](https://www.reddit.com/r/Xcode/), [r/appdev](https://www.reddit.com/r/appdev/) | Swift architecture, ScreenCaptureKit, permissions, accessibility, Simulator evidence |
| Mobile QA | [r/softwaretesting](https://www.reddit.com/r/softwaretesting/), [r/QualityAssurance](https://www.reddit.com/r/QualityAssurance/), [r/testautomation](https://www.reddit.com/r/testautomation/), [r/mobiletesting](https://www.reddit.com/r/mobiletesting/), [r/appium](https://www.reddit.com/r/appium/), [r/SDET](https://www.reddit.com/r/SDET/) | Locator stability, assertions, device labs, record/replay trade-offs |
| Agents and LLM tooling | [r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/), [r/codex](https://www.reddit.com/r/codex/), [r/OpenAI](https://www.reddit.com/r/OpenAI/), [r/ChatGPT](https://www.reddit.com/r/ChatGPT/), [r/AIAgents](https://www.reddit.com/r/AIAgents/), [r/LocalLLaMA](https://www.reddit.com/r/LocalLLaMA/), [r/MCP](https://www.reddit.com/r/MCP/) | Planner/executor boundaries, MCP tool design, token/latency evidence |
| Open-source makers | [r/SideProject](https://www.reddit.com/r/SideProject/), [r/indiehackers](https://www.reddit.com/r/indiehackers/), [r/buildinpublic](https://www.reddit.com/r/buildinpublic/), [r/opensource](https://www.reddit.com/r/opensource/), [r/github](https://www.reddit.com/r/github/) | Working demo, repository, build log, contributor-sized issue |
| India developer audience | [r/developersIndia](https://www.reddit.com/r/developersIndia/), [r/IndianStartups](https://www.reddit.com/r/IndianStartups/), [r/startupsIndia](https://www.reddit.com/r/startupsIndia/), [r/IndianProgrammers](https://www.reddit.com/r/IndianProgrammers/) | Practical engineering story, small-team QA constraints, open-source learning |

## Tier B: second-wave communities

### Apple and mobile development

`r/ObjectiveC`, `r/watchOS`, `r/visionOS`, `r/ARKitCreators`, `r/iOSApps`, `r/iOSGaming`, `r/TestFlight`, `r/AppleDevelopers`, `r/iPhone`, `r/ios`, `r/AndroidDev`, `r/androiddev`, `r/FlutterDev`, `r/reactnative`, `r/mobiledev`, `r/crossplatform`, `r/Unity3D`, `r/UnrealEngine`.

Use these for a specific platform or app-adapter question. Avoid a generic “here is my automation product” post.

### QA, reliability, and delivery

`r/selenium`, `r/playwright`, `r/cypress`, `r/automatedtesting`, `r/manualtesting`, `r/webtesting`, `r/qa`, `r/testing`, `r/SoftwareTesting`, `r/performanceTesting`, `r/loadtesting`, `r/devops`, `r/sre`, `r/reliabilityengineering`, `r/chaosengineering`, `r/continuousintegration`, `r/jenkinsci`, `r/GitHubActions`, `r/Agile`, `r/scrum`, `r/engineering`.

Use these for evidence-heavy posts about flakiness, postconditions, test maintenance, CI artifacts, or permissions. Some testing communities explicitly reject “please test/review my software” and enforce roughly 10% self-link guidance, so lead with a general lesson and never make the post a request for free QA.

### AI, developer tools, and programming

`r/Claude`, `r/Anthropic`, `r/ModelContextProtocol`, `r/LangChain`, `r/AutoGPT`, `r/LLMDevs`, `r/LLM`, `r/MachineLearning`, `r/ArtificialIntelligence`, `r/GenerativeAI`, `r/PromptEngineering`, `r/RAG`, `r/MLOps`, `r/agents`, `r/aiagents`, `r/vibecoding`, `r/Cursor`, `r/CursorAI`, `r/VisualStudioCode`, `r/vim`, `r/neovim`, `r/emacs`, `r/programming`, `r/learnprogramming`, `r/webdev`, `r/frontend`, `r/backend`, `r/javascript`, `r/typescript`, `r/python`, `r/rust`, `r/golang`, `r/compilers`, `r/devtools`, `r/CodeReview`.

Use these only when the post is about a concrete tool boundary, benchmark, implementation decision, or reproducible workflow. Model-comparison posts need balanced methodology and must not be disguised promotion.

### Indie, startup, and product communities

`r/indiedev`, `r/sideprojects`, `r/Solopreneur`, `r/Entrepreneur`, `r/Entrepreneurs`, `r/startups`, `r/startup`, `r/Startup_Ideas`, `r/Business_Ideas`, `r/SaaS`, `r/MicroSaas`, `r/micro_saas`, `r/bootstrapped`, `r/growmybusiness`, `r/AlphaandBetaUsers`, `r/AppIdeas`, `r/ProductManagement`, `r/productdesign`, `r/UXDesign`, `r/userexperience`, `r/EntrepreneurRideAlong`, `r/startup_resources`, `r/indiebiz`, `r/scaleinpublic`, `r/juststart`, `r/thesidehustle`, `r/launch`, `r/ProductHunt`.

Use a founder story, validation note, or specific feedback request. Do not recycle the technical showcase unchanged; these readers need the problem, failed assumptions, customer evidence, and next decision.

### India and regional communities

`r/cscareerquestionsIN`, `r/IndiaTech`, `r/Bangalore`, `r/hyderabad`, `r/mumbai`, `r/delhi`, `r/india`, `r/AskIndia`, `r/Chennai`, `r/pune`, `r/kerala`, `r/IndianGaming`, `r/IndianDevelopers`.

Use only when the post genuinely addresses a regional constraint or audience. Do not use broad city or national communities as generic traffic channels.

## Tier C: monitor only for now

`r/technology`, `r/Futurology`, `r/productivity`, `r/apps`, `r/software`, `r/techsupport`, `r/InternetIsBeautiful`, `r/Entrepreneurship`, `r/passive_income`, `r/marketing`, `r/GrowthHacking`, `r/digital_marketing`, `r/SEO`, `r/indiehackers` mirror communities, generic “promote your app” directories, and any community where the latest visible posts are mostly referral links or automated launch threads.

These may be useful later for a genuinely broad result, but they are poor first homes for iosClaw. Monitor recurring threads rather than posting standalone product announcements.

## How to inspect each candidate before posting

For every subreddit that survives the priority filter, capture a row in a tracking sheet or issue:

1. Subscriber count and recent-post activity.
2. The last 50 publicly visible posts, excluding posts with a public removal marker.
3. Top recurring intents (questions, showcases, troubleshooting, debates, hiring, memes).
4. Recent moderator announcements, sidebar rules, required flair, karma/account-age gates, and megathreads.
5. Link policy and examples of posts that received substantive replies.
6. One safe post angle and one disallowed angle for iosClaw.
7. The minimum artifact needed: screenshot, video, log, benchmark, code, or customer evidence.

Do not automate posting, voting, commenting, or account rotation. The discovery process can be assisted by scripts, but publication stays human-reviewed and one community at a time.

## Content atomization strategy

Create one evidence pack per milestone, then derive community-specific posts:

| Evidence pack | iOS/QA version | Agent version | Indie version | India developer version |
|---|---|---|---|---|
| Replay benchmark | Locator and assertion maintenance | Tokens/calls saved by compiled replay | Why the wedge exists | Small-team cost and device constraints |
| Permission failure | Screen Recording/Accessibility diagnosis | Safe tool refusal and recovery | Deployment friction | macOS setup lessons |
| Selector repair | Accessibility + OCR fallback | Bounded model proposal | Time saved versus manual repair | Swift implementation trade-off |
| Simulator demo | Reproducible test steps | Planner/executor trace | What works today | Open-source learning |

Never publish the same copy, title, image, and link combination across communities.

## Operating cadence

- Start with 8–12 Tier A communities, not the full universe.
- Contribute useful comments for 2–3 weeks before a standalone post in a new community.
- Publish one milestone per community, then wait at least 7–10 days before another post about the same product.
- Prefer recurring showcase or megathreads whenever available.
- Stop after a removal, duplicate warning, or moderator request; record the reason and ask before retrying.

## Measurement

Track per community: post date, title, angle, flair, artifact, link/no-link, impressions if visible, substantive comments, qualified conversations, removals, moderator feedback, and the next learning. Optimize for technical discussion and qualified QA conversations; treat clicks and upvotes as secondary.

## Immediate next actions

1. Pick one iOS/QA community and one maker community from Tier A.
2. Prepare a different evidence pack for each: a benchmark for QA, a 60-second demo for makers.
3. Check live rules and flair on the day of posting.
4. Publish once, answer questions, and update this map with the observed response.
