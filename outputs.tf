# Export the project id so that it can be referenced outside of terraform
# E.g. $ terraform output project_id
output "project_id" {
  value = "${google_project.project.project_id}"
}

# Export the project number so it can be used elsewhere
output "project_number" {
  value = "${google_project.project.number}"
}

# Export the service accounts as a map of account id to fully-qualified email
output "service_accounts" {
  value = "${zipmap(google_service_account.sa.*.account_id, google_service_account.sa.*.email)}"
}

# Export the usage bucket name
output "usage_export_bucket" {
  value = "${local.usage_export_bucket_name}"
}
