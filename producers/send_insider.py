import json, os, random, time
from faker import Faker
from azure.eventhub import EventHubProducerClient, EventData

EH_SEND=os.getenv('EH_SEND')
TOPIC=os.getenv('TOPIC','insider_events')

#producer = EventHubProducerClient.from_connection_string(conn_str=EH_SEND, eventhub_name=TOPIC); 
fk=Faker(); 
users=[fk.user_name() for _ in range(5000)]

while True:
    u=random.choice(users)
    for t in ['PRIV_ESC','BULK_EXPORT','EXT_SHARE']:
        evt={'type':t,'actor':u,'ts':int(time.time()*1000)}
        #producer.send_batch([EventData(json.dumps(evt).encode())]); time.sleep(0.2)
        print(json.dumps(evt))
    time.sleep(random.uniform(0.1,5))
