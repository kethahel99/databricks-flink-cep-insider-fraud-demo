import dlt
from pyspark.sql.functions import col, from_json
from pyspark.sql.types import *

kafka_conf = {
 'kafka.bootstrap.servers': spark.conf.get('eh.broker'),
 'subscribe': 'auth_txn,insider_events',
 'kafka.security.protocol': 'SASL_SSL',
 'kafka.sasl.mechanism': 'PLAIN',
 'kafka.sasl.jaas.config':
 'org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="' + spark.conf.get('eh.listen') + '";'
 }
rawSchema = StructType([
 StructField('type', StringType()),
 StructField('cardId', StringType()),
 StructField('amount', DoubleType()),
 StructField('actor', StringType()),
 StructField('ts', LongType())
])

@dlt.table(comment="bronze events from Event Hubs")
@dlt.expect("has_ts", "ts IS NOT NULL")
@dlt.expect_or_drop("valid_type", "type IN ('TXN','PRIV_ESC','BULK_EXPORT','EXT_SHARE')")

def bronze():
 df = (spark.readStream.format('kafka').options(**kafka_conf).load()
 .selectExpr('CAST(value AS STRING) as v')
 .select(from_json(col('v'), rawSchema).alias('j')).select('j.*'))
 return df

@dlt.table(comment="silver normalized")

def silver():
 return dlt.read_stream('bronze').withColumn('event_time', (col('ts')/
 1000).cast('timestamp'))

@dlt.table(comment="fraud features")

def features_fraud():
 s = dlt.read_stream('silver').filter("type='TXN'")
 return s.select('cardId','amount','event_time')

@dlt.table(comment="insider features")

def features_insider():
 s = dlt.read_stream('silver').filter("type in ('PRIV_ESC','BULK_EXPORT','EXT_SHARE')")
 return s.select('actor','type','event_time')