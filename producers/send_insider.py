import json, os, random, time
from faker import Faker
from confluent_kafka import Producer

EH_BROKER=os.getenv('EH_BROKER')
EH_SEND=os.getenv('EH_SEND')
TOPIC=os.getenv('TOPIC','insider_events')
conf = {
 'bootstrap.servers': EH_BROKER,
 'security.protocol': 'SASL_SSL',
 'sasl.mechanism': 'PLAIN',
 'sasl.username': '$ConnectionString',
 'sasl.password': EH_SEND,
}
p=Producer(conf); fk=Faker(); users=[fk.user_name() for _ in range(500)]

while True:
    u=random.choice(users)
    for t in ['PRIV_ESC','BULK_EXPORT','EXT_SHARE']:
        evt={'type':t,'actor':u,'ts':int(time.time()*1000)}
        p.produce(TOPIC, json.dumps(evt).encode()); p.flush(); time.sleep(0.2)
    time.sleep(1)