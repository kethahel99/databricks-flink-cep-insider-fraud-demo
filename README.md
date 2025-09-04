# Databricks-Flink CEP Insider Fraud Detection Demo

## Overview

This repository demonstrates a comprehensive real-time fraud detection system that combines **Complex Event Processing (CEP)** using Apache Flink with **Machine Learning** capabilities in Databricks. The solution showcases two critical fraud detection scenarios:

1. **Financial Transaction Fraud**: Detecting suspicious card transaction p4. **Configure Databricks**

1. **Upload notebooks** from `databricks/` directory
2. **Create cluster** with runtime 11.3 LTS or later
3. **Configure Event Hubs** connection in cluster settings
4. **Run DLT pipeline** for data ingestion:
   - `dlt_fraud_insider.py` - Original fraud/insider data pipeline
   - `dlt_alert_analytics.py` - Alert analytics and reporting pipeline
5. **Execute real-time scoring** notebook

### Alert Analytics Pipeline Setup

The alert analytics pipeline requires the Flink CEP to be running and producing alerts:

1. **Ensure Flink is deployed** and producing alerts to the `alerts` topic
2. **Upload `dlt_alert_analytics.py`** to Databricks
3. **Create DLT pipeline** with the alert analytics notebook
4. **Configure cluster** with Event Hubs connectivity
5. **Start the pipeline** to begin processing alerts

**Pipeline Dependencies**:
- Flink CEP alerts in Event Hubs `alerts` topic
- Optional: Existing fraud/insider feature tables for enrichment
- Databricks SQL warehouse for dashboard queries using CEP
2. **Insider Threat Detection**: Identifying malicious insider activities through behavioral analysis

The architecture leverages Azure cloud services to create a scalable, real-time streaming analytics platform that can process thousands of events per second and generate immediate alerts for fraudulent activities.

## Solution Architecture

```
                    🌐 REAL-TIME FRAUD DETECTION PLATFORM 🌐
                    ════════════════════════════════════════════

┌─────────────────────────┐      ┌─────────────────────────┐      ┌─────────────────────────┐
│    📊 DATA PRODUCERS    │      │     🚀 EVENT HUBS      │      │    ⚡ APACHE FLINK     │
│  ┌─────────────────────┐│  ╔═▶ │  ┌─────────────────────┐│  ╔═▶ │  ┌─────────────────────┐│
│  │ 💳 Transaction Gen  ││  ║   │  │   📈 auth_txn       ││  ║   │  │  🔍 CEP Engine      ││
│  │ • Card Testing      ││  ║   │  │   • 12 Partitions   ││  ║   │  │  • Pattern Matcher  ││
│  │ • Fraud Patterns    ││  ║   │  │   • 2 TU Capacity   ││  ║   │  │  • Time Windows     ││
│  └─────────────────────┘│  ║   │  └─────────────────────┘│  ║   │  └─────────────────────┘│
│  ┌─────────────────────┐│  ║   │  ┌─────────────────────┐│  ║   │  ┌─────────────────────┐│
│  │ 👤 Insider Events   ││  ║   │  │  🔐 insider_events  ││  ║   │  │  🚨 Alert Generator ││
│  │ • Priv Escalation   ││  ╚══▶│  │   • Employee Acts    ││  ║   │  │  • Fraud Rules      ││
│  │ • Data Exfiltration ││      │  │   • Security Events ││  ║   │  │  • Insider Rules    ││
│  └─────────────────────┘│      │  └─────────────────────┘│  ║   │  └─────────────────────┘│
└─────────────────────────┘      │  ┌─────────────────────┐│  ║   └─────────────────────────┘
                                 │  │    📢 alerts       ││  ║              │
                                 │  │   • Real-time      ││  ║              │
                                 │  │   • JSON Format    ││  ║              │
                                 │  └─────────────────────┘│  ║              ▼
                                 └─────────────────────────┘  ║   ┌─────────────────────────┐
                                              │                ╚══▶│    ☸️  KUBERNETES      │
                                              │                    │  ┌─────────────────────┐│
                                              │                    │  │  🎯 Job Manager     ││
                                              │                    │  │  • Coordination     ││
                                              ▼                    │  │  • Checkpointing    ││
                                 ┌─────────────────────────┐       │  └─────────────────────┘│
                                 │    🧠 DATABRICKS       │       │  ┌─────────────────────┐│
                                 │ ┌─────────────────────┐ │       │  │ ⚙️  Task Managers   ││
                                 │ │  📊 Streaming Jobs  │ │       │  │  • Parallel Proc    ││
                                 │ │  • Real-time Score  │ │       │  │  • Auto Scaling     ││
                                 │ │  • ML Inference     │ │       │  └─────────────────────┘│
                                 │ └─────────────────────┘ │       └─────────────────────────┘
                                 │ ┌─────────────────────┐ │
                                 │ │  🔬 ML Training     │ │
                                 │ │  • Feature Eng      │ │
                                 │ │  • Model Registry   │ │
                                 │ └─────────────────────┘ │
                                 │ ┌─────────────────────┐ │
                                 │ │  🏗️  DLT Pipelines  │ │
                                 │ │  • Bronze/Silver    │ │
                                 │ │  • Data Quality     │ │
                                 │ └─────────────────────┘ │
                                 └─────────────────────────┘
                                              │
                                              ▼
                                 ┌─────────────────────────┐
                                 │   💾 AZURE STORAGE     │
                                 │ ┌─────────────────────┐ │
                                 │ │  🏛️  Delta Lake      │ │
                                 │ │  • ACID Transactions│ │
                                 │ │  • Time Travel      │ │
                                 │ └─────────────────────┘ │
                                 │ ┌─────────────────────┐ │
                                 │ │  📚 Feature Store   │ │
                                 │ │  • ML Features      │ │
                                 │ │  • Versioning       │ │
                                 │ └─────────────────────┘ │
                                 └─────────────────────────┘
```

