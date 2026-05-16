#include "esp_camera.h"
#include <WiFi.h>

#define CAMERA_MODEL_AI_THINKER
#include "camera_pins.h"

const char *ssid = "Veitel";
const char *password = "12345667";

void startCameraServer();
void setupLedFlash(int pin);
void onWiFiEvent(WiFiEvent_t event, WiFiEventInfo_t info);
const char *wifiStatusToText(wl_status_t status);
bool connectWiFiRobust();

const int WIFI_CONNECT_RETRIES = 3;
const unsigned long WIFI_SINGLE_TRY_TIMEOUT_MS = 20000;

const char *wifiStatusToText(wl_status_t status) {
  switch (status) {
    case WL_IDLE_STATUS:
      return "WL_IDLE_STATUS";
    case WL_NO_SSID_AVAIL:
      return "WL_NO_SSID_AVAIL";
    case WL_SCAN_COMPLETED:
      return "WL_SCAN_COMPLETED";
    case WL_CONNECTED:
      return "WL_CONNECTED";
    case WL_CONNECT_FAILED:
      return "WL_CONNECT_FAILED";
    case WL_CONNECTION_LOST:
      return "WL_CONNECTION_LOST";
    case WL_DISCONNECTED:
      return "WL_DISCONNECTED";
    default:
      return "WL_UNKNOWN";
  }
}

void onWiFiEvent(WiFiEvent_t event, WiFiEventInfo_t info) {
  if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
    Serial.printf("[WiFi] DISCONNECTED, reason=%d\n", info.wifi_sta_disconnected.reason);
  } else if (event == ARDUINO_EVENT_WIFI_STA_CONNECTED) {
    Serial.println("[WiFi] STA connected to AP");
  } else if (event == ARDUINO_EVENT_WIFI_STA_GOT_IP) {
    Serial.print("[WiFi] GOT_IP: ");
    Serial.println(WiFi.localIP());
  }
}

bool connectWiFiRobust() {
  WiFi.onEvent(onWiFiEvent);
  WiFi.persistent(false);
  WiFi.setAutoReconnect(true);

  int found = WiFi.scanNetworks(false, true);
  Serial.printf("[WiFi] Scan found %d networks\n", found);
  bool seenTarget = false;
  for (int i = 0; i < found; i++) {
    String current = WiFi.SSID(i);
    if (current == String(ssid)) {
      seenTarget = true;
      Serial.printf("[WiFi] Target SSID found, RSSI=%d, CH=%d, auth=%d\n",
                    WiFi.RSSI(i), WiFi.channel(i), (int)WiFi.encryptionType(i));
    }
  }
  if (!seenTarget) {
    Serial.printf("[WiFi] Target SSID '%s' not found in scan\n", ssid);
  }

  for (int attempt = 1; attempt <= WIFI_CONNECT_RETRIES; attempt++) {
    Serial.printf("[WiFi] Connect attempt %d/%d\n", attempt, WIFI_CONNECT_RETRIES);

    WiFi.disconnect(true, true);
    delay(300);
    WiFi.mode(WIFI_MODE_NULL);
    delay(150);
    WiFi.mode(WIFI_STA);
    WiFi.setSleep(false);
    WiFi.begin(ssid, password);

    unsigned long started = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - started < WIFI_SINGLE_TRY_TIMEOUT_MS) {
      wl_status_t st = WiFi.status();
      Serial.printf("[WiFi] waiting... status=%s (%d)\n", wifiStatusToText(st), (int)st);
      delay(800);
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("[WiFi] Connected");
      return true;
    }

    Serial.printf("[WiFi] Attempt %d failed. Final status=%s (%d)\n",
                  attempt, wifiStatusToText(WiFi.status()), (int)WiFi.status());
    delay(1200);
  }

  return false;
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.setDebugOutput(true);

  Serial.println();
  Serial.println("=== ESP32-CAM START ===");

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;

  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;

  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;

  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;

  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;

  // Stable streaming profile for AI Thinker:
  // - JPEG avoids heavy RGB conversion load
  // - QVGA keeps bandwidth/memory in safe zone
  // - CAMERA_GRAB_LATEST helps drop stale frames instead of queue overflow
  config.xclk_freq_hz = 10000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_QVGA;  // 320x240
  config.grab_mode = CAMERA_GRAB_LATEST;
  config.jpeg_quality = 20;  // lower quality -> smaller frame -> more stable
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.fb_count = 2;

  if (!psramFound()) {
    Serial.println("WARNING: PSRAM not found. Switching to low-memory camera profile.");
    config.fb_location = CAMERA_FB_IN_DRAM;
    config.frame_size = FRAMESIZE_QQVGA;  // 160x120
    config.fb_count = 1;
    config.jpeg_quality = 24;
  } else {
    Serial.println("PSRAM found.");
  }

  Serial.println("Starting camera init...");
  esp_err_t err = esp_camera_init(&config);

  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x\n", err);
    Serial.println("Try: check ribbon, PWDN pin, camera model, power supply.");
    return;
  }

  Serial.println("Camera init success!");

  sensor_t *s = esp_camera_sensor_get();

  if (s->id.PID == OV3660_PID) {
    Serial.println("Detected camera: OV3660");
    s->set_vflip(s, 1);
    s->set_brightness(s, 1);
    s->set_saturation(s, -2);
  } else if (s->id.PID == OV2640_PID) {
    Serial.println("Detected camera: OV2640");
  } else {
    Serial.printf("Detected camera PID: 0x%x\n", s->id.PID);
  }

#if defined(LED_GPIO_NUM)
  setupLedFlash(LED_GPIO_NUM);
#endif

  Serial.println("Starting WiFi...");
  if (!connectWiFiRobust()) {
    Serial.println("WiFi connect failed!");
    Serial.println("Check hotspot/router: 2.4GHz, WPA2 (not WPA3-only), SSID/password.");
    return;
  }

  Serial.println("WiFi connected");

  startCameraServer();

  Serial.print("Camera Ready! Use 'http://");
  Serial.print(WiFi.localIP());
  Serial.println("' to connect");
}

void loop() {
  delay(10000);
}
