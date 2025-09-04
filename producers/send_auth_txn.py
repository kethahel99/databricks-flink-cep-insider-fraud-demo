import json, os, random, time
from datetime import datetime, timezone
from faker import Faker
from azure.eventhub import EventHubProducerClient, EventData



EH_SEND=os.getenv('EH_SEND')
TOPIC=os.getenv('TOPIC','auth_txn')

#producer = EventHubProducerClient.from_connection_string(conn_str=EH_SEND, eventhub_name=TOPIC)
fk = Faker()
cards=[fk.credit_card_number() for _ in range(100000)]
while True:
    card=random.choice(cards)
    small = { 'type':'TXN','cardId':card,'amount':round(random.uniform(1,4.5),2),'ts':int(datetime.now().timestamp()*1000)}
    print(json.dumps(small))
    #producer.send_batch([EventData(json.dumps(small).encode())])
    time.sleep(random.uniform(0.1,5))
    big = { 'type':'TXN','cardId':card,'amount':round(random.uniform(600,2000),2),'ts':int(datetime.now().timestamp()*1000)}
    #producer.send_batch([EventData(json.dumps(big).encode())])
    # log the transaction to console
    print(json.dumps(big))
    time.sleep(random.uniform(0.1,5))