#!/bin/bash
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." 2>&1
  exit 1
fi

# Determine if we're running in EC2 or Vagrant.  Default will be EC2
if [ -d /home/vagrant ]; then
    TARGET_USER='vagrant'
    VAGRANT=true
    if [ -z "$1" ]; then
        echo "You must specify the security group when using Vagrant.  $0 WebSG | DBSG | MonitorSG | GoServerSG"
        exit 255
    fi
elif [ -d /home/ubuntu ]; then
    TARGET_USER='ubuntu'
    VAGRANT=false
else
    echo No vagrant user or ubuntu user found.  Are you in EC2 or Vagrant?
    exit 255
fi
HOME_TARGET="/home/$TARGET_USER"

DOWNLOAD_URL=http://thoughtworksinc.github.com/InfraTraining/files

cd /root

# common setup for all nodes, applied by cloud formation
# apt-get update


# do something node specific based on the passed security group (EC2 only)
if [ -n "$1" ]; then
    SECURITY_GROUP=$(echo $1 | cut -d- -f 2)
else
    SECURITY_GROUP=$(curl -s http://169.254.169.254/latest/meta-data/security-groups | cut -d- -f 2)
fi

function setup_puppet {
	# Determine if Puppet 3 is already installed
	if [[ `dpkg -s puppet|grep Version|cut -c 10-10` -eq '3' ]]; then
		echo "Puppet 3.x is already installed."
		return 0
	fi
	# Ensure Puppet < 3 doesn't already exist on this system
	apt-get purge -y puppet-common
	
	# Install Puppet 3 using Puppet Labs repo
	codename=`lsb_release -c -s`
	wget -N http://apt.puppetlabs.com/puppetlabs-release-${codename}.deb
	dpkg -i puppetlabs-release-${codename}.deb
	apt-get update
	
	# Switch default Ruby to 1.9.3 (Ubuntu == 1.9.1) before installing [for good measure]
	apt-get install -y ruby1.9.1-full
	update-alternatives --set ruby /usr/bin/ruby1.9.1
	update-alternatives --set gem /usr/bin/gem1.9.1
	
	# Now install Puppet 3.x
	apt-get install -y puppet
	
    # apt-get install -y ruby1.8 rubygems ruby1.8-dev libruby1.8 libshadow-ruby1.8 libaugeas-ruby1.8
}

function setup_web {
    echo "nothing to do"
}

function setup_db {
    echo "nothing to do"
}

function setup_monitor {
	if [[ ! -f /root/provisioned.txt ]]; then
		setup_puppet

	    wget -N $DOWNLOAD_URL/nagios.tgz
	    tar zxvf nagios.tgz
	    puppet apply --modulepath=modules nagios.pp

	    # Moved all this to bash temporarily.  Would normally be in Puppet too.
	    # build-essential for native extensions in gems
		# git is for checking out cucumber-nagios from Github via Bundler
	    apt-get install --yes git build-essential libxml2-dev libxslt-dev make
		gem install bundler -v 1.3.5

	    wget -N $DOWNLOAD_URL/cucumber.tgz
	    tar zxvf cucumber.tgz
	    cp -r cucumber ${HOME_TARGET}
	    chown -R $TARGET_USER:$TARGET_USER ${HOME_TARGET}/cucumber
	    cd ${HOME_TARGET}/cucumber
		pwd
	    bundle install --system
	
		# Bundler source gems (from Github for exampple) aren't installed system-wide.  To install system-wide, build them, then install via gem.
		cucumbernagios=`bundle show cucumber-nagios`
		cd ${cucumbernagios}
		gem build cucumber-nagios.gemspec
		gem install ./cucumber-nagios-0.9.3.gem
		cd -
		touch /root/provisioned.txt
		echo "Inital provisioning complete."
	fi
	if [[ -d /vagrant/nagios ]]; then
		echo "Nagios config files found.  Copying to /etc/nagios3/conf.d/"
		cp -v -u --backup /vagrant/nagios/* /etc/nagios3/conf.d/
	fi
		
}

function setup_git {
    mkdir -p git-install
    cd git-install
    wget -N $DOWNLOAD_URL/git.tgz
    tar zxvf git.tgz
    puppet apply --modulepath=modules git.pp
    cd ..
}

function setup_go {
    apt-get -y install python-pip
    pip install boto
    mkdir -p go-install
    cd go-install
    wget -N $DOWNLOAD_URL/go.tgz
    tar zxvf go.tgz
    puppet apply --modulepath=modules go.pp
    apt-get install --yes build-essential libxml2-dev libxslt-dev make
    gem install bundler
	gem install cucumber
    cd ..
}

case $SECURITY_GROUP in
    WebSG)
        setup_web
        ;;
    DBSG)
        setup_db
        ;;
    MonitorSG)
        setup_monitor
        ;;
    GoServerSG)
        setup_puppet
        setup_git
        setup_go
        ;;
esac
