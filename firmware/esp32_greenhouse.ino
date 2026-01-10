#include <WiFi.h>
#include <PubSubClient.h>
#include <Preferences.h>

// ============================================================
//  WiFi და MQTT კონფიგურაცია
// ============================================================
const char *WIFI_SSID = "YOUR_WIFI_NAME";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char *MQTT_BROKER = "YOUR_SERVER_IP"; // სერვერის IP მისამართი
const uint16_t MQTT_PORT = 1883;
const char *MQTT_USERNAME = "";
const char *MQTT_PASSWORD = "";

// ============================================================
//  მოწყობილობის კოდი (Device Key)
// ============================================================
// ეს კოდი უნდა დააგენერიროთ აპლიკაციაში და ჩაწეროთ აქ!
// ფორმატი: GH-XXXX-XXXX (მაგ: GH-A3K7-B9M2)
//
// ნაბიჯები:
// 1. გახსენით Greenhouse აპლიკაცია
// 2. დააჭირეთ ლურჯ ღილაკს (✨) - "ახალი მოწყობილობის გენერაცია"
// 3. დააკოპირეთ შექმნილი კოდი (მაგ: GH-A3K7-B9M2)
// 4. ჩაწერეთ ქვემოთ DEVICE_KEY-ში
// 5. ატვირთეთ კოდი ESP32-ზე
// ============================================================
const char *DEVICE_KEY = "GH-XXXX-XXXX"; // <-- შეცვალეთ თქვენი კოდით!

Preferences preferences;
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
const unsigned long TELEMETRY_INTERVAL_MS = 60UL * 1000UL; // 1 წუთი
unsigned long lastTelemetryMs = 0;

String telemetryTopic() { return String("greenhouse/") + DEVICE_KEY + "/telemetry"; }
String statusTopic() { return String("greenhouse/") + DEVICE_KEY + "/status"; }

void connectWiFi()
{
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }

  Serial.print("\nWiFi connected. IP: ");
  Serial.println(WiFi.localIP());
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
  Serial.printf("[%lu] Connecting to MQTT as %s (attempt %u)...\n", now, clientId.c_str(), mqttRetryCount + 1);

  bool connected = mqttClient.connect(
      clientId.c_str(),
      MQTT_USERNAME[0] ? MQTT_USERNAME : nullptr,
      MQTT_PASSWORD[0] ? MQTT_PASSWORD : nullptr,
      statusTopic().c_str(), 1, true, "offline");

  if (connected)
  {
    Serial.println("MQTT connected successfully");
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
  char payload[256];
  snprintf(payload, sizeof(payload),
           "{\"deviceId\":\"%s\",\"airTemperature\":%.2f,\"airHumidity\":%.2f,"
           "\"soilTemperature\":%.2f,\"soilMoisture\":%.2f,\"lightLevel\":%.2f}",
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
  Serial.printf("║  Device Key: %-37s ║\n", DEVICE_KEY);
  Serial.println("╠════════════════════════════════════════════════════╣");
  Serial.println("║  ამ კოდით დაამატეთ მოწყობილობა აპლიკაციაში!       ║");
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
