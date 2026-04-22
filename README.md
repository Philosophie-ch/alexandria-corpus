# alexandria-corpus

Versioned bibliography data for [Alexandria Nexus](https://github.com/Philosophie-ch/alexandria-nexus). Each table is mirrored as CSV files here. Publishing a GitHub release triggers a full production rebuild.

## Layout

```
data_version.yml          -- version tag and description, bump before each release

data/
  keyword/all.csv
  school/all.csv
  institution/all.csv
  series/all.csv
  publisher/all.csv
  journal/all.csv

  author/                 -- split by first character of author_key
    a.csv  b.csv  ...

  bibitem/                -- split by first two characters of bibkey
    aa.csv  ab.csv  ...

  bibitem_authors/all.csv
  bibitem_keywords/all.csv
  bibitem_refs/all.csv
  bibitem_notes/all.csv
```

## Updating the corpus

1. Run the full local import against the source portal CSVs using the tooling in `sysadmin-utils/alexandria/dev/`. This imports data into the local dev DB and takes a snapshot that replaces `data/` here.
2. Bump `data_version.yml` (version + description).
3. Open a PR, review the diff, merge to `main`.
4. Publish a GitHub release — the rebuild workflow deploys to production.

## Rebuild workflow

On release publish, `.github/workflows/rebuild.yml` SSHes into the production server and:

1. Checks that `data_version.yml` carries a version not yet in the DB (version gate).
2. Wipes all data tables.
3. Clones this repo on the server and reimports in dependency order: entities → authors → bibitems → junctions → refs → notes.
4. Records the data version.

Required repository secrets (same values as in `alexandria-nexus`):

| Secret | Description |
|--------|-------------|
| `PROD_HOST` | Production server hostname/IP |
| `PROD_USER` | SSH user |
| `PROD_SSH_KEY` | SSH private key |
| `ALEXANDRIA_SEED_API_KEY` | Admin API key |

## Manual production rebuild (on demand)

If you need to push data to production outside of a release, use the sysadmin tunnel:

```bash
# Terminal 1 — open the tunnel
cd sysadmin-utils/alexandria/sysadmin && ./tunnel.sh

# Terminal 2 — run the rebuild
./corpus-rebuild.sh
```

Requires `ALEXANDRIA_CORPUS_PATH` set in the sysadmin `.env`.

## CSV format

Each file contains the exact column layout of the corresponding database table, IDs included. Rows are sorted by primary key for stable diffs across versions.
