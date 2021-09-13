# terraform-kubernetes-argocd
This Terraform module will deploy ArgoCD into Kubernetes and setup SSO and RBAC.  Be sure to follow the pre-reqs before using this module.

## DNS Pre-Reqs
A DNS record needs to be created for Argo in order to use SSO.  Select an IP from the range used in the subnet AKS uses for internal LB's for the DNS record.

## SSO Pre-Reqs
Before SSO can be used an app registration needs to be created and SAML SSO configured on the Azure AD app.<br><br>
Log into the Azure portal and navigate to <b>Azure AD -> Enterprise applications</b>.<br>
Click on <b>New application</b>, then click on <b>Create your own application</b>.<br>
Give the application a name such as ArgoCD and tick the radio box for <b>Integrate any other application you don't find in the gallery (Non-gallery)</b>.<br><br>
Once the application is created, open it from the <b>Enterprise applications</b> menu.<br>
From the <b>Users and groups</b> menu of the app, add any users or groups requiring access to the service.<br>
From the <b>Single sign-on</b> menu, click on <b>SAML</b>.<br><br>
Click the edit button on the <b>Basic SAML Configuration</b> box.<br>
```
Update the following fields replacing <ArgoFQDN> with the actual domain name used to access Argo.

* Identifier (Entity ID) -> https://<ArgoFQDN>/api/dex/callback
* Reply URL (Assertion Consumer Service URL) -> https://<ArgoFQDN>/api/dex/callback
* Sign on URL -> https://<ArgoFQDN>/auth/login
```

<br>
Next click edit on the <b>User Attributes & Claims</b> box.<br>
Click on the box <b>Add new claim</b>, and enter the following details for the claim.<br>
* Name: email<br>
* Source: Attribute<br>
* Source attribute: user.mail<br><br>

Then click edit on the <b>User Attributes & Claims</b> box.<br>
Click on the box <b>Add a group claim</b>, and enter the following details for the claim.<br>
* Which groups associated with the user should be returned in the claim?: All groups<br>
* Source Attribute: Group ID<br>
* Customize the name of the group claim: checked<br>
* Name: Group<br>
* Emit groups as role claim: unchecked<br><br>

From the Single sign-on menu, go to the box labeled <b>SAML Signing Certificate</b> and click on the Download link for <b>Certificate (Base64)</b>.<br>
The downloaded .crt file needs to be base64 encoded.  Use the following command in a Bash shell to encode the certificate.<br>
```
cat ArgoCD.cer | base64 -w 0
```

<br>
From the Single sign-on menu, note the <b>Login URL</b> parameter in the box labeled <b>Set up APPNAME</b>.<br><br>

The values for <b>ArgoFQDN</b>, <b>LoginUrl</b>, and <b>SamlCertificate</b> will be used as Terraform variables to configure the ArgoCD config map enabling SSO.


## Using this module
You will need to place the following files into a git repo that is being used as a Terraform workspace.<br><br>
<b>TF-Workspace\main.tf</b> <br>
```
module "argocd" {
  depends_on                   = [module.aks]
  source                       = "app.terraform.io/ANET/argocd/kubernetes"
  version                      = "1.0.22"
  aks_kubeconfig               = module.aks.aks_kubeconfig
  region                       = local.region
  argo_fqdn                    = "argo.teokyllc.internal"
  sso_login_url                = "https://login.microsoftonline.com/5ad90dc5-b02a-4f06-8f90-14d6bccf9282/saml2"
  sso_certificate              = var.sso_certificate
  #github_app_private_key       = var.github_app_private_key
  aks_cluster_name             = module.aks.aks_cluster_name
  aks_cluster_rg               = module.aks.aks_rg_name
  argo_git_app_id              = "116304"
  argo_git_app_installation_id = "17064473"
  argo_aad_admin_group_id      = "271497d3-a118-449a-a877-acb02e4fda52"
  argo_aad_read_only_group_id  = "fabfdbaf-7b2e-4d8a-ab5f-e4bcc65f3e7f"
}
```
<br><br>
<b>TF-Workspace\variables.tf</b> <br>
```
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

variable "region" {
    type = string
    description = "The Azure region."
}

variable "argo_fqdn" {
    type = string
    description = "The FQDN name for ArgoCD."
}

variable "sso_login_url" {
    type = string
    description = "The Azure AD SAML login URL."
}

variable "sso_certificate" {
    type = string
    description = "The Azure AD SAML certificate for the app."
}

variable "argo_git_app_id" {
    type = string
    description = "The Github app id."
}

variable "argo_git_app_installation_id" {
    type = string
    description = "The Github app installation id."
}

variable "argo_aad_admin_group_id" {
    type = string
    description = "The Azure AD group ID for administrative access to ArgoCD."
}

variable "argo_aad_read_only_group_id" {
    type = string
    description = "The Azure AD group ID for read-only access to ArgoCD."
}
```
