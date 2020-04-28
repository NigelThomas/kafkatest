# test data generation for kafka exactly once / restart-recovery / feature engineering testing
# TODO save the feature set as a file in JSON; allow to re-read the same feature set
# TODO save the users as a file in JSON; allow to re-read the same user set

import random
import string
import uuid
import json
import time
import argparse
import csv

parser = argparse.ArgumentParser()
parser.add_argument("-c","--user_count", type=int, default=1000, help="number of users to be created")
parser.add_argument("-t","--output_time", type=float, default=24.0, help="time: number of hours of calls (default 24)")
parser.add_argument("-r","--transaction_rate", type=int, default=10, help="average number of transactions per second (default 10)")

parser.add_argument("-F","--feature_file", type=str, default="none", required=True, help="name of input file describing features and their cardinality")
#parser.add_argument("-O","--output_file", type=str, default="none", required=True, help="name of output file containing data")

parser.add_argument( "-k", "--trickle", default=True, action='store_true', help="Trickle one second of data each second")
parser.add_argument( "-n", "--no_trickle", default=False, dest='trickle', action='store_false', help="No trickling - emit data immediately")


args = parser.parse_args()

max_trans_per_sec = args.transaction_rate * 2

# initially use CSV format:
# timestamp|user|device|visitId|f1|f2|...|fN

# TODO we are assuming length > number of dgits to manage cardinality (ie 3 for 1000)
def randomword(length, cardinality, idx):
   l = len(str(cardinality-1))
   baseval = str(idx).rjust(l, '0')
   return baseval+ ''.join(random.choice(string.ascii_letters) for i in range(length-l))


features = []
feature_descs = []
feature_count=0
feature_names = []

with open(args.feature_file, "r") as f:
    freader = csv.DictReader(f, delimiter=',')

    for row in freader:
        feature_desc = {'name':row['name'],'type':row['type'],'length':int(row['length']),'cardinality':int(row['cardinality']), 'fvalues':[]}

        feature_names.append(feature_desc['name'])
        
        # generate feature values
        fvalues = []
        for i in range(feature_desc['cardinality']):
            # start the value with the index (zero filled) then fill with random chars
            fvalues.append(randomword(feature_desc['length'],feature_desc['cardinality'], i))

        feature_desc['fvalues'] = fvalues

        feature_descs.append(feature_desc)
        features.append(feature_descs)

        feature_count += 1

    f.close()

# TODO save the generated features for later re-use
# print json.dumps(features)

# just number the users
# 
# Make sure userId is a long number
startrange=1000000000000

users = []

# Generate the initial list of users and devices

for i in range(startrange, startrange+int(args.user_count)):

    device_count=int(random.triangular(1,10,2))
    user_devices = []
    for dev in range(device_count):
        user_devices.append(i * 100 + dev)

    user = { 'id':i, 'devices': user_devices }

    users.append(user)


# TODO save user set for re-use
# print json.dumps(users)

# Now generate calls for random users every second

startsecs = time.time()


# Generate data for this many "seconds"

print "calltime|userid|deviceid|visitId|"+string.join(feature_names,'|')

output_seconds = int(3600 * args.output_time)

for calltime in range(output_seconds):

    # Generate up to this many transactions per second

    for counter in range(random.randint(1,max_trans_per_sec)):
        # choose a random subscriber
        user = users[random.randrange(len(users))]
        userId = user['id'];
        deviceCount = len(user['devices'])
        deviceIdx = 0 if deviceCount == 1 else random.randint(0,deviceCount-1)
        deviceId = user['devices'][deviceIdx]

        visitId = uuid.uuid1().hex
        concat_features = []

        for f in range(len(features)):
            fvalues = feature_descs[f]['fvalues']
            l = len(fvalues)
            # pick a random value for this feature
            concat_features.append(fvalues[random.randint(0,l-1)])

        print "%010d|%d|%d|%s|%s"% (calltime+startsecs, userId, deviceId, visitId , string.join(concat_features,'|'))
    
   
    # If we want to trickle the data:
    if args.trickle:
        time.sleep(1)

