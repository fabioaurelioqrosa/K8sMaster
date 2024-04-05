sudo kubeadm reset --force

sudo systemctl stop kubelet
sudo systemctl stop crio
sudo systemctl daemon-reload


sudo dnf remove -y kubernetes-kubeadm kubernetes-client crun cri-o cri-tools

sudo rm -R /etc/cni/net.d/
sudo rm -R /etc/crio/

sudo firewall-cmd --set-default-zone=internal
sudo firewall-cmd --permanent \
  --remove-port=6443/tcp \
  --remove-port=2379-2380/tcp \
  --remove-port=10250/tcp \
  --remove-port=10259/tcp \
  --remove-port=10257/tcp 
sudo firewall-cmd --reload



cd ~

rm -R ./.kube/
rm ./kubeadmin-config.yaml
