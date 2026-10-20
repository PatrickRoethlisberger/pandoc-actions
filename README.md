# pandoc-actions

GitHub Actions that build a Markdown manuscript with a Pandoc template and export draw.io diagrams. The template lives in its own repository and only ships a `pandoc/` data folder; these actions are shared by all such templates.

Both actions need a Linux runner with Docker (GitHub's `ubuntu-latest` has it). Nothing is built or installed: they run existing images (`pandoc/latex`, `rlespinasse/drawio-desktop-headless`) and mount the template into them.

```yaml
- uses: actions/checkout@v7
- uses: PatrickRoethlisberger/pandoc-actions/drawio@v1
- uses: PatrickRoethlisberger/pandoc-actions/build@v1
  with:
    template: owner/my-template@v1
    defaults: thesis
- uses: actions/upload-artifact@v7
  with:
    archive: false
    path: thesis.pdf
```

Upload the PDF with `archive: false` (needs `upload-artifact@v7` or later). The PDF is then stored as-is and downloads or opens directly, instead of being zipped. The artifact takes the file's name, so `name` is ignored, and only a single file can be uploaded this way.

## `build`

Builds the manuscript in a Pandoc image. The data directory is the template's `pandoc/` folder; the defaults file `defaults/<defaults>.yaml` in it is passed as `-d <defaults>`.

| Input | Meaning | Default |
|---|---|---|
| `defaults` | Defaults file name in the template (required) | – |
| `template` | `owner/repo` or `owner/repo@ref` (tag, branch or SHA); the default branch if no ref is given. Use this or `data-dir` | – |
| `data-dir` | Pandoc data directory in your repository, relative to its root, for a local template or a submodule. Use this or `template` | – |
| `token` | Token to fetch a private template repository; not needed for public ones | – |
| `image` | Docker image that runs Pandoc, for a template that needs more LaTeX packages or fonts | `pandoc/latex:3.7.0.2-ubuntu` |
| `input` | Manuscript, relative to `working-directory` | `thesis.md` |
| `output` | PDF to write, relative to `working-directory` | `thesis.pdf` |
| `working-directory` | Where Pandoc runs, relative to the repository root; images, bibliography and diagrams are found from here | `.` |
| `args` | Extra Pandoc options, e.g. `--pdf-engine-opt=-pdflatex=lualatex` | – |

The template is fetched outside the workspace, so none of it ends up in your checkout. The ref is the template version: pin it (`@v1`) in your workflow.

A template is a repository with a `pandoc/` folder at its root. Pandoc looks for each kind of file in a fixed folder of its data directory (`defaults/`, `filters/`, `csl/`, `templates/`, …), and `templates/` must be flat.

## `drawio`

Exports every page of every `.drawio` (or `.dio`) file below `working-directory` to a cropped PDF beside the source. Page 1 becomes `name.pdf`, page N becomes `name-pageN.pdf`; this is the naming a template's draw.io filter has to expect. The image is about 400 MB. The `build` image has no draw.io, so the build uses these PDFs.

| Input | Meaning | Default |
|---|---|---|
| `working-directory` | Directory to search, relative to the repository root | `.` |

There are two ways to wire it up:

- **Simple:** put `drawio` before `build` in the same job. Every build exports the diagrams again.
- **Only when a diagram changes:** export in a separate workflow that a path filter triggers, and commit the PDFs. The build workflow then finds them in the checkout. Without committed PDFs the build has nothing to fall back on, so skipping the export is only safe this way.

  ```yaml
  # .github/workflows/diagrams.yml
  on:
    push:
      paths: ["**.drawio"]
  permissions:
    contents: write
  jobs:
    export:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v7
        - uses: PatrickRoethlisberger/pandoc-actions/drawio@v1
        - run: |
            git config user.name "github-actions[bot]"
            git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
            git add -- '*.pdf'
            git diff --cached --quiet || { git commit -m "Export diagrams" && git push; }
  ```

  A commit made with the default token does not start other workflows. The build that your own push started runs in parallel and sees the old PDFs, so re-run it after the export commit, or start the build with `workflow_run` on this workflow.

## Releasing

Consumers pin a major tag. Pushing an immutable tag is the whole release; the `Move major tag` workflow then moves the floating major tag (`v1`) to the same commit:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Only full `vMAJOR.MINOR.PATCH` tags trigger it. The first release of a new major version (`v2.0.0`) creates `v2` the same way.
