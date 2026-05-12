#include "esp_camera.h"
#include <WiFi.h>

#define CAMERA_MODEL_AI_THINKER
#include "camera_pins.h"

const char *ssid = "ITF";
const char *password = "789789789";

void startCameraServer();
void setupLedFlash(int pin);

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

  // Nhẹ hơn, ổn hơn cho OV3660 + ESP32 thường
  config.xclk_freq_hz = 10000000;
  config.frame_size = FRAMESIZE_240X240;
  config.pixel_format = PIXFORMAT_RGB565;

  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.jpeg_quality = 15;
  config.fb_count = 1;

  if (!psramFound()) {
    Serial.println("WARNING: PSRAM not found. Face detect may not work well.");
    config.fb_location = CAMERA_FB_IN_DRAM;
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
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  WiFi.setSleep(false);

  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 40) {
    delay(500);
    Serial.print(".");
    retry++;
  }

  Serial.println();

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi connect failed!");
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