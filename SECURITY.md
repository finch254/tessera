# Security Policy

## Reporting a vulnerability

Please report security vulnerabilities to **finch254** via GitHub Security Advisories
(https://github.com/finch254/tessera/security/advisories/new).

Do not open public issues for security bugs.

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |
| < 1.0   | No        |

## Notes

- Tessera stores only UserDefaults data (favorites, theme, blur mode). No personal data is collected.
- Network calls go to Pexels (third-party). Review Pexels' privacy policy.
- The Pexels API key is a client-side build setting — never commit it to the repo.
