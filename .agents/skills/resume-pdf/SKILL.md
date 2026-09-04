---
name: resume-pdf
description: Generate and visually verify the downloadable PDF for this Astro resume after content or print-style changes. Use for PDF updates; do not deploy the site.
---

# Resume PDF

Run `scripts/generate.sh` from anywhere inside the repository.

Inspect every PNG path printed by the script. Accept only a legible two-page A4 without clipping or overlaps; otherwise fix the source and rerun. Remove the printed QA directory after inspection.

The script updates the final PDF in `output/pdf/` and copies it to tracked `public/` and built `dist/`. Commit the `public/` copy with the source change. Do not publish unless explicitly requested.
