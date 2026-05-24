terraform {
  required_providers {
    akeyless = {
      version = ">= 1.0.0"
      source  = "akeyless-community/akeyless"
    }
  }

#   cloud {
#     organization = "cs-akl"
#     workspaces {
#       name = "instruqt-users-training-account"
#     }
#   }
}

provider "akeyless" {
  api_gateway_address = "https://api.akeyless.io"

  token_login {
    token = var.akeyless_token
  }
}

# ==========================================
# VARIABLES
# ==========================================

variable "akeyless_token" {
  type        = string
  description = "Akeyless token"
  sensitive   = true
}

variable "instruqt_user_id" {
  type        = string
  description = "Instruqt participant ID"
}

# ==========================================
# AUTH METHOD
# ==========================================

resource "akeyless_auth_method_universal_identity" "learner_uid" {
  name        = format("/instruqt-users-uid/%s/uid-%s", var.instruqt_user_id, var.instruqt_user_id)
  jwt_ttl     = 500
  ttl         = 500
  deny_rotate = true
}

# ==========================================
# ROLES
# ==========================================

# Primary User Role
resource "akeyless_role" "role" {
  name                = format("/instruqt-users-uid-roles/%s/uid-%s-role", var.instruqt_user_id, var.instruqt_user_id)
  description         = format("Role for user %s", var.instruqt_user_id)
  audit_access        = "own"
  analytics_access    = "own"
  event_center_access = "own"
  sra_reports_access  = "own"

  # Secrets and items access
  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = format("/TrainingUsers/%s/*", var.instruqt_user_id)
    rule_type  = "item-rule"
  }

  rules {
    capability = ["deny"]
    path       = "/Admin/*"
    rule_type  = "item-rule"
  }

  # Target access
  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = format("/TrainingUsers/%s/*", var.instruqt_user_id)
    rule_type  = "target-rule"
  }

  # Adjusted path to match where their roles live so they can manage them via CLI/TF
  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = format("/instruqt-users-uid-roles/%s/*", var.instruqt_user_id)
    rule_type  = "role-rule"
  }

  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = format("/TrainingUsers/%s/*", var.instruqt_user_id)
    rule_type  = "auth-method-rule"
  }
}

# Role Viewer (Now contains the Scoped Gateway Analytics settings)
resource "akeyless_role" "role_viewer" {
  depends_on = [
    akeyless_role.role
  ]
  name                = format("/instruqt-users-uid-roles/%s/role-viewer-%s-role", var.instruqt_user_id, var.instruqt_user_id)
  description         = format("Role Viewer for user %s", var.instruqt_user_id)
  
  # FIX: Added administrative scoped access property right here
  gw_analytics_access = "scoped"

  # Standard permission to read the primary role definition
  rules {
    capability = ["read", "list"]
    path       = akeyless_role.role.name
    rule_type  = "role-rule"
  }

  # FIX: Added item-rule path scope mapping so the "scoped" attribute 
  # knows exactly which path directory to filter gateway dashboard telemetry by
  rules {
    capability = ["read", "list"]
    path       = format("/TrainingUsers/%s/*", var.instruqt_user_id)
    rule_type  = "item-rule"
  }
}

# ==========================================
# ROLE ASSOCIATIONS
# ==========================================

resource "akeyless_associate_role_auth_method" "learner_uid_role" {
  depends_on = [
    akeyless_role.role,
    akeyless_auth_method_universal_identity.learner_uid
  ]
  role_name = akeyless_role.role.name
  am_name   = akeyless_auth_method_universal_identity.learner_uid.name
}

resource "akeyless_associate_role_auth_method" "role_viewer_role" {
  depends_on = [
    akeyless_role.role_viewer,
    akeyless_auth_method_universal_identity.learner_uid
  ]
  role_name = akeyless_role.role_viewer.name
  am_name   = akeyless_auth_method_universal_identity.learner_uid.name
}

# ==========================================
# OUTPUTS
# ==========================================

output "learner_uid" {
  value = akeyless_auth_method_universal_identity.learner_uid.name
}

output "uid_access_id" {
  value = akeyless_auth_method_universal_identity.learner_uid.access_id
}
