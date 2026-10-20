#!/usr/bin/env zsh
# Call the Kiro control plane (undocumented API) with curl's built-in SigV4 signing.
#
#   ./kiro-profile-api.sh ListProfiles  list-profiles.json     # read-only: full profile + valid model IDs
#   ./kiro-profile-api.sh UpdateProfile new-update.json        # WRITE: replaces the whole profile config
#
# list-profiles.json must contain {"optInFeaturesType":"KIRO"} so the response is the
# COMPLETE profile (incl. byUserAnalytics/overageConfiguration); an empty {} omits them.
# A successful ListProfiles response is also saved to snapshots/profile-<date>-<time>.json.
#
# Uses your local AWS credentials (AWS_PROFILE, default if unset). Never paste the
# browser's authorization / x-amz-security-token headers into this script.
set -euo pipefail

operation=$1
payload=$2
script_dir=${0:A:h}

# Load AccessKeyId / SecretAccessKey / SessionToken from the local AWS profile
eval "$(aws configure export-credentials --format env)"

response=$(mktemp)
trap 'rm -f "$response"' EXIT

http_code=$(curl https://management.us-east-1.kiro.dev/ \
  --silent --show-error \
  --aws-sigv4 "aws:amz:us-east-1:codewhisperer" \
  --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" \
  ${AWS_SESSION_TOKEN:+--header "x-amz-security-token: ${AWS_SESSION_TOKEN}"} \
  --header "content-type: application/x-amz-json-1.0" \
  --header "x-amz-target: KiroControlPlaneService.${operation}" \
  --data "@${payload}" \
  --output "$response" \
  --write-out "%{http_code}")

cat "$response"
echo "\nHTTP ${http_code}"

if [[ $operation == ListProfiles && $http_code == 200 ]]; then
  mkdir -p "${script_dir}/snapshots"
  snapshot="${script_dir}/snapshots/profile-$(date +%Y%m%d-%H%M%S).json"
  jq . "$response" > "$snapshot"
  echo "Saved ${snapshot}"
fi
