import dlt
from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.sql.window import Window

# Configuration
kafka_conf = {
    'kafka.bootstrap.servers': spark.conf.get('eh.broker'),
    'subscribe': 'alerts',  # CEP alerts from Flink
    'kafka.security.protocol': 'SASL_SSL',
    'kafka.sasl.mechanism': 'PLAIN',
    'kafka.sasl.jaas.config':
    'org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="' + spark.conf.get('eh.listen') + '";'
}

alert_schema = StructType([
    StructField('id', StringType()),
    StructField('rule', StringType()),
    StructField('ts', LongType())
])

# Bronze Layer: Raw Alert Ingestion
@dlt.table(
    comment="Raw alerts from Flink CEP engine",
    table_properties={
        "pipelines.autoOptimize.managed": "true",
        "pipelines.autoOptimize.zOrderCols": "ts"
    }
)
@dlt.expect("valid_alert", "id IS NOT NULL AND rule IS NOT NULL")
def bronze_alerts():
    """Ingest raw alerts from Flink CEP processing"""
    return (spark.readStream.format('kafka')
            .options(**kafka_conf)
            .load()
            .selectExpr('CAST(value AS STRING) as v')
            .select(from_json(col('v'), alert_schema).alias('alert'))
            .select('alert.*', '_metadata.*')
            .withColumn('ingestion_ts', current_timestamp())
            .withColumn('event_time', (col('ts') / 1000).cast('timestamp')))

# Silver Layer: Enriched and Cleaned Alerts
@dlt.table(
    comment="Enriched and validated alerts with business context",
    table_properties={
        "pipelines.autoOptimize.managed": "true",
        "pipelines.autoOptimize.zOrderCols": "event_time"
    }
)
def silver_alerts():
    """Clean and enrich alert data with business context"""
    alerts_df = dlt.read_stream('bronze_alerts')

    # Add alert metadata and severity
    enriched = (alerts_df
                .withColumn('alert_type',
                           when(col('rule').contains('SMALL_THEN_LARGE'), 'FRAUD_TRANSACTION')
                           .when(col('rule').contains('INSIDER_EXFIL'), 'INSIDER_THREAT')
                           .otherwise('UNKNOWN'))
                .withColumn('severity',
                           when(col('rule').contains('INSIDER_EXFIL'), 'CRITICAL')
                           .when(col('rule').contains('SMALL_THEN_LARGE'), 'HIGH')
                           .otherwise('MEDIUM'))
                .withColumn('alert_category',
                           when(col('rule').contains('FRAUD'), 'Financial Fraud')
                           .when(col('rule').contains('INSIDER'), 'Insider Threat')
                           .otherwise('Security Event'))
                .withColumn('business_impact',
                           when(col('severity') == 'CRITICAL', 'High - Immediate Response Required')
                           .when(col('severity') == 'HIGH', 'Medium - Investigation Needed')
                           .otherwise('Low - Monitor'))
                .withColumn('year', year('event_time'))
                .withColumn('month', month('event_time'))
                .withColumn('day', dayofmonth('event_time'))
                .withColumn('hour', hour('event_time')))

    return enriched

# Gold Layer: Alert Analytics and Reporting

@dlt.table(
    comment="Real-time alert dashboard metrics",
    table_properties={
        "pipelines.autoOptimize.managed": "true",
        "pipelines.autoOptimize.zOrderCols": "window_start"
    }
)
def gold_alert_dashboard():
    """Aggregated metrics for real-time dashboards"""
    alerts_df = dlt.read_stream('silver_alerts')

    # 5-minute rolling window aggregations
    windowed = (alerts_df
                .withWatermark('event_time', '10 minutes')
                .groupBy(window('event_time', '5 minutes'), 'alert_type', 'severity')
                .agg(
                    count('*').alias('alert_count'),
                    countDistinct('id').alias('unique_entities'),
                    first('window.start').alias('window_start'),
                    first('window.end').alias('window_end')
                )
                .withColumn('alerts_per_minute', col('alert_count') / 5.0)
                .withColumn('severity_score',
                           when(col('severity') == 'CRITICAL', 10)
                           .when(col('severity') == 'HIGH', 7)
                           .when(col('severity') == 'MEDIUM', 4)
                           .otherwise(1))
                .withColumn('risk_score', col('alert_count') * col('severity_score')))

    return windowed

