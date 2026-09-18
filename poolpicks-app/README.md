# PoolPicks

PoolPicks is an Angular NFL confidence-pool app backed by Firebase Anonymous
Authentication and Cloud Firestore. The current launch exposes one pool named
`AFCU`; the underlying data model still supports many pools and many weeks.

Users enter a display name and the private group invite code once. Firebase
silently assigns a persistent UID to that browser, and every membership and
weekly submission is stored under that UID. No Google sign-in, email, or
account password is required.

## Required Firebase setup

The frontend is already configured for the existing `poolpicks-3906c` Firebase
project. Its web configuration in `src/firebase.public-config.ts` contains
public project identifiers only. Never put a service-account key or Admin SDK
credential in this repository.

Before publishing the Firebase-backed build:

1. In Firebase Console, open **Authentication → Sign-in method** and enable
   **Anonymous** authentication.
2. Create a Cloud Firestore database if one does not already exist.
3. Delete the old `pools` and `users` data if starting clean. Remove old pool
   documents recursively so any legacy subcollections are removed too; deleting
   only a parent document does not delete its subcollections.
4. In Firestore, create a private invite document whose ID is the shared invite
   code. Do not commit the actual code to this repository:

   ```text
   poolInvites/{sharedInviteCode}
     poolId: "AFCU"
     active: true
   ```

   Share links may use this format to pre-fill the invite code:

   ```text
   https://jlopez29.github.io/poolpicks/#/?invite={sharedInviteCode}
   ```

   The hash fragment is handled by the Angular app and is not sent to GitHub
   Pages in the HTTP request.

5. Deploy the included restrictive rules:

   ```bash
   npx firebase-tools login
   npx firebase-tools deploy --only firestore:rules
   ```

6. Build the GitHub Pages artifact:

   ```bash
   npm install
   npm run build:deploy
   ```

The first AFCU participant who completes a pick sheet creates the clean `AFCU`
pool and becomes its owner. Do this before the first game of the week because
the database rules enforce the first kickoff as the submission deadline.

## Data model

```text
users/{uid}
  displayName
  photoUrl
  joinedPools

pools/{poolId}
  name
  ownerId
  year
  week
  type

pools/{poolId}/members/{uid}
  displayName
  photoUrl
  role
  inviteCode

pools/{poolId}/weeks/{year-week}
  year
  week
  type
  lockAt

pools/{poolId}/weeks/{year-week}/submissions/{uid}
  displayName
  photoUrl
  picks or playoffPicks
  tiebreaker
  hasViewedPodium

poolInvites/{sharedInviteCode}
  poolId
  active
```

A user document is global to PoolPicks. The same UID can be a member of AFCU
and any future pool, while each pool and week gets a separate submission.

Anonymous identity is browser-specific. Clearing site data, explicitly signing
out, or using another device creates a different UID. A future permanent login
can be linked to the anonymous Firebase account without changing this schema.

## AFCU launch mode and future pools

`src/app-settings.ts` currently contains:

```ts
primaryPoolId: 'AFCU'
singlePoolMode: true
allowPoolCreation: false
```

This hides generic join/create controls while retaining their components and
services. Firestore rules also restrict new pool creation to the `AFCU` document.
When general pool creation is wanted later:

1. Turn off `singlePoolMode` and enable `allowPoolCreation`.
2. Replace the `poolId == 'AFCU'` creation restriction in `firestore.rules` with
   an owner-validated creation policy plus rate limiting or App Check.
3. Rebuild the frontend and redeploy the rules.

## Security behavior

- Every request requires a Firebase-authenticated UID.
- New membership requires an active, pool-specific invite document; invite
  documents cannot be read or written by clients.
- Users can write only their own profile, membership, and submission.
- Pool/week administration is restricted to the pool owner.
- Pool members can see submitted picks immediately.
- Picks and tiebreakers are immutable after their initial submission; only
  profile-display fields and podium-view state may change afterward.
- Scores are calculated from ESPN results and are not accepted from Firestore
  clients.
- Unknown collections are denied by default.
- Client error logs are not written to Firestore.

The rules bound document fields, types, pick count, and tiebreaker range. The UI
also enforces unique confidence values. For a larger or adversarial public pool,
move pick validation into a callable Cloud Function so every nested pick can be
validated server-side; the current setup is designed for the trusted AFCU group.

## Development

```bash
npm install
npm run dev
```

Build source only:

```bash
npm run build
```

Build directly into the portfolio's deployable `poolpicks/` directory:

```bash
npm run build:deploy
```

Validate Firestore rules locally:

```bash
npx firebase-tools emulators:exec --only firestore --project demo-poolpicks "true"
```

The local-storage adapter remains in `src/services/local-storage-data-store.ts`
as an offline/demo alternative. The active provider is selected in `index.tsx`.
