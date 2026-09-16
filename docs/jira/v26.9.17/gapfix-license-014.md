# gapfix-license-014: LICENSE file (MIT) matching mix.exs declaration
status: OPEN
created: 2026-09-17T05:30:00Z
## Mission
mix.exs:66 declares licenses: ["MIT"]; no LICENSE file exists anywhere (git log --all confirms never existed). Add the MIT license text with the package's author line; no other changes.
## Acceptance
- LICENSE at root, text byte-standard MIT, copyright line consistent with mix.exs authors/maintainers; mix test 0.
## History