## Fraud Detection Scenarios

### 1. Transaction Fraud Pattern: Small-Then-Large

**Business Rule**: Flag transactions where a small amount (< $5) is immediately followed by a large amount (> $500) from the same card within 60 seconds.

**Why This Matters**: This pattern often indicates:
- Card testing attacks (verifying stolen card validity with small amounts)
- Fraudsters confirming card limits before making large purchases
- Automated bot attacks testing multiple cards

**CEP Implementation**:
```java
Pattern.<Event>begin("small")
  .where(e -> "TXN".equals(e.type) && e.amount < 5)
  .next("large") 
  .where(e -> "TXN".equals(e.type) && e.amount > 500)
  .within(Time.seconds(60))
```

### 2. Insider Threat Pattern: Privilege Escalation → Data Exfiltration

**Business Rule**: Detect when an employee escalates privileges, performs bulk data export, and shares data externally within 30 minutes.

**Why This Matters**: This sequence indicates:
- Malicious insider attempting data theft
- Compromised employee accounts being used for espionage
- Industrial espionage or corporate data theft

**CEP Implementation**:
```java
Pattern.<Event>begin("elev")
  .where(e -> "PRIV_ESC".equals(e.type))
  .next("export")
  .where(e -> "BULK_EXPORT".equals(e.type))
  .next("share")
  .where(e -> "EXT_SHARE".equals(e.type))
  .within(Time.minutes(30))
```

## Data Flow Architecture

