terraform {
  required_providers {
    akeyless = {
      source  = "akeyless-community/akeyless"
      version = ">= 1.8.0"
    }
  }
}

variable "akeyless_token" {
  type        = string
  description = "Akeyless Management Token"
}

variable "instruqt_user_id" {
  type        = string
  description = "Unique Sandbox ID for the participant"
}

provider "akeyless" {
  api_gateway_address = "https://api.akeyless.io"

  # ✅ CORRECT STRUCTURAL PATTERN FOR THE TOKEN PROVIDER
  token_login {
    token = var.akeyless_token
  }
}

# 1. Create the Universal Identity Auth Method for the Gateway
resource "akeyless_auth_method_universal_identity" "learner_uid" {
  name              = "/instruqt-users-uid/${var.instruqt_user_id}/uid-${var.instruqt_user_id}"
  ttl               = 500
  jwt_ttl           = 500
  deny_rotate       = true
  delete_protection = "false"
}

# 2. Main Admin Role with Corrected Administrative View Parameters
resource "akeyless_role" "role" {
  name                = "/instruqt-users-uid-roles/${var.instruqt_user_id}/uid-${var.instruqt_user_id}-role"
  description         = "Role for user ${var.instruqt_user_id}"
  analytics_access    = "own"
  audit_access        = "own"
  event_center_access = "own"
  sra_reports_access  = "own"
  delete_protection   = "false"

  # Aligns the "Gateways" Row in the console GUI to "Scoped"
  gw_analytics_access = "scoped"

  # Standard laboratory folder engine permissions
  rules {
    rule_type  = "item-rule"
    path       = "/TrainingUsers/${var.instruqt_user_id}/*"
    capability = ["create", "read", "update", "delete", "list"]
  }
  rules {
    rule_type  = "role-rule"
    path       = "/TrainingUsers/${var.instruqt_user_id}/*"
    capability = ["create", "read", "update", "delete", "list"]
  }
  rules {
    rule_type  = "auth-method-rule"
    path       = "/TrainingUsers/${var.instruqt_user_id}/*"
    capability = ["create", "read", "update", "delete", "list"]
  }
  rules {
    rule_type  = "target-rule"
    path       = "/TrainingUsers/${var.instruqt_user_id}/*"
    capability = ["create", "read", "update", "delete", "list"]
  }
  rules {
    rule_type  = "item-rule"
    path       = "/Admin/*"
    capability = ["deny"]
  }
}

# 3. Associate the Role to the Universal Identity Method
resource "akeyless_associate_role_auth_method" "learner_uid_role" {
  role_name = akeyless_role.role.name
  am_name   = akeyless_auth_method_universal_identity.learner_uid.name
}

output "learner_uid" {
  value = akeyless_auth_method_universal_identity.learner_uid.name
}

output "uid_access_id" {
  value = akeyless_auth_method_universal_identity.learner_uid.access_id
}
