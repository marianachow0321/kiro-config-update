#!/usr/bin/env zsh
# Build new-update.json for UpdateProfile.   ./build-update-payload.sh
#
# Reproduces the whole profile from the latest snapshot (UpdateProfile replaces).
# Requires a COMPLETE snapshot — byUserAnalytics/overageConfiguration only appear when
# ListProfiles is called with {"optInFeaturesType":"KIRO"}; the guard below rejects an
# incomplete one. See README for the full rationale.
set -euo pipefail
cd "${0:A:h}"

latest=$(ls snapshots/profile-*.json 2>/dev/null | sort | tail -1 || true)
if [[ -z $latest ]]; then
  echo "No snapshot found. Run: ./kiro-profile-api.sh ListProfiles list-profiles.json" >&2
  exit 1
fi

# Guard: refuse to build from an incomplete snapshot (one taken with an empty {} body).
# byUserAnalytics/overageConfiguration missing here means the payload would wipe them.
missing=$(jq -r '
  ["byUserAnalytics","overageConfiguration"]
  - (.profiles[0].optInFeatures | keys)
  | join(", ")' "$latest")
if [[ -n $missing ]]; then
  echo "Snapshot ${latest} is INCOMPLETE (missing: ${missing})." >&2
  echo "It was taken with an empty body. Re-run:" >&2
  echo "  ./kiro-profile-api.sh ListProfiles list-profiles.json" >&2
  echo "(list-profiles.json must contain {\"optInFeaturesType\":\"KIRO\"})" >&2
  exit 1
fi

jq -n --slurpfile snap "$latest" '
  ($snap[0].profiles[0]) as $p
  | {
      profileArn:    $p.arn,
      profileName:   $p.profileName,
      # Map ListProfiles read-shape (identityDetails.ssoIdentityDetails) to the
      # UpdateProfile write-shape (identitySource.ssoIdentitySource).
      identitySource: { ssoIdentitySource: {
          instanceArn: $p.identityDetails.ssoIdentityDetails.instanceArn,
          ssoRegion:   $p.identityDetails.ssoIdentityDetails.ssoRegion } },
      optInFeatures: $p.optInFeatures,          # complete, incl. byUserAnalytics/overage
      optInFeaturesType: "KIRO",                # request-only constant
      referenceTrackerConfiguration: $p.referenceTrackerConfiguration,
      activeFunctionalities:         $p.activeFunctionalities,
      resourcePolicy:                $p.resourcePolicy
    }
  | with_entries(select(.value != null))
  ' > new-update.json

echo "Built new-update.json from ${latest}"
echo
echo "optInFeatures carried into the payload:"
jq -r '.optInFeatures | keys[] | "  optInFeatures." + .' new-update.json
echo
echo "modelConfiguration summary:"
jq -r '.optInFeatures.modelConfiguration
  | "  toggle: \(.toggle), default: \(.defaultModel.modelId), models: \(.allowlistedModels | length)"' \
  new-update.json
