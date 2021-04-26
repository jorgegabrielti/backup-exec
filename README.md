# backup-exec

### Dependencies

1. bc
2. pssh
3. unzip
4. aws cli

```
dnf install -y bc pssh unzip bzip2
```

## AWS CLI install
```
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```
```
/usr/local/bin/aws --version
```

### Create a simbolic link
```
ln -s /usr/local/bin/aws /usr/bin/aws
``` 

### And test the command
```
aws --version
```

### Configuiring aws profile on your host
```
aws configure
```

