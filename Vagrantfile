# -*- mode: ruby -*-
# vi: set ft=ruby :

# This Vagrant file creates and provisions a VM used for development
# of the NHM data portal. It provisions in a single VM:
# - The application server (Ckan + extentions).

VM_IP = "10.11.12.13"

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Base box
  config.vm.box = "precise64" 
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  # Ensure synced folder is over NFS, as it is quite slow otherwise
  # config.vm.synced_folder ".", "/vagrant", :nfs => true
  config.vm.synced_folder "./src", "/usr/lib/ckan/default/src", :nfs => true

  config.vm.network :private_network, ip: VM_IP

  # Call the app provision script
  config.vm.provision "shell",
    path: "provision/provision_app.sh",
    args: "-r /vagrant/provision"
end