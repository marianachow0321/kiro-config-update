# Kiro profile settings via API

Scripts for reading and updating a Kiro Enterprise profile when the Kiro console can't save.

Built for profile `QDefaultProfile` in us-east-1. Nothing profile-specific is stored in
the repo — `build-update-payload.sh` reconstructs the whole profile from the latest
`ListProfiles` snapshot.

`UpdateProfile` **replaces** the profile (omitted fields are nulled), so the payload must
carry everything. Key gotcha: `ListProfiles` returns the full profile — including
`byUserAnalytics` and `overageConfiguration` — only when the request body is
`{"optInFeaturesType":"KIRO"}` (what `list-profiles.json` sends); an empty `{}` omits them.

## Quick Start

```zsh
git clone git@github.com:marianachow0321/kiro-config-update.git
cd kiro-config-update

./kiro-profile-api.sh ListProfiles list-profiles.json    # 1. save complete profile to snapshots/

./build-update-payload.sh                                # 2. build new-update.json from the snapshot

# 3. edit new-update.json → change the field(s) you want (it already mirrors the live profile)

./kiro-profile-api.sh UpdateProfile new-update.json      # 4. send (expect HTTP 200)

./kiro-profile-api.sh ListProfiles list-profiles.json    # 5. re-snapshot and eyeball the change
```

Use the Kiro console for normal changes. Use these scripts only when the console fails.
