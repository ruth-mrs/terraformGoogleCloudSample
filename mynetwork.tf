# Para mas detalles (opocional): export TF_LOG=TRACE


# Create the mynetwork network
resource "google_compute_network" "mynetwork" {
  name                    = "mynetwork-tf"
  auto_create_subnetworks = "true"
  project                 = var.gcp_project
}

# Add a firewall rule to allow HTTP, SSH, RDP, and ICMP traffic on mynetwork
resource "google_compute_firewall" "mynetwork-allow-http-ssh-rdp-icmp" {
  name    = "mynetwork-tf-allow-http-ssh-rdp-icmp"
  network = google_compute_network.mynetwork.name
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "8080"]
  }
  
  # firewall will apply  to traffic that has source IP address in these ranges, any IP: 0.0.0.0/0
  source_ranges = ["0.0.0.0/0"]   

  allow {
    protocol = "icmp"
  }
}

# Create the jenkins-vm instance
module "jenkins-vm" {
  source          = "./instance"
  instance_name   = "jenkins-vm-tf"
  instance_region = "us-central1"
  instance_zone   = "us-central1-a"
  instance_type   = "e2-medium"
  image           = "ubuntu-os-cloud/ubuntu-2204-lts" # ubuntu-2204-lts"
  #  startup_script      = "${var.init_scrip_docker}"
  instance_subnetwork = google_compute_network.mynetwork.self_link
}

# Create the web-deploy-vm" instance
module "web-deploy-vm" {
  source          = "./instance"
  instance_name   = "web-deploy-vm-tf"
  instance_region = "us-central1"
  instance_zone   = "us-central1-a"
  instance_type   = "e2-medium"
  image           = "ubuntu-os-cloud/ubuntu-2204-lts"  #ubuntu-2204-lts"  
  #  startup_script      = "${var.init_scrip_apache2}"
  instance_subnetwork = google_compute_network.mynetwork.self_link
}


resource "null_resource" "provision-jenkins-vm" {

  provisioner "remote-exec" {
    connection {
      host        = module.jenkins-vm.instance_ip_addr
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
    }

    ## Script inicialización jenkins-vm
    inline = [
      "sudo apt-get update -y",
      "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections",
      "echo 'debconf debconf/frontend select Noninteractive'  | sudo debconf-set-selections",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y python-minimal",
      "sudo timedatectl set-timezone Europe/Madrid",
      # Instalacion de docker
      # Add Docker's official GPG key:
      "sudo apt-get update",
      "sudo apt-get install ca-certificates",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      # Add the repository to Apt sources:
      "echo \\",
      "  \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \\",
      "  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | \\",
      "  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y",
      "sudo usermod -aG docker $${USER}",
    ]
    on_failure = continue
  }
  depends_on = [
    # Init script must be created before this IP address could
    # actually be used, otherwise the services will be unreachable.
    module.jenkins-vm.instance_ip_addr
  ]
}

resource "null_resource" "provision-deploy-vm" {

  provisioner "remote-exec" {
    connection {
      host        = module.web-deploy-vm.instance_ip_addr
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
    }

    ## Script inicialización web-deploy-vm
    inline = [
      "sudo apt-get update -y",
      "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections",
      "echo 'debconf debconf/frontend select Noninteractive'  | sudo debconf-set-selections",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y python-minimal",
      "sudo timedatectl set-timezone Europe/Madrid",
      # Instalacion de docker
      # Add Docker's official GPG key:
      "sudo apt-get update",
      "sudo apt-get install ca-certificates",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      # Add the repository to Apt sources:
      "echo \\",
      "  \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \\",
      "  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | \\",
      "  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y",
      "sudo usermod -aG docker $${USER}",
      # Instalacion de Java jdk 17
      "sudo apt install openjdk-17-jdk -y",
      "echo JAVA_HOME=\"/usr/lib/jvm/java-17-openjdk-amd64/jre\" | sudo tee -a /etc/environment",
      # Instalacion de Node JS LTS. Install Node.js and npm using the Node Version Manager (nvm)
      "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash",
      "export NVM_DIR=\"$HOME/.nvm\"",
      "[ -s \"$NVM_DIR/nvm.sh\" ] && \\. \"$NVM_DIR/nvm.sh\"",
      "nvm install --lts"
    ]
    on_failure = continue
  }
  depends_on = [
    # Init script must be created before this IP address could
    # actually be used, otherwise the services will be unreachable.
    module.web-deploy-vm.instance_ip_addr
  ]
}
