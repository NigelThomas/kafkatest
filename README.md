# kafkatest

This git repo includes code to test Kafka features.

Each test lives in its own subdirectory. One test ("experiment") can be executed
at a time (by starting up a docker instance or using `docker-compose`).

The docker instances rely on the `sqlstream/streamlab-git` image.

## Kafka support

We could use the `sqlstream/complete` image and make use of its local Kafka support - but that makes it impossible to kill SQLstream while keeping the Kafka cluster running.

So instead we use separate Kafka container(s) and orchestrate using `docker-compose`. Typically we use the
`https://github.com/wurstmeister/kafka-docker` project.

## Experiments

Each experiment is created in a separate subdirectory. When the container is started the experiment name is passed in using the `EXPERIMENT_NAME` environment variable. The top level `pre-startup.sh` picks the correct setup scripts to run.

### exactly-once-time

This tests the use of time watermarks for the exactly once processing.

**NOTE** we should add parameterisation to allow increase in number of partitions, sizes of batches etc

This is intended to test the Kafka-to-Kafka exactly once processing as documented at https://docs.sqlstream.com/integrating-sqlstream/exactly-once/

* Read watermark timestamp from source
* Insert watermark time into target topic
* Ensure that on restart the reading restarts from after the last committed timestamp
 * include `OPTIONS_QUERY 'SELECT * FROM (VALUES(sys_boot.mgmt.watermark_timestamp(''{broker:port}'', ''{sink_topic}'', ''LOCALDB.{targetschema}.{target_pump}'')) AS options(STARTING_TIME)'`

Issues:
* If the last committed timestamp is at epoch time M (milliseconds) we need to restart from time M+1 because 
we assume that all data at time <= M has been committed
* If there are 2 or more partitions in the source data we cannot assume that data from P1 and P2 will be processed
in time order. We will likely read a batch from P1 and then a batch from P2 (and so timestamps may be slightly disordered).
* So how do we reposition to the "right" place?

Workaround:
* Start from time > (M - epsilon) where epsilon is a big enough interval to ensure that we do re-read all required data 
(at least the size of one batch - even if we also re-read some rows where rowtime <= M)
 * It is better to set epsilon larger - it will result in more rows being read and rejected, but reduces the risk of completely
 missing any rows.
* Create a relational view over the `watermark_timestamp` function
```
   create or replace view MyKafkaWatermarkTime as
   select * from table(
       sys_boot.mgmt.watermark_timestamp('{broker:port}', '{sink_topic}', 'LOCALDB.{targetschema}.{target_pump}')
   );
```
* Use the view in OPTIONS QUERY
```
   OPTIONS_QUERY 'SELECT STARTING_TIME - INTERVAL ''{epsilon}'' SECOND AS STARTING_TIME FROM MyKafkaWatermarkTime'
```
* Add an explicit filter after the source to filter out "too early" rows (rowtime <=M) using the same function call
```
   SELECT STREAM s.* FROM mystream s
   WHERE  SQLSTREAM_PROV_KAFKA_TIMESTAMP > sys_boot.mgmt.watermark_timestamp('{broker:port}', '{sink_topic}', 'LOCALDB.{targetschema}.{target_pump}') 
```
* Finally add rowtime promotion and T-sort `WITHIN INTERVAL '{epsilon}' SECOND`

### exactly-once-offset

This will test the use of (partition, offset) tuples for exactly once processing. More details TBA.

### window-perf

This test is intended to take the output of the data generator and see how much time and memory is used in reading the data files and building up window state.

Initially data is supplied in file format (future: supply via Kafka).

The data generator is documented below.

Data is produced in a flat file format; it is easy to break data down into smaller files using standard unix utilities like `split`. 



## Generating failures

We can have a UDX that fails
* either when a control message is injected (time dependent, independent of main data flow)
* after a specified or random number of records (so can be repeatable / predictable)

Or we can literally stop / kill SQLstream with degrees of prejudice
* Stop the pumps
* Stop the service
* Kill the process
* Kill the entire container

## Detecting failures

This test is more about recovery than failure detection. We can detect "end of messages" in the target topic; either because of a failure, or because we have run out of data.

## Restart and recovery

Type | Description
--- | ----
Basic | Stop and restart pumps
Crash Recovery | Kill the SQLstream server/container; restart the server

## Validating results

We verify that each row is received into the sink topic, and there are no missing rows. In particular we check that there
are no gaps or duplicates around the failure time.

For time based tests we also check the rows are ordered by time.

## Supporting components

Component |Description
--- | ---
Data | we can use one of the gallery demo data sets
Kafka | We use docker image `wurstmeister/kafka` to form a kafka cluster of one or more brokers
Kafkacat | we use docker image `edenhill/kafkacat` to pipe data into and out of kafka topics


## Using sqlstream/complete

### Source data

We can rely on the local Kafka broker (as long as we don't stop it!).

Dribble data into the `IoT` topic:

```
. /etc/sqlstream/environment
$SQLSTREAM_HOME/demo/IoT/start.sh
```

This launches the dribbler process in the background, so the foreground terminal can be used for monitoring.

### Target Data

We can subscribe to the target topic `iot_sink` using either `kafka-console-consumer.sh` or `kafkacat`:

```
kafkacat -C -b $HOSTNAME -t iot_sink
```

You can exit after a given number of records using `-c <count>`.

## generate_data.py

Data generator that can build data files containing `timestamp`, `userId`, `deviceId`, `visitId` and N feature values.

```
$ python generate_data.py --help
usage: generate_data.py [-h] [-c USER_COUNT] [-t OUTPUT_TIME]
                        [-r TRANSACTION_RATE] -F FEATURE_FILE [-k] [-n]

optional arguments:
  -h, --help            show this help message and exit
  -c USER_COUNT, --user_count USER_COUNT
                        number of users to be created
  -t OUTPUT_TIME, --output_time OUTPUT_TIME
                        time: number of hours of calls (default 24)
  -r TRANSACTION_RATE, --transaction_rate TRANSACTION_RATE
                        average number of transactions per second (default 10)
  -F FEATURE_FILE, --feature_file FEATURE_FILE
                        name of input file describing features and their
                        cardinality
  -k, --trickle         Trickle one second of data each second
  -n, --no_trickle      No trickling - emit data immediately
```

The feature file looks like this:
```
$ cat feature_file.csv 
name,type,length,cardinality
f01,x,5,10
f02,x,10,10
f03,x,10,10
f04,x,10,10
f05,x,10,100
f06,x,10,100
f07,x,20,1000
f08,x,20,1000
f09,x,20,1000
f10,x,20,1000
f11,x,20,1000
```

At the moment `type` isn't used. I anticipate the types are:
* `categorical` (all are now) -- where we generate a list of values of the right length and cardinality
* `random` - where we generate the value in the same way at each transaction (no cardinality)
* `numeric` - some int or float in a range, maybe with a distribution function

### Splitting test data

We can `split` and if wanted `gzip` the output data like this (generating data for 1 week for 11 features):
```
python generate_data.py -F feature_file.csv -c 1000000 -n -t 168 | split --bytes=50M --filter='gzip > data/$FILE.gz' - data
```

Generating and compressing one week of data for 11 features as currently defined takes about 5 minutes. 610M compressed.