```
    🔄 END-TO-END REAL-TIME FRAUD DETECTION PIPELINE 🔄
    ═══════════════════════════════════════════════════════

┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│     📤      │    │     🚀      │    │     ⚡      │    │     🔍      │    │     🚨      │
│    DATA     │    │   EVENT     │    │   STREAM    │    │  PATTERN    │    │   ALERT     │
│ GENERATION  │───▶│  INGESTION  │───▶│ PROCESSING  │───▶│ DETECTION   │───▶│ GENERATION  │
│             │    │             │    │             │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                 │                  │                │
       ▼                   ▼                 ▼                  ▼                ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 🐍 Python   │    │ 📡 Event    │    │ ⚙️  Flink    │    │ 🧩 CEP      │    │ 📬 Alert    │
│ Producers   │    │ Hubs        │    │ Cluster     │    │ Rules       │    │ Topic       │
│             │    │             │    │             │    │             │    │             │
│ • TXN Gen   │    │ • Kafka API │    │ • JobMgr    │    │ • Time Win  │    │ • JSON      │
│ • Insider   │    │ • Partions  │    │ • TaskMgr   │    │ • Conditions│    │ • Real-time │
│ • Realistic │    │ • SASL/SSL  │    │ • Parallel  │    │ • Sequences │    │ • Routing   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                                                       │
                           │                                                       │
                           ▼                                                       ▼
                  ┌─────────────────┐                                    ┌─────────────────┐
                  │   🧠 DATABRICKS │                                    │  👥 SECURITY    │
                  │    STREAMING    │                                    │     TEAMS       │
                  │                 │                                    │                 │
                  │ • Kafka Connect │                                    │ • SOC Alerts    │
                  │ • Delta Streaming│                                    │ • Investigations│
                  │ • Auto Scaling  │                                    │ • Response      │
                  └─────────────────┘                                    └─────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │  🤖 ML MODEL    │
                  │    SCORING      │
                  │                 │
                  │ • Real-time API │
                  │ • Fraud Score   │
                  │ • Threshold     │
                  └─────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │  💾 DELTA LAKE  │
                  │    STORAGE      │
                  │                 │
                  │ • Scored Data   │
                  │ • Feature Store │
                  │ • Audit Trail   │
                  └─────────────────┘
```

## Component Deep Dive

### 1. Apache Flink CEP Engine

**Location**: `flink/src/main/java/com/beckerj/fraudinsider/StreamingJob.java`

**Key Features**:
- **Dual-Mode Operation**: Supports both fraud detection and insider threat scenarios
- **Event-Time Processing**: Uses watermarks for handling late-arriving events
- **Kafka Integration**: Connects to Azure Event Hubs using Kafka protocol
- **Pattern Matching**: Implements complex event patterns with time windows
- **Scalable Architecture**: Runs on Kubernetes with horizontal scaling

**Configuration**:
```bash
# Environment Variables
MODE=fraud|insider          # Detection mode
EH_BROKER=                  # Event Hubs Kafka endpoint
TOPIC_FRAUD=auth_txn        # Financial transaction topic
TOPIC_INSIDER=insider_events # Insider activity topic
EH_LISTEN=                  # Event Hubs connection string
```

### 2. Azure Event Hubs

**Role**: High-throughput event streaming platform

**Topics**:
- `auth_txn`: Financial transaction events
- `insider_events`: Employee security events
- `alerts`: Generated fraud alerts

**Configuration** (in `infra/main.bicep`):
- **Capacity**: 2 throughput units (configurable)
- **Partitions**: 12 partitions for parallel processing
- **Retention**: 7 days default
- **Kafka Compatibility**: Enabled for Flink integration

### 3. Databricks Analytics Platform

**Components**:

#### Real-Time Scoring (`databricks/rtm_scoring.scala`)
- Streams transaction data from Event Hubs
- Applies pre-trained ML models for fraud scoring
- Writes scored results to Delta tables
- Uses Structured Streaming with 5-minute triggers

#### Delta Live Tables Pipeline (`databricks/dlt_fraud_insider.py`)
- **Bronze Layer**: Raw event ingestion with data quality checks
- **Silver Layer**: Cleaned and normalized data
- **Gold Layer**: Feature-engineered tables for ML training

**Data Quality Rules**:
```python
@dlt.expect("has_ts", "ts IS NOT NULL")
@dlt.expect_or_drop("valid_type", "type IN ('TXN','PRIV_ESC','BULK_EXPORT','EXT_SHARE')")
```

#### Alert Analytics Pipeline (`databricks/dlt_alert_analytics.py`)
- **Bronze Layer**: Raw alert ingestion from Flink CEP
- **Silver Layer**: Enriched alerts with business context and severity
- **Gold Layer**: Multiple analytics tables for dashboards and reporting

