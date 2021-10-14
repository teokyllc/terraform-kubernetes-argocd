resource "null_resource" "setup_env" { 
  provisioner "local-exec" { 
    command = <<-EOT
      mkdir ~/.kube
      echo "${var.kubeconfig}" > ~/.kube/config
    EOT
  }
}

resource "null_resource" "install_argocd" { 
  depends_on = [null_resource.setup_env]  
  provisioner "local-exec" { 
    command = <<-EOT
      kubectl create namespace ${var.argocd_namespace}
      wget https://raw.githubusercontent.com/teokyllc/terraform-kubernetes-argocd/main/kustomize/argocd-repo-server-deploy.yaml
      wget https://raw.githubusercontent.com/teokyllc/terraform-kubernetes-argocd/main/kustomize/kustomization.yaml
      kubectl -n ${var.argocd_namespace} apply -k .
      kubectl annotate svc argocd-server -n ${var.argocd_namespace} service.beta.kubernetes.io/azure-load-balancer-internal=true
      kubectl patch svc argocd-server -n ${var.argocd_namespace} -p '{"spec": {"type": "LoadBalancer"}}'
    EOT
  }
}

resource "null_resource" "configure_argocd" { 
  depends_on = [null_resource.install_argocd]  
  provisioner "local-exec" { 
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: argocd-cm
        namespace: ${var.argocd_namespace}
        labels:
          app.kubernetes.io/name: argocd-cm
          app.kubernetes.io/part-of: argocd
      data:
        configManagementPlugins: |
          - name: argocd-vault-plugin
            generate:
              command: ["argocd-vault-plugin"]
              args: ["generate", "./"]
          - name: argocd-vault-plugin-helm
            generate:
              command: ["sh", "-c"]
              args: ["helm template . > all.yaml && argocd-vault-plugin generate all.yaml"]
          - name: argocd-vault-plugin-kustomize
            generate:
              command: ["sh", "-c"]
              args: ["kustomize build . > all.yaml && argocd-vault-plugin generate all.yaml"]
        url: https://${var.argo_fqdn}/
        users.anonymous.enabled: "$argo_anonymous_users_enabled"
        users.session.duration: "1h"
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
              ssoURL: ${var.argo_sso_login_url}
              caData: ${var.argo_sso_certificate}
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
        admin.enabled: "${var.argo_admin_user_enabled}"
        timeout.reconciliation: 180s
      EOF
    EOT
  }
}

resource "null_resource" "configure_argocd_rbac" { 
  depends_on = [null_resource.install_argocd]  
  provisioner "local-exec" { 
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: argocd-rbac-cm
        namespace: ${var.argocd_namespace}
      data:
        policy.default: role:no-access
        policy.csv: |
          p, role:no-access, *, *, */*, deny
          g, "${var.argo_aad_admin_group_id}", role:admin
          g, "${var.argo_aad_read_only_group_id}", role:readonly
      EOF
    EOT
  }
}

resource "null_resource" "add_argocd_github_app_config_map" { 
  depends_on = [null_resource.install_argocd]  
  provisioner "local-exec" { 
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: v1
      kind: Secret
      metadata:
        name: github-creds
        namespace: ${var.argocd_namespace}
        labels:
          argocd.argoproj.io/secret-type: repo-creds
      stringData:
        url: "https://github.com/teokyllc"
        githubAppID: "${var.argo_git_app_id}"
        githubAppInstallationID: "${var.argo_git_app_installation_id}"
        githubAppPrivateKey: "${var.github_app_private_key}"
      EOF
    EOT
  }
}

resource "null_resource" "add_argocd_vault_plugin_secret" { 
  depends_on = [null_resource.install_argocd]  
  provisioner "local-exec" { 
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      kind: Secret
      apiVersion: v1
      metadata:
        name: argocd-vault-plugin-credentials
        namespace: argocd
      type: Opaque
      stringData:
        AVP_AUTH_TYPE: approle
        AVP_TYPE: vault 
        AVP_ROLE_ID: 92c2aaa5-a920-5538-aef2-5212e2f88396
        AVP_SECRET_ID: ${var.avp_secret_id}
      EOF
    EOT
  }
}

resource "null_resource" "add_argocd_server_tls_certificate" { 
  depends_on = [null_resource.install_argocd]  
  provisioner "local-exec" { 
    command = <<-EOT
      sleep 120
      cat <<EOF | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: argocd-teokyllc-internal
        namespace: ${var.argocd_namespace}
      spec:
        secretName: argocd-server-tls
        duration: 2160h # 90d
        renewBefore: 360h # 15d
        subject:
          organizations:
            - teokyllc
        commonName: argo.teokyllc.internal
        isCA: false
        privateKey:
          algorithm: RSA
          encoding: PKCS1
          size: 2048
        usages:
          - server auth
          - client auth
        dnsNames:
          - argo.teokyllc.internal
        issuerRef:
          name: vault-issuer
          kind: ClusterIssuer
          group: cert-manager.io
      EOF
    EOT
  }
}
