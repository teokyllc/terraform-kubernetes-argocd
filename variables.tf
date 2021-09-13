variable "aks_kubeconfig" {
    type = string
    description = "The kubeconfig file from the AKS cluster."
}

variable "aks_cluster_name" {
    type = string
    description = "The name of the AKS cluster to apply ArgoCD to."
}

variable "aks_cluster_rg" {
    type = string
    description = "The name of the resource group the AKS cluster is in."
}

variable "vault_token" {
    type = string
    description = "An admin token to use Vault."
}

variable "region" {
    type = string
    description = "The Azure region."
}

variable "argo_git_app_id" {
    type = string
    description = "The Github app id."
    default = "116304"
}

variable "argo_fqdn" {
    type = string
    description = "The FQDN DNS name for ArgoCD."
}

variable "sso_login_url" {
    type = string
    description = "The Azure AD SAML login URL."
}

variable "sso_certificate" {
    type = string
    description = "The Azure AD SAML certificate for the app."
}

variable "argo_git_app_installation_id" {
    type = string
    description = "The Github app installation id."
    default = "17064473"
}

variable "argo_aad_admin_group_id" {
    type = string
    description = "The Azure AD group ID for administrative access to ArgoCD."
}

variable "argo_aad_read_only_group_id" {
    type = string
    description = "The Azure AD group ID for read-only access to ArgoCD."
}