**Analytics Tables**:
- `gold_alert_dashboard`: Real-time dashboard metrics (5-minute windows)
- `gold_daily_alert_summary`: Daily aggregated statistics
- `gold_alert_patterns`: Pattern analysis for threat intelligence
- `gold_combined_threat_analytics`: Combined fraud/insider analytics
- `gold_executive_dashboard`: Executive KPIs and risk metrics

### 4. Kubernetes (AKS) Orchestration

**Flink Deployment** (`k8s/flink-deployment.yaml`):
- **Job Manager**: Coordinates job execution
- **Task Managers**: Execute parallel processing
- **Horizontal Scaling**: Auto-scales based on throughput
- **High Availability**: Multiple replicas for fault tolerance

### 5. Data Producers

#### Transaction Generator (`producers/send_auth_txn.py`)
```python
# Generates realistic fraud patterns
small = {'type':'TXN', 'cardId':card, 'amount':random.uniform(1,4.5)}
large = {'type':'TXN', 'cardId':card, 'amount':random.uniform(600,2000)}
```

### 5. Alert Analytics Pipeline

**Location**: `databricks/dlt_alert_analytics.py`

**Purpose**: Consumes Flink CEP alerts and creates comprehensive analytics for dashboards and reporting

**Key Features**:
- **Real-time Alert Processing**: Streams alerts from Event Hubs `alerts` topic
- **Multi-layer Analytics**: Bronze → Silver → Gold transformation pipeline
- **Business Enrichment**: Adds severity, categories, and business impact scoring
- **Time-based Aggregations**: Rolling windows and daily summaries
- **Pattern Analysis**: Detects spikes and threat campaigns
- **Executive Dashboards**: KPI metrics for management reporting

**Analytics Outputs**:

#### Real-time Dashboard (`gold_alert_dashboard`)
```sql
-- 5-minute rolling window metrics
SELECT window_start, alert_type, severity, alert_count, risk_score
FROM fraud.gold_alert_dashboard
WHERE window_start >= current_timestamp() - INTERVAL 1 HOUR
ORDER BY window_start DESC
```

#### Daily Summary (`gold_daily_alert_summary`)
```sql
-- Daily alert statistics
SELECT date, alert_type, total_alerts, severity, weighted_risk_score
FROM fraud.gold_daily_alert_summary
WHERE date >= current_date() - INTERVAL 7 DAYS
ORDER BY date DESC, weighted_risk_score DESC
```

#### Pattern Analysis (`gold_alert_patterns`)
```sql
-- Threat pattern detection
SELECT pattern_date, rule, pattern_count, pattern_intensity, is_spike
FROM fraud.gold_alert_patterns
WHERE is_spike = true
ORDER BY pattern_count DESC
```

#### Executive Dashboard (`gold_executive_dashboard`)
```sql
-- Executive KPIs
SELECT date, total_alerts, critical_percentage, risk_index, threat_trend
FROM fraud.gold_executive_dashboard
WHERE date >= current_date() - INTERVAL 30 DAYS
ORDER BY date DESC
```

**Usage in Dashboards**:
- **Grafana/Power BI**: Connect via Databricks SQL endpoint
- **Databricks SQL Analytics**: Direct SQL queries on gold tables
- **Real-time Dashboards**: Streaming queries on silver/gold layers
- **Alert Monitoring**: Real-time threshold monitoring on alert counts

## Infrastructure Components

### Azure Resources Deployed

| Service | Purpose | Configuration |
|---------|---------|---------------|
| **AKS** | Kubernetes cluster for Flink | 2 nodes, Standard_D4s_v5 |
| **ACR** | Container registry | Standard SKU |
| **Event Hubs** | Event streaming | 2 TU, 12 partitions |
| **Databricks** | Analytics platform | Premium workspace |
| **Storage Account** | Delta Lake storage | ADLS Gen2 enabled |

### Security & Access

- **Managed Identity**: AKS uses system-assigned identity
- **RBAC**: Proper role assignments for service integration
- **Network Security**: VNet integration for secure communication
- **Event Hubs Authentication**: SASL/SSL with connection strings

