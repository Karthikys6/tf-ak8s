
resource "local_file" "kubeconfig" {
  depends_on   = [azurerm_kubernetes_cluster.ak8s_cluster]
  filename     = "kubeconfig-${var.env}"
  content      = azurerm_kubernetes_cluster.ak8s_cluster.kube_config_raw
}
