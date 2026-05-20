terraform {
  required_providers {
    akeyless = {
      version = ">= 1.0.0"
      source  = "akeyless-community/akeyless"
    }
  }
}

provider "akeyless" {
  api_gateway_address = "https://api.akeyless.io"

  token_login {
    token = var.akeyless_token
  }
}

variable "akeyless_token" {
  type        = string
  description = "Akeyless token"
  sensitive   = true
}

variable "instruqt_user_id" {
  type        = string
  description = "Instruqt participant ID"
}

# Universal Identity for the learner
resource "akeyless_auth_method_universal_identity" "learner_uid" {
  name        = format("/instruqt-users-uid/%s/uid-%s", var.instruqt_user_id, var.instruqt_user_id)
  jwt_ttl     = 500
  ttl         = 500
  deny_rotate = true
}

# The Sub-Admin Role utilizing Path Templating
resource "akeyless_role" "role" {
  name                = format("/instruqt-users-uid-roles/%s/uid-%s-role", var.instruqt_user_id, var.instruqt_user_id)
  description         = format("Admin Role for user %s", var.instruqt_user_id)
  
  # SYSTEM ADMINISTRATIVE RIGHTS (Crucial for console.akeyless.io UI views)
  audit_access        = "own"
  analytics_access    = "own"
  event_center_access = "all"
  gw_analytics_access = "all" # Enables visibility of the "Gateways" tab in the SaaS UI
  sra_reports_access  = "own"

  # Path Rules scoped safely to user space
  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = "/TrainingUsers/{{user_space}}/*"
    rule_type  = "item-rule"
  }

  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = "/TrainingUsers/{{user_space}}/*"
    rule_type  = "target-rule"
  }

  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = "/TrainingUsers/{{user_space}}/*"
    rule_type  = "role-rule"
  }

  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = "/TrainingUsers/{{user_space}}/*"
    rule_type  = "auth-method-rule"
  }
}

# Associating the identity with the designated role & injecting user_space criteria
resource "akeyless_associate_role_auth_method" "learner_uid_role" {
  depends_on = [
    akeyless_role.role,
    akeyless_auth_method_universal_identity.learner_uid
  ]
  role_name = akeyless_role.role.name
  am_name   = akeyless_auth_method_universal_identity.learner_uid.name

  sub_claims = {
    user_space = var.instruqt_user_id
  }
}

output "learner_uid" {
  value = akeyless_auth_method_universal_identity.learner_uid.name
}

output "uid_access_id" {
  value = akeyless_auth_method_universal_identity.learner_uid.access_id
}
