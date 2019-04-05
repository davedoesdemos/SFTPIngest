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
Log in to your server over SSH using a client tool like PuTTY. From here you'll need to create some data - I've created a script to do this randomly. You can either upload the copy in the repository, or you can paste the below into a new file. My preferred way to create the new file is with nano editor as it's most similar to GUI notepads, so use "nano ./createCSVdata.sh" to create and open the file, then just paste the below into your PuTTY window.

```bash
#!/bin/bash
# Create a bunch of random CSV data in a directory

mkdir data

for value in {1..100}
do
  randomno=$((RANDOM%200))
  sleep $randomno
  runtime=`date +"%F-%T"`
  echo "date,delay" > ./data/$runtime.csv
  echo "$runtime,$randomno" >> ./data/$runtime.csv
	echo $value
done
```

Press ctrl+O to save, then ctrl+X to exit. Now run "chmod 744 ./createCSVdata.sh" to make it executable then run "./createCSVdata.sh". This will take some time to run since it loops 100 times and waits a random time up to 200 seconds in each loop. It'll output a CSV file with the timestamp and random number for each loop just to give you some data in the file to work with. Leave this running and move on to the next part.

# Blob Storage
Next, create a new storage account in your resource group. We just need normal Blob storage here since it's cheapest and we're just using it for our raw data dump into the lake. As always, choose LRS not the default RA-GRS for your demo to save money.
![4.storageconfig.png](images/4.storageconfig.png)
Once that's created, go to Blob and create a container called sftpdemo with a private access level.
![5.storageconfig2.png](images/5.storageconfig2.png)

# Data Factory
## Create the Data Factory
Finally, we create a Data Factory. Choose your resource group and V2, everything else can be defaults.
![6.datafactoryconfig.png](images/6.datafactoryconfig.png)

## Set up the pipeline
Once the Data Factory is deployed, we'll create the resources we need to ingest data. We always do this in the order Connections, Datasets, Pipelines, Triggers. This is because they are each a dependency of the other. While the interface does allow you to create things in any order, you can't validate or save if you have unmet dependencies. If you ever use PowerShell, you'll need to know this order.

### Connections
In the ADF designer, go to the author tab (the pencil) and click connections. Under Linked Services click New and search for SFTP then select this and click Continue.
![7.NewConnection.png](images/7.NewConnection.png)
Copy the public IP of the Linux system and paste it into the Host box. I've disabled host key validation here for simplicity but in production you should definitely use this for enhanced security. This key can be found in the SSH config on most systems under /etc/ssh. Enter your username and password then click test connection. You should get a connection successful message back. Click Finish.
![8.SFTPConfig.png](images/8.SFTPConfig.png)
Now create another linked service for Blob. Here you just need to use the dropdown boxes to select your storage account.
![9.NewConnection2.png](images/9.NewConnection2.png)

### Datasets
Next, we create the datasets. Select Add Dataset from the menu and search for SFTP. Give the dataset a name.
![10.DatasetName.png](images/10.DatasetName.png)
On the Parameters tab, create two new parameters, runstart and runend. These will contain the timestamp for the beginning and end of the pipeline run from the trigger. We'll use these to filter the files.
![11.Parameters.png](images/11.Parameters.png)
On the Connection tab, select your linked service and browse to your data directory. This will be in /home/<yourusername>/data if you left everything default, otherwise you can use the pwd command in PuTTY to find your current directory. Click Preview Data and you should see some data come up. Do this before adding the parameters to the start and end time, otherwise the preview is greyed out. Select text format and comma delimeter here since we're using CSV data. Check the box to say column names are in the first row.
![12.Connection.png](images/12.Connection.png)
Next, go to the Schema tab and click Import Schema. You should see the column names date and delay. If not you may not have selected the checkbox for column names in the last step (you'd see prop_0 and prop_1 here instead).
![13.Schema.png](images/13.Schema.png)
Now go back to the connection tab and use the Dynamic Content buttons to add the parameters to start time and end time.
![14.Params.png](images/14.Params.png)
As an alternative to the start and end time filters, we can use wildcards in the name field to select files. if the files are on the SFTP server with names such as "sales2019-04-03-12:43:22.csv" then we could set the wildcard to "sales2019-04-03-12*" to collect all files during the hour of 12 on that date. Use the dynamic content wizard to craft your filter using the start time from the trigger.
![15.alternative.png](images/15.alternative.png)
Now create another new dataset for the Blob store. Call this one RawData since it will be the raw section of the data lake.
![16.blobdataset.png](images/16.blobdataset.png)
Now select your storage connection and browse to the container you created. Tick the column names in first row box
![17.blobdataset2.png](images/17.blobdataset2.png)
On the Schema tab create two columns, date and random. These names do not need to match those in the files, they are the destination schema.
![18.BlobSchema.png](images/18.BlobSchema.png)

## Pipeline
Next, create a new pipeline and give it a name. On the parameters tab, create two parameters, runstart and runend.
![19.params.png](images/19.params.png)
Now, drag a copy data task into the designer. Give this a name and select the SFTP dataset as the source. For the two parameters, use dynamic content to pass the pipeline parameters to the dataset ones we created earlier.
![20.Source.png](images/20.Source.png)
Similarly, select the sink dataset as the Blob set.
![21.sink.png](images/21.sink.png)
Under mapping, click import schemas and map the date and random fields.
![22.mapping.png](images/22.mapping.png)
Now we're all set to run the pipeline. Click Publish All to save everything ready to create a trigger.

## Trigger
Click add trigger and choose new/edit. Next click New. Give the trigger a useful name so that you can identify the jobs created from it. Choose tumbling window as the trigger type and set the start time to something around the time you ran the crateCSVdata.sh script. Set the end time to the same plus an hour and the recurrence to 15 minutes. Remember that you'll be charged more for more runs so for demos be as specific as you can.
![23.Trigger.png](images/23.Trigger.png)
Copy the following into the parameters boxes. This will fill the parameters with the timestamps needed to filter files based on the tumbling window. Click finish and then publish all.
runstart
```@trigger().outputs.windowStartTime
runend
```@trigger().outputs.windowEndTime
![24.params.png](images/24.params.png)
Now you should see several runs under the monitor tab. 
![25.PipelineRuns.png](images/25.PipelineRuns.png)
Click the pipeline symbol on each to see the copied data for that run. Then click the watch (glasses) button to see more details.
![26.watch.png](images/26.watch.png)
Under details you'll see how many files and how much data was copied.
![27.Details.png](images/27.Details.png)
If you look into your Blob store you'll now see the copied files. You may want to try this out with a trigger than starts later or finishes earlier than the available files so that you can see each tumbling window copies only the correct files.
![28.Blobfiles.png](images/28.Blobfiles.png)
If you open one of the files you'll see the new schema we created with different headers.
![29.newSchema.png](images/29.newSchema.png)

# Conclusion
This demo showed how to selectively copy files from SFTP sources. We copy because the information we're pointing at is the source data - we never move because we might need to change the ingest process later and re-run the copy job with different parameters. Data retention should be managed at the source system, keeping data for as long as needed and running regular delete jobs once data is confirmed to have been ingested. Generally this retention will be 30 days, a year, or 5 years depending on requirements.