## Prerequisites

Before deploying this solution, ensure you have:

### Required Tools
- **Azure CLI** (`az`) - Version 2.0 or later
- **PowerShell Core** (`pwsh`) - For deployment scripts
- **Docker** - For building Flink application
- **Helm** - For Kubernetes package management
- **kubectl** - For Kubernetes cluster management

### Azure Requirements
- **Azure Subscription** with sufficient permissions
- **Resource Provider Registration**:
  ```bash
  az provider register --namespace Microsoft.ContainerService
  az provider register --namespace Microsoft.EventHub
  az provider register --namespace Microsoft.Databricks
  ```

### Development Tools (Optional)
- **Java 11+** - For Flink development
- **Maven** - For Java build management
- **Python 3.8+** - For data producers
- **Scala** - For Databricks development

## Quick Start Deployment

### 1. Environment Setup

```bash
# Clone the repository
git clone <repository-url>
cd databricks-flink-cep-insider-fraud-demo

# Copy and configure environment variables
cp .env.sample .env
# Edit .env with your Azure details
```

### 2. Deploy Infrastructure

```bash
# Load environment variables and deploy
cd infra
pwsh ./load-env.ps1
.\deploy.ps1
```

**What gets deployed**:
- Azure Kubernetes Service (AKS)
- Azure Container Registry (ACR)
- Azure Event Hubs namespace with topics
- Databricks workspace
- Storage account for Delta Lake
- Flink Kubernetes operator

### 3. Build and Deploy Flink Application

```bash
# Build the Flink job
cd flink
./build.sh

# Deploy to Kubernetes
kubectl apply -f ../k8s/flink-deployment.yaml
```

### 4. Start Data Producers

```bash
# Generate sample transaction data
cd producers
./run_producers.sh
```

### 5. Configure Databricks

1. **Upload notebooks** from `databricks/` directory
2. **Create cluster** with runtime 11.3 LTS or later
3. **Configure Event Hubs** connection in cluster settings
4. **Run DLT pipeline** for data ingestion
5. **Execute real-time scoring** notebook

## Monitoring and Observability

### Flink Dashboard
- Access via port-forward: `kubectl port-forward svc/flink-jobmanager 8081:8081`
- Monitor job status, checkpoints, and throughput

### Event Hubs Metrics
- Throughput units utilization
- Incoming/outgoing message rates
- Consumer lag monitoring

### Databricks Monitoring
- Streaming query progress
- Delta table operations
- ML model performance metrics

## Scaling Considerations

### Performance Tuning

**Flink Configuration**:
```yaml
taskmanager:
  numberOfTaskSlots: 4
  memory: "2GB"
parallelism: 8
checkpointing:
  interval: 5000ms
```

**Event Hubs Scaling**:
- Increase throughput units for higher ingestion rates
- Add partitions for parallel processing
- Monitor consumer lag

**Databricks Optimization**:
- Use Delta optimization for faster queries
- Enable adaptive query execution
- Configure cluster auto-scaling

## Troubleshooting

### Common Issues

1. **Flink Job Failures**
   ```bash
   kubectl logs flink-jobmanager-<pod-id>
   kubectl describe flinkapplication fraud-detection
   ```

2. **Event Hubs Connection Issues**
   - Verify connection strings in configuration
   - Check SASL authentication settings
   - Monitor throttling metrics

3. **Databricks Connectivity**
   - Ensure cluster has internet access
   - Verify Event Hubs integration libraries
   - Check workspace firewall settings

### Log Locations
- **Flink Logs**: Kubernetes pod logs
- **Event Hubs**: Azure Monitor
- **Databricks**: Cluster event logs and Spark UI

## Security Best Practices

### Data Protection
- **Encryption at Rest**: All storage encrypted with Azure keys
- **Encryption in Transit**: TLS 1.2 for all communications
- **Access Control**: RBAC and managed identities

### Network Security
- **Private Endpoints**: For Event Hubs and Storage
- **VNet Integration**: Secure service-to-service communication
- **Network Policies**: Kubernetes network segmentation

