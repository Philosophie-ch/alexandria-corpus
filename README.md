# alexandria-corpus

Versioned bibliography data for [Alexandria Nexus](https://github.com/Philosophie-ch/alexandria-nexus). Each table is mirrored as CSV files here. Merging to `main` (via a release) triggers a full production rebuild.

## Layout

```
data_version.yml          -- version tag and description, updated before each PR

keyword/all.csv
school/all.csv
institution/all.csv
series/all.csv
publisher/all.csv
journal/all.csv

author/                   -- split by first character of author_key
  a.csv
  b.csv
  ...

bibitem/                  -- split by first two characters of bibkey
  aa.csv
  ab.csv
  ...

bibitem_refs/all.csv
bibitem_notes/all.csv
```

## Adding a new data version

1. Run a full import locally against the source CSV to catch errors.
2. Generate the snapshot:
   ```bash
   curl -X POST https://localhost:8080/api/v1/admin/snapshot \
     -H "Authorization: Bearer $KEY" -o snapshot.zip
   unzip -o snapshot.zip -d /path/to/alexandria-corpus
   ```
3. Update `data_version.yml` with a version string and description.
4. Open a PR. Review the diff.
5. Publish a GitHub release to trigger the rebuild workflow.

## Rebuild workflow

On release publish, `.github/workflows/rebuild.yml`:

1. Wipes all data tables (`POST /api/v1/admin/wipe?confirm=true`)
2. Reimports in dependency order: keywords, schools, institutions, series, publishers, journals, authors, bibitems
3. Imports bibitem refs and recomputes the transitive dependency graph
4. Imports bibitem notes
5. Records the data version (`POST /api/v1/data-version`)

Requires two repository secrets: `ALEXANDRIA_URL` and `ALEXANDRIA_ADMIN_KEY`.

## CSV format

Each file contains the exact column layout of the corresponding database table, IDs included. Rows are sorted by primary key for stable diffs across versions.
