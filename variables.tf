variable "kubeconfig" {
    type = string
    description = "The kubeconfig file from the AKS cluster."
}

variable "github_app_private_key" {
    type = string
    description = "The Github app private key."
}

variable "argo_git_app_id" {
    type = string
    description = "The Github app id."
}

variable "argo_git_app_installation_id" {
    type = string
    description = "The Github app installation id."
}

variable "argo_fqdn" {
    type = string
    description = "The FQDN DNS name for ArgoCD."
}

variable "argo_sso_login_url" {
    type = string
    description = "The Azure AD SAML login URL."
}

variable "argo_sso_certificate" {
    type = string
    description = "The Azure AD SAML certificate for the app."
}

variable "argo_admin_user_enabled" {
    type = string
    description = "Enables the Argo admin user."
}

variable "argo_anonymous_users_enabled" {
    type = string
    description = "Enables anonymous user access to Argo UI."
}

variable "argo_aad_admin_group_id" {
    type = string
    description = "The Azure AD group ID for administrative access to ArgoCD."
}

variable "argo_aad_read_only_group_id" {
    type = string
    description = "The Azure AD group ID for read-only access to ArgoCD."
}
