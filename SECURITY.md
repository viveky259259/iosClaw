# Security policy

iosClaw handles screen captures, accessibility input, encrypted local state, and optional developer-device automation. Please treat security reports as sensitive.

## Reporting a vulnerability

Do not open a public issue with credentials, private messages, screenshots, device identifiers, signing material, or an exploit. If private GitHub Security Advisories are enabled for the repository, use that channel. Otherwise open a minimal issue containing only “security report” and a safe way to establish a private conversation.

Please include the affected component, reproduction conditions, impact, and a proposed mitigation when known. We will acknowledge valid reports, coordinate a fix, and credit reporters who want attribution.

## Local data guidance

When testing or contributing:

- Use simulator data or dedicated test accounts.
- Never commit certificates, private keys, provisioning profiles, notary credentials, app-specific passwords, or personal messages.
- Redact screenshots and audit fixtures before sharing them.
- Keep WebDriverAgent bound to loopback and use only devices owned or authorized by the QA team.