@dlt.table(
    comment="Daily alert summary for reporting",
    table_properties={
        "pipelines.autoOptimize.managed": "true",
        "pipelines.autoOptimize.zOrderCols": "date"
    }
)
def gold_daily_alert_summary():
    """Daily aggregated alert statistics for reporting"""
    alerts_df = dlt.read_stream('silver_alerts')

    daily_agg = (alerts_df
                 .withWatermark('event_time', '1 day')
                 .groupBy(
                     date_format('event_time', 'yyyy-MM-dd').alias('date'),
                     'alert_type',
                     'alert_category',
                     'severity'
                 )
                 .agg(
                     count('*').alias('total_alerts'),
                     countDistinct('id').alias('unique_entities_affected'),
                     min('event_time').alias('first_alert_time'),
                     max('event_time').alias('last_alert_time'),
                     collect_set('rule').alias('rules_triggered')
                 )
                 .withColumn('alerts_per_hour', col('total_alerts') / 24.0)
                 .withColumn('severity_weight',
                            when(col('severity') == 'CRITICAL', 3)
                            .when(col('severity') == 'HIGH', 2)
                            .when(col('severity') == 'MEDIUM', 1)
                            .otherwise(0))
                 .withColumn('weighted_risk_score', col('total_alerts') * col('severity_weight')))

    return daily_agg

@dlt.table(
    comment="Alert pattern analysis for threat intelligence",
    table_properties={
        "pipelines.autoOptimize.managed": "true",
        "pipelines.autoOptimize.zOrderCols": "pattern_date"
    }
)
def gold_alert_patterns():
    """Analyze alert patterns and trends for threat intelligence"""
    alerts_df = dlt.read_stream('silver_alerts')

    # Pattern analysis with sliding windows
    patterns = (alerts_df
                .withWatermark('event_time', '30 minutes')
                .groupBy(
                    window('event_time', '1 hour', '30 minutes'),
                    'rule',
                    'alert_type'
                )
                .agg(
                    count('*').alias('pattern_count'),
                    countDistinct('id').alias('unique_victims'),
                    collect_list('id').alias('affected_entities'),
                    first('window.start').alias('window_start'),
                    first('window.end').alias('window_end')
                )
                .withColumn('pattern_date', date_format('window_start', 'yyyy-MM-dd'))
                .withColumn('pattern_hour', hour('window_start'))
                .withColumn('is_spike',
                           col('pattern_count') > 5)  # Flag potential attack campaigns
                .withColumn('pattern_intensity',
                           when(col('pattern_count') > 10, 'HIGH_SPIKE')
                           .when(col('pattern_count') > 5, 'MODERATE_SPIKE')
                           .otherwise('NORMAL')))

    return patterns

