# Quick Win - Collecting data from SFTP with Data Factory
**Produced by Dave Lusty**

# Introduction
This demo shows how to ingest data from an SFTP source to your Azure Data Lake. This can be useful when third parties share data with you via SFTP rather than giving access to the source systems. You could also use a Logic App with a new file trigger to copy the files into blob storage if you prefer.

# SFTP Server
For this demo we'll need an SFTP server. Luckily this is very easy since SFTP is a part of SCP which is included in most Linux distributions. Please bear in mind that FTPS, or FTP over SSL (aka TLS) is a different protocol and different server so setup may be more involved.

## Create Server
Log into the Azure portal and select create new resource. Choose any Linux distribution, here I'm choosing Ubuntu Server 18.04 LTS because it's on the list of popular things so I don't need to search for it.
![1.newserver.png](images/1.newserver.png)
Next, configure your server. Create a new resource group and give the server a name. Here I've used the default server size of D2s v3, but even the smallest, cheapest server will be fine for demo purposes since it's just a file server. Since My server will only be there for the duration of the demo I don't mind using a more expensive one. Next, I choose password for simplicity and create an account. You can and should use SSH keys in production, and the process works in the same way - this is just easier to demo. Finally, ensure that the SSH port is open so we can access the machine for configuration as well as SFTP purposes.
![2.configserver](images/2.configserver.png)
Next, I use the defaults for the networking. This opens SSH and creates a new public IP. The system must be available publicly for Data Factory to access without an integration runtime. As always, the integration runtime would work the same way if you need to run locally, but to keep the demo short I'm leaving that part out. It's likely a third party SFTP server would be public anyway for you to access remotely.
![3.networkconfig.png](images/3.networkconfig.png)
The remainder of the configuration is default aside from adding a tag to mark this as a demo system.

## Create Data
Log in to your server over SSH using a client tool like PuTTY. From here you'll need to create some data - I've created a script to do this randomly.

```bash
#!/bin/bash
# Create a bunch of random CSV data in a directory

mkdir data

for value in {1..100}
do
  randomno=$((RANDOM%3))
  sleep $randomno
  runtime=`date +"%F-%T"`
  echo "date, delay" > ./data/$runtime.csv
  echo "$runtime, $randomno" >> ./data/$runtime.csv
done
```