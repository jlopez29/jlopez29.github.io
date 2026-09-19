# Jesse Lopez — Portfolio & Apps

Personal portfolio and browser-based projects hosted at [jlopez29.github.io](https://jlopez29.github.io/).

The portfolio and most apps are plain HTML, CSS, and JavaScript. PoolPicks has a
separate Angular source project that builds into a static folder alongside the
other apps. There is no repository-wide package install or build step.

## Projects

| Project | Description | Source / documentation | Site path |
| --- | --- | --- | --- |
| Portfolio | Project showcase with responsive navigation and light/dark themes | [index.html](index.html), [home.css](home.css) | `/` |
| PoolPicks | NFL confidence picks, weekly leaderboards, playoff picks, and achievements; currently configured for the private AFCU group | [poolpicks-app/](poolpicks-app/README.md) | `/poolpicks/` |
| LoL IQ | League of Legends training games, champion scouting, and guided lessons | [loliq/](loliq/README.md) | `/loliq/` |
| ReCert Ready | PANRE-LA practice questions, flashcards, and study modes | [panre/](panre/README.md) | `/panre/` |
| WordXchange | Timed word chains made by adding, removing, or changing one letter | [wordxchange/](wordxchange/README.md) | `/wordxchange/` |

## Repository layout

```text
.
├── index.html          # Portfolio markup and inline behavior
├── home.css            # Portfolio styles
├── favicon.ico
├── profile.png
├── loliq/              # Editable static app and curriculum
├── panre/              # Editable static app and practice content
├── wordxchange/        # Editable static word game
├── poolpicks-app/      # Angular source, Firebase rules, tests, and build config
│   ├── src/            # Components, services, models, and public configuration
│   ├── tests/          # Isolated regression tests
│   ├── firestore.rules
│   └── package.json
└── poolpicks/          # Generated PoolPicks files served by GitHub Pages
```

Edit PoolPicks in `poolpicks-app/`, **not** its generated `poolpicks/` files.
The two directories are source and build output—not separate frontend and backend
applications. Rebuilding replaces the generated output.

## Run locally

### Portfolio and static apps

With Python 3 installed, run this from the repository root:

```bash
python3 -m http.server 8080 --bind 127.0.0.1
```

Open [localhost:8080](http://localhost:8080/). The project links work just as they
do on the hosted site, including the last built version of PoolPicks. No npm
install is required for the portfolio, LoL IQ, ReCert Ready, or WordXchange.

Use an HTTP server rather than opening files directly, particularly for apps
that fetch external data.

### PoolPicks development

Use Node.js 22.12 or later within the 22.x release line, or Node.js 24, with npm.
From the repository root:

```bash
cd poolpicks-app
npm ci
npm run dev
```

Open [localhost:3000](http://localhost:3000/). This serves the Angular source with
development rebuilding; it does not update the deployable `poolpicks/` directory.

**Local development uses the configured Firebase project by default.** It is
not automatically connected to an emulator, so signing in or submitting picks
can affect real data. Review [PoolPicks setup](poolpicks-app/README.md) before
testing against Firebase.

## Test and build PoolPicks

Run these commands inside `poolpicks-app/`:

```bash
npm test
npm run build
```

The tests isolate application behavior with mocked dependencies and do not
contact live Firebase. The Angular build checks source and templates and writes
to `poolpicks-app/dist/`. These checks do not replace deployed-rules testing or
a browser smoke test.

To generate the version served by this repository:

```bash
npm run build:deploy
```

This writes to `poolpicks/` at the repository root with a `/poolpicks/` base path.
PoolPicks uses hash-based routes, such as `/poolpicks/#/pool/AFCU`.

## Publishing changes

The repository is organized to publish the root directory through GitHub Pages.
Check the repository's **Settings → Pages** for the actual publishing branch and
source; there is no checked-in GitHub Actions deployment workflow.

1. Edit the portfolio or the relevant app's source files.
2. For PoolPicks changes, run the tests and `npm run build:deploy`.
3. Preview from the repository root and check navigation, mobile layout, and the
   changed feature. For PoolPicks, also check joining and picks in two browsers.
4. Review the Git diff. Include PoolPicks source changes **and** regenerated
   `poolpicks/` files, including replacement hashed bundles.
5. Commit and push to the configured publishing branch, then check the Pages
   deployment result.

Changing Angular source without rebuilding `poolpicks/` will not update the
version served from that folder. Publishing static files also does **not** deploy
Firestore rules; that is a separate step documented in the PoolPicks README.

## Data, external services, and security

- The portfolio saves theme preferences in browser storage. LoL IQ, ReCert Ready,
  and WordXchange store their progress or scores locally; clearing site data can
  remove that information.
- LoL IQ fetches Riot Data Dragon definitions and artwork. WordXchange supplements
  its bundled word list with a public dictionary when available.
- PoolPicks uses Firebase Anonymous Authentication and Cloud Firestore for shared
  data, plus ESPN schedules/results. It currently requires a group invite to join;
  Google sign-in and a custom backend are not implemented.
- Anonymous PoolPicks identities are browser-specific. Signing out, clearing site
  data, or switching devices can mean using a different identity.
- Firebase web configuration is public client configuration, not an authorization
  boundary. Access depends on authentication and deployed Firestore rules. Never
  commit service-account credentials, Admin SDK keys, or private invite codes.
- GitHub Pages serves the frontend; Firebase usage is separate. This repository
  does not enforce a spending cap or guarantee zero backend costs.

The current PoolPicks rules provide a restricted internal-group setup, not full
server-side validation of every nested pick. Future public pool creation,
password verification, and stronger abuse controls need additional backend and
rules work. See [PoolPicks security notes](poolpicks-app/README.md#security-behavior).

## Maintaining and adding projects

Keep each static app in its own directory with an `index.html` entry point and
relative asset paths. Add its card/link to the root `index.html`, update `home.css`
if needed, and add it to the project table above. Framework-based apps should keep
editable source separate from their generated publishing folder, as PoolPicks does.

Project-specific READMEs contain the detailed feature and setup notes. ReCert
Ready is independent educational practice, not medical advice or an NCCPA product;
its AI-authored content requires qualified clinician review before high-stakes
use. LoL strategy lessons also require review as game patches change.
