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
  description = "Akeyless administrator session token"
  sensitive   = true
}

variable "instruqt_user_id" {
  type        = string
  description = "Unique Instruqt participant identifier used for multi-tenant isolation"
}

# 1. Create the Universal Identity (UID) Method for the student environment
resource "akeyless_auth_method_universal_identity" "learner_uid" {
  name        = format("/instruqt-users-uid/%s/uid-%s", var.instruqt_user_id, var.instruqt_user_id)
  jwt_ttl     = 500
  ttl         = 500
  deny_rotate = true
}

# 2. Define a virtual "Sub-Admin" Role using Path Templating
# Crucial change: The path utilizes {{user_space}} which enforces runtime tenant routing!
resource "akeyless_role" "sub_admin_role" {
  name                = format("/instruqt-users-uid-roles/%s/uid-%s-admin-role", var.instruqt_user_id, var.instruqt_user_id)
  description         = format("Virtual Root Admin Role for sandbox %s", var.instruqt_user_id)
  audit_access        = "own"
  analytics_access    = "own"
  event_center_access = "own"
  gw_analytics_access = "own"
  sra_reports_access  = "own"

  # Student has full administrator permissions over Secrets/Keys inside their sub-space
  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = "/TrainingUsers/{{user_space}}/*"
    rule_type  = "item-rule"
  }

  # Student can manage and create Targets inside their sub-space
  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = "/TrainingUsers/{{user_space}}/*"
    rule_type  = "target-rule"
  }

  # Student can manage independent internal Roles inside their sub-space
  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = "/TrainingUsers/{{user_space}}/*"
    rule_type  = "role-rule"
  }

  # Student can manage independent internal Auth Methods inside their sub-space
  rules {
    capability = ["create", "read", "update", "delete", "list"]
    path       = "/TrainingUsers/{{user_space}}/*"
    rule_type  = "auth-method-rule"
  }
}

# 3. Associate the Identity to the Role, strictly pinning the user_space sub-claim
resource "akeyless_associate_role_auth_method" "learner_sub_admin_assoc" {
  depends_on = [
    akeyless_role.sub_admin_role,
    akeyless_auth_method_universal_identity.learner_uid
  ]
  role_name = akeyless_role.sub_admin_role.name
  am_name   = akeyless_auth_method_universal_identity.learner_uid.name

  # Enforce that tokens authorized under this role MUST contain the participant's specific claim
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
