#include <WiFi.h>
#include <PubSubClient.h>
#include <Preferences.h>

const char *WIFI_SSID = "Matrix Vision"; // WiFi სახელი
const char *WIFI_PASSWORD = "14022007";  // WiFi პაროლი
const char *MQTT_BROKER = "161.35.219.50";
const uint16_t MQTT_PORT = 1883;
const char *MQTT_USERNAME = "";          // არასავალდებულო
const char *MQTT_PASSWORD = "";          // არასავალდებულო
const char *DEVICE_ID = "ESP32_001";     // <-- Device identifier (visible in app)
const char *DEVICE_KEY = "GH-4K7N-WF48"; // <-- Secret key for registration (QR/manual entry)

Preferences preferences;
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
const unsigned long TELEMETRY_INTERVAL_MS = 60UL * 1000UL; // 1 წუთი
unsigned long lastTelemetryMs = 0;

String telemetryTopic() { return String("greenhouse/") + DEVICE_ID + "/telemetry"; }
String statusTopic() { return String("greenhouse/") + DEVICE_ID + "/status"; }

void connectWiFi()
{
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("📶 Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20)
  {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED)
  {
    Serial.println("\n✅ WiFi connected! IP: ");
    Serial.println(WiFi.localIP());
  }
  else
  {
    Serial.println("\n❌ WiFi connection FAILED!");
  }
}

void publishStatus(const char *status)
{
  mqttClient.publish(statusTopic().c_str(), status, true);
}

unsigned long lastMqttRetry = 0;
unsigned int mqttRetryCount = 0;

void connectMqtt()
{
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);

  if (WiFi.status() != WL_CONNECTED)
  {
    Serial.println("❌ WiFi not connected, cannot connect to MQTT");
    return;
  }

  if (mqttClient.connected())
  {
    return;
  }

  unsigned long now = millis();
  unsigned long backoff = min(300000UL, 1000UL * (1UL << mqttRetryCount));

  if (now - lastMqttRetry < backoff)
  {
    return;
  }

  lastMqttRetry = now;

  String clientId = String("greenhouse-") + DEVICE_KEY;
  Serial.printf("🔌 Connecting to MQTT %s:%u as %s (attempt %u)...\n", MQTT_BROKER, MQTT_PORT, clientId.c_str(), mqttRetryCount + 1);

  bool connected = mqttClient.connect(
      clientId.c_str(),
      MQTT_USERNAME[0] ? MQTT_USERNAME : nullptr,
      MQTT_PASSWORD[0] ? MQTT_PASSWORD : nullptr,
      statusTopic().c_str(), 1, true, "offline");

  if (connected)
  {
    Serial.println("✅ MQTT connected successfully!");
    mqttRetryCount = 0;
    publishStatus("online");
  }
  else
  {
    mqttRetryCount++;
    Serial.printf("MQTT connect failed (rc=%d). Next retry in ~%lu ms (attempt %u)\n", mqttClient.state(), backoff, mqttRetryCount + 1);
  }
}

float readAirTemperatureC() { return 25.0 + random(-20, 20) / 10.0; }
float readAirHumidityPct() { return 60.0 + random(-50, 50) / 10.0; }
float readSoilTemperatureC() { return 22.0 + random(-20, 20) / 10.0; }
float readSoilMoisturePct()
{
  float value = 45.0 + random(-100, 100) / 10.0;
  return constrain(value, 0.0, 100.0); // Clamp to valid range
}
float readLightLevel() { return 700 + random(-50, 50); }

void publishTelemetry()
{
  char payload[300];
  snprintf(payload, sizeof(payload),
           "{\"deviceId\":\"%s\",\"deviceKey\":\"%s\",\"airTemperature\":%.2f,\"airHumidity\":%.2f,"
           "\"soilTemperature\":%.2f,\"soilMoisture\":%.2f,\"lightLevel\":%.2f}",
           DEVICE_ID,
           DEVICE_KEY,
           readAirTemperatureC(),
           readAirHumidityPct(),
           readSoilTemperatureC(),
           readSoilMoisturePct(),
           readLightLevel());

  bool published = mqttClient.publish(telemetryTopic().c_str(), payload, false);
  if (published)
  {
    Serial.print("📤 Telemetry sent: ");
    Serial.println(payload);
  }
  else
  {
    Serial.println("❌ Failed to publish telemetry");
  }
}

void printDeviceInfo()
{
  Serial.println();
  Serial.println("╔════════════════════════════════════════════════════╗");
  Serial.println("║       🌱 GREENHOUSE IoT DEVICE 🌱                  ║");
  Serial.println("╠════════════════════════════════════════════════════╣");
  Serial.printf("║  Device ID:  %-37s ║\n", DEVICE_ID);
  Serial.printf("║  Device Key: %-37s ║\n", DEVICE_KEY);
  Serial.println("╠════════════════════════════════════════════════════╣");
  Serial.println("║  შეიყვანეთ Device Key აპლიკაციაში!                 ║");
  Serial.println("╚════════════════════════════════════════════════════╝");
  Serial.println();
}

void setup()
{
  Serial.begin(115200);
  delay(2000);

  printDeviceInfo();

  // Validate device key format
  String key = String(DEVICE_KEY);
  if (key == "GH-XXXX-XXXX" || key.length() != 12)
  {
    Serial.println("⚠️  WARNING: Device key not configured!");
    Serial.println("⚠️  Please set DEVICE_KEY in the code.");
    Serial.println("⚠️  Generate key in Greenhouse app first.");
    Serial.println();
  }

  connectWiFi();
  connectMqtt();

  publishStatus("online");
}

void loop()
{
  if (WiFi.status() != WL_CONNECTED)
  {
    connectWiFi();
  }

  if (!mqttClient.connected())
  {
    connectMqtt();
  }

  mqttClient.loop();

  unsigned long now = millis();
  if (now - lastTelemetryMs >= TELEMETRY_INTERVAL_MS)
  {
    lastTelemetryMs = now;
    publishTelemetry();
  }
}
