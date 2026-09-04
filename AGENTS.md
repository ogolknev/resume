# Resume workflow

- After changing resume content or print styles, run `$resume-pdf` before committing and include `public/nikita-ogolknev-resume.pdf` in the same commit.
- If the user explicitly asks to push `main`, finish with `$resume-publish`: push `main`, deploy `gh-pages`, and verify the live HTML and PDF.
- A local edit or successful build is not a publication.
