

# create SSH key with no passphrase, we'll be using an ss_username of "packer"
 $  cd ../keys
 $  ssh-keygen -t rsa -f ./packer-key -C packer

# create ssh firewall
 $  terraform init
 $  terraform apply

# build image
 $  packer build -var hashi_base.pkr.hcl