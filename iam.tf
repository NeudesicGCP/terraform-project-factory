# var.iam_assignments is a list of strings that formatted as
# "account-specifier=iam-role", where account-specifier can be any one of
# 'user:username@domain.tld', 'group:groupname@domain.tld',
# 'serviceAccount:account-id@project-id.iam.gserviceaccount.com', or
# 'account-id' if (and only if) account-id is a service account defined in the
# current project module. Role can be any single IAM role.
#
# E.g. to add service account 'foobar' (created as part of this module) as a
# Project Editor:-
#  iam_assignments = ["foobar=project/editor"]
#

# Verify that iam_assignments_count matches the number of entries in
# iam_assignments - workaround for Terraform limitation.
# See https://github.com/hashicorp/terraform/issues/10857#issuecomment-368059147
resource "null_resource" "verify_iam_assignments_count" {
  provisioner "local-exec" {
    command = <<EOF
if [ ${var.iam_assignments_count} -ne ${length(var.iam_assignments)} ]; then
  echo "var.iam_assignments_count must match the length of var.iam_assignments list"
  exit 1
fi
EOF
  }

  triggers {
    iam_assignments_computed = "${length(var.iam_assignments)}"
    iam_assignments_provided = "${var.iam_assignments_count}"
  }
}

# Sanitise the input list; all raw service account ids will become
# fully-qualified identifiers. Terraform 0.12 and for_each will help immensely
# here.
data "null_data_source" "iam_assignments" {
  count = "${var.iam_assignments_count}"

  inputs = {
    account = "${replace(element(var.iam_assignments, count.index), "@", "!") != element(var.iam_assignments, count.index) ? element(split("=", element(var.iam_assignments, count.index)), 0) : format("serviceAccount:%s",join("", matchkeys(google_service_account.sa.*.email, google_service_account.sa.*.account_id, list(element(split("=", element(var.iam_assignments, count.index)), 0)))))}"
    role    = "${element(split("=", element(var.iam_assignments, count.index)), 1)}"
  }
}

resource "google_project_iam_member" "iam" {
  count      = "${var.iam_assignments_count}"
  project    = "${google_project.project.project_id}"
  role       = "${lookup(data.null_data_source.iam_assignments.*.outputs[count.index], "role")}"
  member     = "${lookup(data.null_data_source.iam_assignments.*.outputs[count.index], "account")}"
  depends_on = ["google_project_service.api", "google_service_account.sa"]
}
