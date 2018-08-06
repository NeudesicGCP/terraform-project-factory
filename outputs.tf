# Export the project id so that it can be referenced outside of terraform
# E.g. $ terraform output project_id
output "project_id" {
  value = "${google_project.project.project_id}"
}

# Export the subnets as a map of name to region
output "subnets" {
  value = "${zipmap(google_compute_subnetwork.subnet.*.name, google_compute_subnetwork.subnet.*.region)}"
}

# Export the service accounts as a map of account id to fully-qualified email
output "service_accounts" {
  value = "${zipmap(google_service_account.sa.*.account_id, google_service_account.sa.*.email)}"
}

# Export the usage bucket name
output "usage_export_bucket" {
  value = "${local.usage_export_bucket_name}"
}
