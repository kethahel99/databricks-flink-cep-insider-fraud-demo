import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._
import org.apache.spark.sql.execution.streaming.RealTimeTrigger

val ehBroker = spark.conf.get("eh.broker")
val ehListen = spark.conf.get("eh.listen")
val endpoint = spark.conf.get("model.endpoint") // e.g., "fraud"

val schema = StructType(Seq(
  StructField("type", StringType), StructField("cardId", StringType),
  StructField("amount", DoubleType), StructField("actor", StringType),
  StructField("ts", LongType)
))

val kafkaOptions = Map(
  "kafka.bootstrap.servers" -> ehBroker,
  "subscribe" -> "auth_txn",
  "kafka.security.protocol" -> "SASL_SSL",
  "kafka.sasl.mechanism" -> "PLAIN",
  "kafka.sasl.jaas.config" ->
    s"""org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="$ehListen";"""
)

val raw = spark.readStream.format("kafka").options(kafkaOptions).load()
val txn = raw.selectExpr("CAST(value AS STRING) v").select(from_json(col("v"), schema).as("j")).select("j.*")

import scala.util.Try
import scalaj.http._

val scoreUdf = udf((cardId: String, amount: Double, ts: Long) => {
  val body = s"""{"inputs":[{"cardId":"$cardId","amount":$amount,"ts":$ts}]}"""
  Try {
    val r = Http(s"/api/2.0/serving-endpoints/$endpoint/invocations")
      .postData(body).header("Content-Type","application/json").timeout(50,50).asString
    val js = ujson.read(r.body)
    js("predictions")(0).num.toDouble
  }.getOrElse(0.0)
})

val scored = txn.withColumn("score", scoreUdf(col("cardId"), col("amount"), col("ts")))
                .withColumn("decision", col("score") > lit(0.85))

scored.writeStream.format("delta")
  .option("checkpointLocation", "/mnt/delta/chk/rtm_fraud")
  .outputMode("update")
  .trigger(RealTimeTrigger.apply("5 minutes"))
  .toTable("fraud.realtime_scored")
