import json, os, random, time
from datetime import datetime, timezone
from faker import Faker
from confluent_kafka import Producer



EH_BROKER=os.getenv('EH_BROKER')
EH_NS=os.getenv('EH_NS')
EH_SEND=os.getenv('EH_SEND')
TOPIC=os.getenv('TOPIC','auth_txn')

conf = {
 'bootstrap.servers': EH_BROKER,
 'security.protocol': 'SASL_SSL',
 'sasl.mechanism': 'PLAIN',
 'sasl.username': '$ConnectionString',
 'sasl.password': EH_SEND,
 }

p = Producer(conf)
fk = Faker()
cards=[fk.credit_card_number() for _ in range(100000)]
while True:
    card=random.choice(cards)
    small = { 'type':'TXN','cardId':card,'amount':round(random.uniform(1,4.5),2),'ts':int(datetime.now().timestamp()*1000)}
    p.produce(TOPIC, json.dumps(small).encode())
    p.flush()
    time.sleep(0.1)
    big = { 'type':'TXN','cardId':card,'amount':round(random.uniform(600,2000),2),'ts':int(datetime.now().timestamp()*1000)}
    p.produce(TOPIC, json.dumps(big).encode())
    p.flush()
    time.sleep(1)