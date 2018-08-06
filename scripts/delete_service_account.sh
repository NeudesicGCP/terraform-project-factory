#!/bin/sh
#
# Deletes the service account from a project
# $1 = project_id
# $2 = service account email
# $3 = credentials file

set -e

# On exit reset the gcloud auth account to prior value
CURRENT_AUTH=$(gcloud config get-value account)
trap reset_auth 0 1 2 3 6
reset_auth()
{
    gcloud config set account "${CURRENT_AUTH}"
}

# If the service account is not found, exit early with success
# - this prevents terraform from reporting an error when the script is
#   triggered but the account has already been deleted.
[ -z "$(gcloud iam service-accounts list --project="$1" --format='value(email)' --filter="email~${2}")" ] && exit 0

# If credentials file exists, switch to that account
[ -n "${3}" ] && [ -r "${3}" ] && \
    gcloud auth activate-service-account --key-file="$3"

# Actually delete the account
gcloud iam service-accounts delete --quiet --project="$1" "$2"
