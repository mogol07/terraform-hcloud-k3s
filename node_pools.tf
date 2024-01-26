module "node_pools" {
  source     = "./node_pool"
  depends_on = [module.node_pool_cluster_init]

  for_each               = { for k, v in var.node_pools : k => v if !v.cluster_can_init }
  cluster_name           = var.cluster_name
  name                   = each.key
  location               = var.location
  delete_protection      = var.delete_protection
  node_type              = each.value.type
  node_count             = each.value.count
  node_labels            = merge(each.value.labels, each.value.is_control_plane ? { "control-plane" = "true" } : {})
  image                  = var.image
  ssh_keys               = [for k in hcloud_ssh_key.pub_keys : k.name]
  firewall_ids           = each.value.is_control_plane ? var.control_plane_firewall_ids : var.worker_node_firewall_ids
  hcloud_network_id      = hcloud_network.private.id
  enable_public_net_ipv4 = var.enable_public_net_ipv4
  enable_public_net_ipv6 = var.enable_public_net_ipv6
  default_gateway        = local.default_gateway

  runcmd = concat([
    local.security_setup,
    each.value.is_control_plane ? local.control_plane_k8s_security_setup : "",
    local.k8s_security_setup,
    local.package_updates,
    "export K3S_URL='https://${hcloud_server_network.gateway.ip}:6443'",
    each.value.is_control_plane ?
    <<-EOT
      ${local.k3s_install~}
      sh -s - server \
      ${local.control_plane_arguments~}
      ${!each.value.schedule_workloads ? "--node-taint CriticalAddonsOnly=true:NoExecute" : ""}  %{for k, v in each.value.taints} --node-taint "${k}:${v}" %{endfor}  \
      ${var.control_plane_k3s_additional_options}  %{for key, value in merge(each.value.labels, each.value.is_control_plane ? { "control-plane" = "true" } : {})} --node-label=${key}=${value} %{endfor} %{for key, value in local.kube-apiserver-args} --kube-apiserver-arg=${key}=${value} %{endfor}
      EOT
    :
    <<-EOT
      ${local.k3s_install~}
      sh -s - agent ${local.common_arguments~}
      EOT
  ], var.additional_runcmd)
  additional_cloud_init = var.additional_cloud_init
  prices                = local.prices
}
