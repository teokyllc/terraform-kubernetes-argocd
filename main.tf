resource "null_resource" "setup_env" { 
  provisioner "local-exec" { 
    command = <<-EOT
      # Add bins
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x kubectl
      
      # Create kubeconfig
      mkdir ~/.kube
      echo "${var.aks_kubeconfig}" > ~/.kube/config
      
      # Setup Vault
      wget https://releases.hashicorp.com/vault/1.8.2/vault_1.8.2_linux_amd64.zip
      unzip vault_1.8.2_linux_amd64.zip
    EOT
  }
}

resource "null_resource" "install_argocd" { 
  depends_on = [null_resource.setup_env]  
  provisioner "local-exec" { 
    command = <<-EOT
      ./kubectl create namespace argocd 
      ./kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
      ./kubectl annotate svc argocd-server -n argocd service.beta.kubernetes.io/azure-load-balancer-internal=true
      ./kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
      ip=""
      while [ -z $ip ]; do
        echo "Waiting for external IP"
        ip=$(./kubectl get svc argocd-server --namespace argocd --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
        [ -z "$ip" ] && sleep 10
      done
      echo $ip
    EOT
  }
}

resource "null_resource" "add_argocd_config_map" { 
  depends_on = [null_resource.install_argocd]  
  provisioner "local-exec" { 
    command = <<-EOT
      cat <<EOF | ./kubectl apply -f -
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: argocd-cm
        namespace: argocd
        labels:
          app.kubernetes.io/name: argocd-cm
          app.kubernetes.io/part-of: argocd
      data:
        url: https://${var.argo_fqdn}
        users.anonymous.enabled: "false"
        users.session.duration: "2h"
        dex.config: |
          logger:
            level: debug
            format: json
          connectors:
          - type: saml
            id: saml
            name: Azure AD SAML
            config:
              entityIssuer: https://${var.argo_fqdn}/api/dex/callback
              ssoURL: ${var.sso_login_url}
              caData: ${var.sso_certificate}
              redirectURI: https://${var.argo_fqdn}/api/dex/callback
              usernameAttr: email
              emailAttr: email
              groupsAttr: Group
        resource.customizations.ignoreDifferences.admissionregistration.k8s.io_MutatingWebhookConfiguration: |
          jsonPointers:
          - /webhooks/0/clientConfig/caBundle
          jqPathExpressions:
          - .webhooks[0].clientConfig.caBundle
        resource.exclusions: |
          - apiGroups:
            - repositories.stash.appscode.com
            kinds:
            - Snapshot
            clusters:
            - "*.local"
        resource.compareoptions: |
          ignoreAggregatedRoles: true
          ignoreResourceStatusField: crd
        admin.enabled: "true"
        #accounts.alice: apiKey, login
        #accounts.alice.enabled: "false"
        timeout.reconciliation: 180s
      EOF
    EOT
  }
}

resource "null_resource" "add_argocd_rbac_config_map" { 
  depends_on = [null_resource.install_argocd]  
  provisioner "local-exec" { 
    command = <<-EOT
      cat <<EOF | ./kubectl apply -f -
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: argocd-rbac-cm
        namespace: argocd
      data:
        policy.default: role:no-access
        policy.csv: |
          p, role:no-access, *, *, */*, deny
          p, role:org-admin, applications, *, */*, allow
          p, role:org-admin, clusters, get, *, allow
          p, role:org-admin, repositories, get, *, allow
          p, role:org-admin, repositories, create, *, allow
          p, role:org-admin, repositories, update, *, allow
          p, role:org-admin, repositories, delete, *, allow
          g, "${var.argo_aad_admin_group_id}", role:org-admin
          g, "${var.argo_aad_read_only_group_id}", role:readonly
      EOF
    EOT
  }
}

resource "null_resource" "add_argocd_github_app_config_map" { 
  depends_on = [null_resource.install_argocd]  
  provisioner "local-exec" { 
    command = <<-EOT
      export VAULT_ADDR=https://vault.teokyllc.internal:8200
      export VAULT_TOKEN=${var.vault_token}
      PRIVATEKEY=$(./vault kv get --field=cert secrets/github-app-cert)
      cat <<EOF | ./kubectl apply -f -
      apiVersion: v1
      kind: Secret
      metadata:
        name: github-creds
        namespace: argocd
        labels:
          argocd.argoproj.io/secret-type: repo-creds
      stringData:
        url: https://github.com/ataylor05/Argo-Control
        githubAppID: "${var.argo_git_app_id}"
        githubAppInstallationID: "${var.argo_git_app_installation_id}"
        githubAppPrivateKey: $PRIVATEKEY
      EOF
    EOT
  }
}
