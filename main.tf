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
# MAIN LEARNER ROLE (With Gateway Visibility)
# ==========================================

resource "akeyless_role" "role" {
  name                = format("/instruqt-users-uid-roles/%s/uid-%s-role", var.instruqt_user_id, var.instruqt_user_id)
  description         = format("Role for user %s with gateway visibility", var.instruqt_user_id)
  
  # Crucial for UI log viewing
  gw_analytics_access = "scoped"
  audit_access        = "own"
  analytics_access    = "own"
  event_center_access = "scoped"
  sra_reports_access  = "scoped"

  # -------------------------------------------------------------
  # GLOBAL VIEW RULES (Forces the UI to unhide the Gateways Tab)
  # -------------------------------------------------------------
  
  rules {
    capability = ["read", "list"]
    path       = "/*"
    rule_type  = "item-rule" # Gateways are registered as "items" in Akeyless
  }

  rules {
    capability = ["read", "list"]
    path       = "/*"
    rule_type  = "auth-method-rule"
  }

  rules {
    capability = ["read", "list"]
    path       = "/*"
    rule_type  = "role-rule"
  }

  # -------------------------------------------------------------
  # SANDBOX WRITE RULES (Restricts modifications to their own folder)
  # -------------------------------------------------------------

  rules {
    capability = ["create", "update", "delete"]
    path       = format("/TrainingUsers/%s/*", var.instruqt_user_id)
    rule_type  = "item-rule"
  }

  rules {
    capability = ["create", "update", "delete", "list"]
    path       = format("/TrainingUsers/%s/*", var.instruqt_user_id)
    rule_type  = "target-rule"
  }

  rules {
    capability = ["create", "update", "delete", "list"]
    path       = format("/TrainingUsers/%s/*", var.instruqt_user_id)
    rule_type  = "role-rule"
  }

  rules {
    capability = ["create", "update", "delete", "list"]
    path       = format("/TrainingUsers/%s/*", var.instruqt_user_id)
    rule_type  = "auth-method-rule"
  }

  # Explicit administrative safety block
  rules {
    capability = ["deny"]
    path       = "/Admin/*"
    rule_type  = "item-rule"
  }
}

# ==========================================
# ROLE VIEWER & ASSOC
# ==========================================

resource "akeyless_role" "role_viewer" {
  depends_on = [akeyless_role.role]
  name        = format("/instruqt-users-uid-roles/%s/role-viewer-%s-role", var.instruqt_user_id, var.instruqt_user_id)
  description = format("Role Viewer for user %s", var.instruqt_user_id)

  rules {
    capability = ["read", "list"]
    path       = akeyless_role.role.name
    rule_type  = "role-rule"
  }
}

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