### Monitoring & Auditing
- **Azure Monitor**: Centralized logging and metrics
- **Security Center**: Compliance and vulnerability scanning
- **Audit Logs**: Track all administrative operations

## Development Workflow

### Adding New Fraud Patterns

1. **Define Pattern Logic** in Flink CEP:
   ```java
   Pattern.<Event>begin("pattern1")
     .where(condition1)
     .followedBy("pattern2")
     .where(condition2)
     .within(timeWindow)
   ```

2. **Update Event Schema** if needed
3. **Modify Data Producers** for testing
4. **Add Unit Tests** in `flink/src/test/`
5. **Deploy and Validate**

### ML Model Integration

1. **Train Model** in Databricks
2. **Register in MLflow**
3. **Create Serving Endpoint**
4. **Update Scoring Logic** in `rtm_scoring.scala`

## Dashboard Examples

### Real-time Alert Monitoring Dashboard

```sql
-- Current hour alert summary
SELECT
  DATE_FORMAT(window_start, 'HH:mm') as time_window,
  alert_type,
  severity,
  SUM(alert_count) as total_alerts,
  AVG(risk_score) as avg_risk_score
FROM fraud.gold_alert_dashboard
WHERE window_start >= DATE_TRUNC('HOUR', CURRENT_TIMESTAMP())
GROUP BY window_start, alert_type, severity
ORDER BY window_start DESC
```

### Executive Risk Dashboard

```sql
-- 7-day risk trend
SELECT
  date,
  total_alerts,
  ROUND(critical_percentage, 2) as critical_pct,
  ROUND(fraud_percentage, 2) as fraud_pct,
  ROUND(insider_percentage, 2) as insider_pct,
  ROUND(risk_index, 2) as risk_index,
  threat_trend
FROM fraud.gold_executive_dashboard
WHERE date >= CURRENT_DATE() - INTERVAL 7 DAYS
ORDER BY date DESC
```

### Threat Pattern Analysis

```sql
-- Top threat patterns this week
SELECT
  rule,
  COUNT(*) as occurrences,
  COUNT(DISTINCT pattern_date) as active_days,
  AVG(pattern_count) as avg_daily_alerts,
  MAX(pattern_count) as peak_alerts
FROM fraud.gold_alert_patterns
WHERE pattern_date >= CURRENT_DATE() - INTERVAL 7 DAYS
  AND pattern_intensity IN ('HIGH_SPIKE', 'MODERATE_SPIKE')
GROUP BY rule
ORDER BY occurrences DESC
```

### Combined Threat Intelligence

```sql
-- Fraud vs Insider threat correlation
SELECT
  date,
  alert_type,
  SUM(alert_count) as alerts,
  SUM(cards_involved) as cards_affected,
  SUM(actors_involved) as actors_involved,
  ROUND(SUM(total_amount_affected), 2) as total_amount,
  threat_level
FROM fraud.gold_combined_threat_analytics
WHERE date >= CURRENT_DATE() - INTERVAL 30 DAYS
GROUP BY date, alert_type, threat_level
ORDER BY date DESC, alerts DESC
```

## Contributing

### Code Standards
- **Java**: Google Java Style Guide
- **Python**: PEP 8
- **Scala**: Scala Style Guide
- **Documentation**: Markdown with diagrams

### Testing
- **Unit Tests**: Required for all new features
- **Integration Tests**: End-to-end scenario validation
- **Performance Tests**: Load testing with realistic data

## Related Documentation

- [Detailed Deployment Guide](DEPLOYMENT_GUIDE.md)
- [Azure Event Hubs Documentation](https://docs.microsoft.com/en-us/azure/event-hubs/)
- [Apache Flink CEP Documentation](https://nightlies.apache.org/flink/flink-docs-stable/docs/libs/cep/)
- [Databricks Delta Live Tables](https://docs.databricks.com/workflows/delta-live-tables/)

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Azure service health status
3. Open an issue in this repository
4. Contact the development team

---

**Built with** ❤️ **using Azure, Flink, and Databricks**
