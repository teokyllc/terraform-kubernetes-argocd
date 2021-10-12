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
      kubectl create namespace argocd 
      wget https://raw.githubusercontent.com/teokyllc/terraform-kubernetes-argocd/main/kustomize/argocd-repo-server-deploy.yaml
      wget https://raw.githubusercontent.com/teokyllc/terraform-kubernetes-argocd/main/kustomize/kustomization.yaml
      kubectl -n argocd apply -k .
      kubectl annotate svc argocd-server -n argocd service.beta.kubernetes.io/azure-load-balancer-internal=true
      kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    EOT
  }
}



#resource "null_resource" "add_argocd_github_app_config_map" { 
#  depends_on = [null_resource.install_argocd]  
#  provisioner "local-exec" { 
#    command = <<-EOT
#      cat <<EOF | kubectl apply -f -
#      apiVersion: v1
#      kind: Secret
#      metadata:
#        name: github-creds
#        namespace: argocd
#        labels:
#          argocd.argoproj.io/secret-type: repo-creds
#      stringData:
#        url: "https://github.com/teokyllc"
#        githubAppID: "${var.argo_git_app_id}"
#        githubAppInstallationID: "${var.argo_git_app_installation_id}"
#        githubAppPrivateKey: "${var.github_app_private_key}"
#      EOF
#    EOT
#  }
#}

#resource "null_resource" "add_argocd_server_tls_certificate" { 
#  depends_on = [null_resource.install_argocd]  
#  provisioner "local-exec" { 
#    command = <<-EOT
#      cat <<EOF | kubectl apply -f -
#      apiVersion: cert-manager.io/v1
#      kind: Certificate
#      metadata:
#        name: argocd-teokyllc-internal
#        namespace: argocd
#      spec:
#        secretName: argocd-server-tls
#        duration: 2160h # 90d
#        renewBefore: 360h # 15d
#        subject:
#          organizations:
#            - teokyllc
#        commonName: argo.teokyllc.internal
#        isCA: false
#        privateKey:
#          algorithm: RSA
#          encoding: PKCS1
#          size: 2048
#        usages:
#          - server auth
#          - client auth
#        dnsNames:
#          - argo.teokyllc.internal
#        ipAddresses:
#          - 10.1.0.5
#        issuerRef:
#          name: vault-issuer
#          kind: ClusterIssuer
#          group: cert-manager.io
#      EOF
#    EOT
#  }
#}
