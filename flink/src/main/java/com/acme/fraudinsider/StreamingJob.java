package com.acme.fraudinsider;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.cep.CEP;
import org.apache.flink.cep.PatternSelectFunction;
import org.apache.flink.cep.pattern.Pattern;
import org.apache.flink.cep.pattern.conditions.SimpleCondition;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.time.Time;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

public class StreamingJob {
  public static void main(String[] args) throws Exception {
    final ParameterTool p = ParameterTool.fromArgs(args);

    // Prefer env vars (operator won't expand $(ENV) in args)
    final String mode = get(p, "mode", env("MODE", "fraud"));
    final String broker = get(p, "broker", env("EH_BROKER", ""));
    final String topic = get(p, "topic", mode.equals("fraud") ? env("TOPIC_FRAUD","auth_txn") : env("TOPIC_INSIDER","insider_events"));
    final String groupId = get(p, "group", env("GROUP_ID","flink-consumer"));
    final String alertsTopic = env("TOPIC_ALERTS","alerts");
    final String sasl = get(p, "sasl", env("EH_LISTEN", "")); // Event Hubs: use full connection string

    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
    env.enableCheckpointing(5000);

    KafkaSource<String> source = KafkaSource.<String>builder()
      .setBootstrapServers(broker)
      .setTopics(topic)
      .setGroupId(groupId)
      .setProperty("security.protocol", "SASL_SSL")
      .setProperty("sasl.mechanism", "PLAIN")
      .setProperty("sasl.jaas.config", String.format(
        "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"%s\" password=\"%s\";",
        "$ConnectionString", sasl))
      .setStartingOffsets(OffsetsInitializer.earliest())
      .setValueOnlyDeserializer(new SimpleStringSchema())
      .build();

    DataStream<String> lines = env.fromSource(source, WatermarkStrategy.noWatermarks(), "event-hubs");
    DataStream<Event> events = lines.map(Event::fromJson);

    DataStream<String> alerts;
    if (mode.equals("fraud")) {
      Pattern<Event, ?> pattern = Pattern.<Event>begin("small")
        .where(new SimpleCondition<Event>() {@Override
 public boolean filter(Event e){return "TXN".equals(e.type) && e.amount<5;} })
        .next("large")
        .where(new SimpleCondition<Event>() {@Override
 public boolean filter(Event e){return "TXN".equals(e.type) && e.amount>500;} })
        .within(Time.seconds(60));

      alerts = CEP.pattern(events.keyBy(e->e.cardId), pattern).select(
        (PatternSelectFunction<Event,String>) m -> {
          Event b = m.get("large").iterator().next();
          return String.format("{\"id\":\"%s\",\"rule\":\"SMALL_THEN_LARGE\",\"ts\":%d}", b.cardId, b.ts);
        });

    } else {
      Pattern<Event, ?> pattern = Pattern.<Event>begin("elev")
        .where(new SimpleCondition<Event>() {@Override
 public boolean filter(Event e){return "PRIV_ESC".equals(e.type);} })
        .next("export")
        .where(new SimpleCondition<Event>() {@Override
 public boolean filter(Event e){return "BULK_EXPORT".equals(e.type);} })
        .next("share")
        .where(new SimpleCondition<Event>() {@Override
 public boolean filter(Event e){return "EXT_SHARE".equals(e.type);} })
        .within(Time.minutes(30));

      alerts = CEP.pattern(events.keyBy(e->e.actor), pattern).select(
        (PatternSelectFunction<Event,String>) m -> {
          Event s = m.get("share").iterator().next();
          return String.format("{\"id\":\"%s\",\"rule\":\"INSIDER_EXFIL\",\"ts\":%d}", s.actor, s.ts);
        });
    }

    KafkaSink<String> sink = KafkaSink.<String>builder()
      .setBootstrapServers(broker)
      .setRecordSerializer(KafkaRecordSerializationSchema.builder()
        .setTopic(alertsTopic)
        .setValueSerializationSchema(new SimpleStringSchema())
        .build())
      .setProperty("security.protocol","SASL_SSL")
      .setProperty("sasl.mechanism","PLAIN")
      .setProperty("sasl.jaas.config", String.format(
        "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"%s\" password=\"%s\";",
        "$ConnectionString", sasl))
      .build();

    alerts.sinkTo(sink);
    env.execute("fraud-insider-cep");
  }

  static class Event {
    public String type; public String cardId; public double amount; public long ts; public String actor;
    static Event fromJson(String s){
      try {
        ObjectMapper om = new ObjectMapper();
        JsonNode n = om.readTree(s);
        Event e = new Event();
        e.type=n.path("type").asText("");
        e.cardId=n.path("cardId").asText("");
        e.amount=n.path("amount").asDouble(0.0);
        e.ts=n.path("ts").asLong(System.currentTimeMillis());
        e.actor=n.path("actor").asText("");
        return e;
      } catch(JsonProcessingException ex){ throw new RuntimeException(ex); }
    }
  }

  static String env(String k, String d){ String v=System.getenv(k); return v==null||v.isEmpty()?d:v; }
  static String get(ParameterTool p, String k, String d){ return p.get(k, d); }
}
