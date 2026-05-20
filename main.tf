terraform {
  required_providers {
    akeyless = {
      source  = "akeyless-community/akeyless"
      version = ">= 1.8.0"
    }
  }
}

variable "akeyless_token" { type = string }
variable "instruqt_user_id" { type = string }

provider "akeyless" {
  api_gateway_address = "https://api.akeyless.io"
  api_key_login {
    access_id = var.akeyless_token
  }
}

# 1. Universal Identity
resource "akeyless_auth_method_universal_identity" "learner_uid" {
  name              = "/instruqt-users-uid/${var.instruqt_user_id}/uid-${var.instruqt_user_id}"
  ttl               = 500
  jwt_ttl           = 500
  deny_rotate       = true
  delete_protection = "false"
}

# 2. Base Access Role
resource "akeyless_role" "role" {
  name                = "/instruqt-users-uid-roles/${var.instruqt_user_id}/uid-${var.instruqt_user_id}-role"
  description         = "Role for user ${var.instruqt_user_id}"
  analytics_access    = "own"
  audit_access        = "own"
  event_center_access = "own"
  sra_reports_access  = "own"
  delete_protection   = "false"
  gw_analytics_access = "scoped" # Top-level toggle mapping to "Gateways" row
}

# 3. ✅ THE TERRAFORM FIX: The explicit Gateway Reports sub-rule
resource "akeyless_role_rule" "gw_reports_visibility" {
  role_name  = akeyless_role.role.name
  rule_type  = "gw-reports-rule"
  path       = "/scoped"
  capability = ["read"]
}

# 4. Standard Lab Visibility Rules
resource "akeyless_role_rule" "items_visibility" {
  role_name  = akeyless_role.role.name
  rule_type  = "item-rule"
  path       = "/TrainingUsers/${var.instruqt_user_id}/*"
  capability = ["create", "read", "update", "delete", "list"]
}

resource "akeyless_role_rule" "auth_methods_visibility" {
  role_name  = akeyless_role.role.name
  rule_type  = "auth-method-rule"
  path       = "/TrainingUsers/${var.instruqt_user_id}/*"
  capability = ["create", "read", "update", "delete", "list"]
}

resource "akeyless_role_rule" "roles_visibility" {
  role_name  = akeyless_role.role.name
  rule_type  = "role-rule"
  path       = "/TrainingUsers/${var.instruqt_user_id}/*"
  capability = ["create", "read", "update", "delete", "list"]
}

resource "akeyless_role_rule" "targets_visibility" {
  role_name  = akeyless_role.role.name
  rule_type  = "target-rule"
  path       = "/TrainingUsers/${var.instruqt_user_id}/*"
  capability = ["create", "read", "update", "delete", "list"]
}

# 5. Bind Role to Universal Identity
resource "akeyless_associate_role_auth_method" "learner_uid_role" {
  role_name = akeyless_role.role.name
  am_name   = akeyless_auth_method_universal_identity.learner_uid.name
}

output "learner_uid" { value = akeyless_auth_method_universal_identity.learner_uid.name }
output "uid_access_id" { value = akeyless_auth_method_universal_identity.learner_uid.access_id }