@dlt.table(
    comment="Combined fraud and insider threat analytics",
    table_properties={
        "pipelines.autoOptimize.managed": "true",
        "pipelines.autoOptimize.zOrderCols": "date"
    }
)
def gold_combined_threat_analytics():
    """Combine alerts with transaction and insider data for comprehensive analytics"""

    # Read alerts
    alerts_df = dlt.read_stream('silver_alerts')

    # Read transaction features (assuming from existing pipeline)
    try:
        txn_df = dlt.read_stream('features_fraud')
    except:
        # Fallback if table doesn't exist
        txn_df = spark.table('fraud.features_fraud').withColumn('event_time', col('event_time'))

    # Read insider features (assuming from existing pipeline)
    try:
        insider_df = dlt.read_stream('features_insider')
    except:
        # Fallback if table doesn't exist
        insider_df = spark.table('fraud.features_insider').withColumn('event_time', col('event_time'))

    # Combine and analyze
    combined = (alerts_df
                .join(txn_df,
                      (alerts_df.id == txn_df.cardId) &
                      (abs(unix_timestamp(alerts_df.event_time) - unix_timestamp(txn_df.event_time)) < 3600),
                      'left_outer')
                .join(insider_df,
                      (alerts_df.id == insider_df.actor) &
                      (abs(unix_timestamp(alerts_df.event_time) - unix_timestamp(insider_df.event_time)) < 3600),
                      'left_outer')
                .withColumn('date', date_format('event_time', 'yyyy-MM-dd'))
                .groupBy('date', 'alert_type', 'severity')
                .agg(
                    count('*').alias('alert_count'),
                    countDistinct('cardId').alias('cards_involved'),
                    countDistinct('actor').alias('actors_involved'),
                    sum('amount').alias('total_amount_affected'),
                    avg('amount').alias('avg_transaction_amount'),
                    collect_set('rule').alias('active_rules'),
                    collect_set('type').alias('event_types')
                )
                .withColumn('threat_level',
                           when((col('alert_count') > 10) & (col('severity') == 'CRITICAL'), 'SEVERE')
                           .when((col('alert_count') > 5) & (col('severity').isin(['HIGH', 'CRITICAL'])), 'HIGH')
                           .when(col('alert_count') > 2, 'MODERATE')
                           .otherwise('LOW'))
                .withColumn('financial_impact_score',
                           when(col('total_amount_affected').isNull(), 0)
                           .otherwise(col('total_amount_affected') / 1000)))

    return combined

@dlt.table(
    comment="Executive dashboard KPIs and metrics",
    table_properties={
        "pipelines.autoOptimize.managed": "true",
        "pipelines.autoOptimize.zOrderCols": "date"
    }
)
def gold_executive_dashboard():
    """Key performance indicators for executive dashboards"""

    alerts_df = dlt.read_stream('silver_alerts')

    # Executive KPIs
    kpis = (alerts_df
            .withWatermark('event_time', '1 day')
            .withColumn('date', date_format('event_time', 'yyyy-MM-dd'))
            .groupBy('date')
            .agg(
                # Overall metrics
                count('*').alias('total_alerts'),
                countDistinct('id').alias('unique_entities'),

                # Severity breakdown
                sum(when(col('severity') == 'CRITICAL', 1).otherwise(0)).alias('critical_alerts'),
                sum(when(col('severity') == 'HIGH', 1).otherwise(0)).alias('high_alerts'),
                sum(when(col('severity') == 'MEDIUM', 1).otherwise(0)).alias('medium_alerts'),

                # Type breakdown
                sum(when(col('alert_type') == 'FRAUD_TRANSACTION', 1).otherwise(0)).alias('fraud_alerts'),
                sum(when(col('alert_type') == 'INSIDER_THREAT', 1).otherwise(0)).alias('insider_alerts'),

                # Time-based metrics
                min('event_time').alias('first_alert'),
                max('event_time').alias('last_alert')
            )
            .withColumn('alert_duration_hours',
                       (unix_timestamp('last_alert') - unix_timestamp('first_alert')) / 3600)
            .withColumn('alerts_per_hour', col('total_alerts') / col('alert_duration_hours'))
            .withColumn('critical_percentage', (col('critical_alerts') / col('total_alerts')) * 100)
            .withColumn('fraud_percentage', (col('fraud_alerts') / col('total_alerts')) * 100)
            .withColumn('insider_percentage', (col('insider_alerts') / col('total_alerts')) * 100)
            .withColumn('risk_index',
                       (col('critical_alerts') * 3 + col('high_alerts') * 2 + col('medium_alerts') * 1) /
                       col('total_alerts'))
            .withColumn('threat_trend',
                       when(col('risk_index') > 2.0, '🔴 HIGH RISK')
                       .when(col('risk_index') > 1.0, '🟡 MEDIUM RISK')
                       .otherwise('🟢 LOW RISK')))

    return kpis