---
name: resume-publish
description: Push committed resume changes from main and deploy the existing GitHub Pages gh-pages branch, including the downloadable PDF. Use only after an explicit push or publication request.
---

# Resume publication

Before committing content or print-style changes, use `$resume-pdf` and include the generated `public/nikita-ogolknev-resume.pdf`.

With a clean `main`, run `scripts/publish.sh`. It builds, pushes `main`, replaces `gh-pages` from `dist/`, waits for Pages, and compares the live HTML and PDF byte-for-byte.

Report both commit hashes and the live URL. Do not claim publication if the script fails.
