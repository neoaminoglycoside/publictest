# Ansible project for test task

## The following variables must be set up for full functionality:
Variable | Description
--- | --- 
install_nginx | (true or false) Install Nginx Or Not
install_monit | (true or false) Is the monit must be installed
timezone | Timezone which will be used in system
locale | Locale which will be used in system 
ssh_port | ssh port which will be used in system  
ssh_root_permit | (yes or no) Allow root user login via ssh
monit_port | Monit port for web interface
service_account | username to create
service_account_usepassword | (true or false) is user allowed to login
service_account_pass | User password for created user
htaccess_username | Basic auth nginx username
htaccess_password | Basic auth nginx password
## Run yourself
First of all you need to configure your inventory


####  Change ansible inventory

```
127.0.0.1  ansible_connection=local ansible_host=127.0.0.1 ansible_user=root

[timezone]
127.0.0.1

[locale]
127.0.0.1

[nginx]
127.0.0.1

[user]
127.0.0.1

[monit]
127.0.0.1

[ssh]
127.0.0.1
```

Accordingly you can exclude nginx, timezone, locale, user, monit, ssh.

#### Run as usual Ansible playbook

```bash
ansible-playbook -i inventory ./test02.yml
```

#### Run as Ansible playbook with specific tags (timezone, nginx, user, monit, ssh, locale)
```bash
ansible-playbook -i inventory ./test02.yml --tags user
```
