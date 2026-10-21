/*
 * Compact O2 Analyzer — ESP32-2424S012 (ESP32-C3, GC9A01 240x240 round, CST816 touch)
 *                       + ADS1115 + R-22D type galvanic O2 sensor
 *
 * Libraries (Arduino Library Manager):
 *   - "GFX Library for Arduino" by moononournation (Arduino_GFX)
 *   - "Adafruit ADS1X15"
 * Board: "ESP32C3 Dev Module", USB CDC On Boot: Enabled, Flash 4MB.
 *
 * Controls (touch screen):
 *   LONG PRESS  : calibrate to air (20.9 %) — do it in fresh air, sensor settled
 *   TAP         : switch between main page and detail page (mV, cal, MOD)
 * Serial (115200): 'c' = calibrate to air, 'o' = calibrate to 100 % O2, 'r' = reset cal
 */

#include <Arduino_GFX_Library.h>
#include <Adafruit_ADS1X15.h>
#include <Wire.h>
#include <Preferences.h>

/* ---------- ESP32-2424S012 pins (verify against your board) ---------- */
#define PIN_TFT_DC    2
#define PIN_TFT_CS    10
#define PIN_TFT_SCK   6
#define PIN_TFT_MOSI  7
#define PIN_TFT_BL    3
#define PIN_TP_SDA    4     // CST816 touch (bit-banged, C3 has one I2C unit)
#define PIN_TP_SCL    5
#define PIN_TP_INT    0
#define PIN_TP_RST    1
// ADS1115 on the 4-pin JST-SH "UART" port: RX pad -> SDA, TX pad -> SCL
#define PIN_ADS_SDA   20
#define PIN_ADS_SCL   21

/* ---------- Measurement settings ---------- */
const float AIR_O2          = 20.9;   // % in dry air
const float BATT_DIVIDER    = 2.0;    // 100k / 100k divider on ADS A2 (set 0 to disable)
const float SENSOR_MIN_MV   = 7.0;    // in air; below = sensor worn out
const float SENSOR_MAX_MV   = 14.5;   // in air; above = suspicious
const float STABLE_BAND_PCT = 0.15;   // max spread over the window to call it "stable"
const uint32_t SAMPLE_MS    = 100;
const int   AVG_N           = 20;     // 2 s rolling window

/* ---------- Display ---------- */
Arduino_DataBus *bus = new Arduino_ESP32SPI(PIN_TFT_DC, PIN_TFT_CS, PIN_TFT_SCK, PIN_TFT_MOSI, GFX_NOT_DEFINED);
Arduino_GFX *panel   = new Arduino_GC9A01(bus, GFX_NOT_DEFINED, 0 /*rotation*/, true /*IPS*/);
Arduino_GFX *gfx     = new Arduino_Canvas(240, 240, panel);   // off-screen buffer -> no flicker

#define C_BG      0x0000
#define C_FG      0xFFFF
#define C_DIM     0x52AA
#define C_ACCENT  0x07FF
#define C_OK      0x07E0
#define C_WARN    0xFD20
#define C_BAD     0xF800

Adafruit_ADS1115 ads;
Preferences prefs;

float calMv     = 0;      // mV reading at AIR_O2
float calO2Mv   = 0;      // optional mV at 100 % (0 = not set)
float buf[AVG_N];
int   bufIdx = 0, bufCnt = 0;
float mvNow = 0, o2Now = 0;
float battV = 0;
bool  adsOk = false;
int   page  = 0;
uint32_t msgUntil = 0;
char  msg[24] = "";

/* ======================= Minimal bit-bang I2C for CST816 ======================= */
static inline void sdaLow()  { pinMode(PIN_TP_SDA, OUTPUT); digitalWrite(PIN_TP_SDA, LOW); }
static inline void sdaRel()  { pinMode(PIN_TP_SDA, INPUT_PULLUP); }
static inline void sclLow()  { pinMode(PIN_TP_SCL, OUTPUT); digitalWrite(PIN_TP_SCL, LOW); }
static inline void sclRel()  { pinMode(PIN_TP_SCL, INPUT_PULLUP); }
static inline void dly()     { delayMicroseconds(4); }

static void i2cStart() { sdaRel(); sclRel(); dly(); sdaLow(); dly(); sclLow(); }
static void i2cStop()  { sdaLow(); dly(); sclRel(); dly(); sdaRel(); dly(); }
static bool i2cWrite(uint8_t b) {
  for (int i = 7; i >= 0; i--) { (b >> i) & 1 ? sdaRel() : sdaLow(); dly(); sclRel(); dly(); sclLow(); }
  sdaRel(); dly(); sclRel(); dly(); bool ack = !digitalRead(PIN_TP_SDA); sclLow(); return ack;
}
static uint8_t i2cRead(bool ack) {
  uint8_t b = 0; sdaRel();
  for (int i = 0; i < 8; i++) { dly(); sclRel(); dly(); b = (b << 1) | digitalRead(PIN_TP_SDA); sclLow(); }
  ack ? sdaLow() : sdaRel(); dly(); sclRel(); dly(); sclLow(); sdaRel(); return b;
}
static bool touchRead(uint8_t reg, uint8_t *out, int n) {
  i2cStart();
  if (!i2cWrite(0x15 << 1)) { i2cStop(); return false; }
  i2cWrite(reg);
  i2cStart();
  if (!i2cWrite((0x15 << 1) | 1)) { i2cStop(); return false; }
  for (int i = 0; i < n; i++) out[i] = i2cRead(i < n - 1);
  i2cStop();
  return true;
}

/* ============================ Seven-segment digits ============================ */
// segments a..g ; bit0=a ... bit6=g
const uint8_t SEG[10] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};

void drawSeg7(int x, int y, int w, int h, int t, int d, uint16_t col) {
  int h2 = h / 2;
  uint8_t s = (d < 0) ? 0x40 : SEG[d];   // d<0 -> dash
  auto H = [&](int xx, int yy) { gfx->fillRoundRect(xx + t / 2, yy - t / 2, w - t, t, t / 2, col); };
  auto V = [&](int xx, int yy, int len) { gfx->fillRoundRect(xx - t / 2, yy + t / 2, t, len - t, t / 2, col); };
  if (s & 0x01) H(x, y);
  if (s & 0x02) V(x + w, y, h2);
  if (s & 0x04) V(x + w, y + h2, h2);
  if (s & 0x08) H(x, y + h);
  if (s & 0x10) V(x, y + h2, h2);
  if (s & 0x20) V(x, y, h2);
  if (s & 0x40) H(x, y + h2);
}

// Draws value like "32.4" centred at cx; returns nothing. Shows "--.-" when invalid.
void drawBigNumber(float v, int cx, int y, uint16_t col, bool valid) {
  const int w = 34, h = 70, t = 9, gap = 12;
  int digits[3] = {-1, -1, -1};
  bool hundred = false;
  if (valid) {
    int tenths = (int)lroundf(v * 10);
    tenths = constrain(tenths, 0, 1000);
    if (tenths >= 1000) hundred = true;
    digits[0] = (tenths / 100) % 10; digits[1] = (tenths / 10) % 10; digits[2] = tenths % 10;
  }
  if (hundred) {                       // "100" without decimal
    int total = 3 * w + 2 * gap, x = cx - total / 2;
    drawSeg7(x, y, w, h, t, 1, col); drawSeg7(x + w + gap, y, w, h, t, 0, col); drawSeg7(x + 2 * (w + gap), y, w, h, t, 0, col);
    return;
  }
  int dotW = 14;
  int total = 3 * w + 2 * gap + dotW;
  int x = cx - total / 2;
  if (!valid || digits[0] != 0) drawSeg7(x, y, w, h, t, digits[0], col);     // blank leading zero
  x += w + gap;
  drawSeg7(x, y, w, h, t, digits[1], col);
  x += w + gap / 2;
  gfx->fillCircle(x + dotW / 2, y + h - 1, t / 2 + 1, col);
  x += dotW + gap / 2;
  drawSeg7(x, y, w, h, t, digits[2], col);
}

/* ================================ Helpers ================================ */
void centerText(const char *s, int y, uint8_t size, uint16_t col) {
  gfx->setTextSize(size);
  gfx->setTextColor(col);
  int w = strlen(s) * 6 * size;
  gfx->setCursor(120 - w / 2, y);
  gfx->print(s);
}

int battPercent(float v) {
  const float tbl[][2] = {{4.20, 100}, {4.10, 90}, {4.00, 80}, {3.90, 66}, {3.80, 52},
                          {3.75, 42}, {3.70, 32}, {3.65, 20}, {3.55, 10}, {3.40, 3}, {3.30, 0}};
  if (v >= tbl[0][0]) return 100;
  for (int i = 1; i < 11; i++)
    if (v >= tbl[i][0])
      return (int)(tbl[i][1] + (v - tbl[i][0]) * (tbl[i - 1][1] - tbl[i][1]) / (tbl[i - 1][0] - tbl[i][0]));
  return 0;
}

float mvToO2(float mv) {
  if (calMv <= 0) return NAN;
  if (calO2Mv > calMv + 1.0) {                       // two-point line through both cals
    float slope = (100.0 - AIR_O2) / (calO2Mv - calMv);
    return AIR_O2 + (mv - calMv) * slope;
  }
  return mv * AIR_O2 / calMv;                        // galvanic cells are linear through zero
}

void flash(const char *s) { strncpy(msg, s, sizeof(msg) - 1); msgUntil = millis() + 2500; }

void saveCal() {
  prefs.putFloat("air", calMv);
  prefs.putFloat("o2", calO2Mv);
}

float avgMv() {
  float s = 0; for (int i = 0; i < bufCnt; i++) s += buf[i];
  return bufCnt ? s / bufCnt : 0;
}

bool isStable() {
  if (bufCnt < AVG_N || calMv <= 0) return false;
  float lo = 1e9, hi = -1e9;
  for (int i = 0; i < bufCnt; i++) { lo = min(lo, buf[i]); hi = max(hi, buf[i]); }
  return (hi - lo) * AIR_O2 / calMv < STABLE_BAND_PCT;
}

void calibrateAir() {
  float mv = avgMv();
  if (mv < SENSOR_MIN_MV * 0.5) { flash("CAL FAILED"); return; }
  calMv = mv; saveCal();
  flash(mv < SENSOR_MIN_MV ? "CAL: WEAK SENSOR" : "CAL 20.9% OK");
}

void calibrateO2() {
  float mv = avgMv();
  if (calMv <= 0 || mv < calMv * 3) { flash("O2 CAL FAILED"); return; }
  calO2Mv = mv; saveCal(); flash("CAL 100% OK");
}

/* ================================ Drawing ================================ */
void drawScreen() {
  gfx->fillScreen(C_BG);
  bool valid = adsOk && calMv > 0 && !isnan(o2Now);
  bool stable = isStable();
  bool sensorWeak = calMv > 0 && calMv < SENSOR_MIN_MV;

  // outer gauge ring: 0..100 %
  float frac = valid ? constrain(o2Now / 100.0, 0, 1) : 0;
  gfx->fillArc(120, 120, 119, 111, 135, 405, 0x2104);
  if (frac > 0) gfx->fillArc(120, 120, 119, 111, 135, 135 + 270 * frac, stable ? C_ACCENT : C_WARN);

  // battery (top)
  if (BATT_DIVIDER > 0 && battV > 2.5) {
    int p = battPercent(battV);
    uint16_t c = p > 25 ? C_OK : (p > 10 ? C_WARN : C_BAD);
    gfx->drawRoundRect(100, 26, 34, 14, 3, C_DIM);
    gfx->fillRect(134, 30, 3, 6, C_DIM);
    gfx->fillRect(102, 28, max(1, 30 * p / 100), 10, c);
    char b[8]; snprintf(b, sizeof b, "%d%%", p);
    gfx->setTextSize(1); gfx->setTextColor(C_DIM); gfx->setCursor(140, 30); gfx->print(b);
  }

  if (page == 0) {
    centerText("O2", 50, 2, C_DIM);
    drawBigNumber(o2Now, 112, 76, valid ? (sensorWeak ? C_WARN : C_FG) : C_DIM, valid);
    gfx->setTextSize(3); gfx->setTextColor(C_DIM); gfx->setCursor(180, 120); gfx->print("%");

    if (valid) {
      char l[24];
      float fo2 = o2Now / 100.0;
      if (fo2 > 0.05) {
        int mod14 = (int)((1.4 / fo2 - 1) * 33.0);
        int mod16 = (int)((1.6 / fo2 - 1) * 33.0);
        snprintf(l, sizeof l, "MOD %d / %d ft", max(0, mod14), max(0, mod16));
        centerText(l, 160, 2, C_FG);
        centerText("@1.4      @1.6", 180, 1, C_DIM);
      }
    }
  } else {
    char l[28];
    centerText("DETAIL", 44, 2, C_DIM);
    snprintf(l, sizeof l, "%.2f mV", mvNow);              centerText(l, 76, 3, C_FG);
    snprintf(l, sizeof l, "air cal %.2f mV", calMv);      centerText(l, 116, 1, C_DIM);
    if (calO2Mv > 0) { snprintf(l, sizeof l, "O2 cal %.2f mV", calO2Mv); centerText(l, 130, 1, C_DIM); }
    snprintf(l, sizeof l, "%.1f %%", o2Now);              centerText(valid ? l : "--", 146, 2, C_FG);
    if (BATT_DIVIDER > 0) { snprintf(l, sizeof l, "batt %.2f V", battV); centerText(l, 172, 1, C_DIM); }
  }

  // status line
  const char *st; uint16_t sc;
  if (!adsOk)                  { st = "NO ADC";       sc = C_BAD; }
  else if (calMv <= 0)         { st = "HOLD: CAL AIR"; sc = C_WARN; }
  else if (mvNow < 0.3)        { st = "NO SENSOR";    sc = C_BAD; }
  else if (sensorWeak)         { st = "SENSOR WEAK";  sc = C_WARN; }
  else if (stable)             { st = "STABLE";       sc = C_OK; }
  else                         { st = "SETTLING";     sc = C_WARN; }
  if (millis() < msgUntil)     { st = msg;            sc = C_ACCENT; }
  centerText(st, 200, 1, sc);

  gfx->flush();
}

/* ============================== Setup / loop ============================== */
void setup() {
  Serial.begin(115200);
  pinMode(PIN_TFT_BL, OUTPUT); digitalWrite(PIN_TFT_BL, HIGH);

  gfx->begin(40000000);
  gfx->fillScreen(C_BG); gfx->flush();

  pinMode(PIN_TP_RST, OUTPUT); digitalWrite(PIN_TP_RST, LOW); delay(10); digitalWrite(PIN_TP_RST, HIGH); delay(50);
  pinMode(PIN_TP_INT, INPUT_PULLUP);
  sdaRel(); sclRel();

  Wire.begin(PIN_ADS_SDA, PIN_ADS_SCL, 400000);
  adsOk = ads.begin(0x48, &Wire);
  ads.setDataRate(RATE_ADS1115_32SPS);

  prefs.begin("o2cal", false);
  calMv   = prefs.getFloat("air", 0);
  calO2Mv = prefs.getFloat("o2", 0);
}

void handleTouch() {
  static bool down = false;
  static uint32_t downAt = 0;
  static bool longDone = false;
  uint8_t d[1];
  // CST816 sleeps between touches; INT goes low while touched/updating
  if (digitalRead(PIN_TP_INT) == HIGH && !down) return;
  if (!touchRead(0x02, d, 1)) { if (down) { down = false; } return; }
  bool finger = d[0] > 0;
  if (finger && !down) { down = true; downAt = millis(); longDone = false; }
  else if (finger && down && !longDone && millis() - downAt > 1500) { longDone = true; calibrateAir(); }
  else if (!finger && down) {
    down = false;
    if (!longDone && millis() - downAt < 600) page ^= 1;
  }
}

void loop() {
  static uint32_t tSample = 0, tDraw = 0;

  handleTouch();

  if (millis() - tSample >= SAMPLE_MS) {
    tSample = millis();
    if (adsOk) {
      ads.setGain(GAIN_SIXTEEN);                       // ±256 mV, 7.8 µV/LSB
      float mv = ads.computeVolts(ads.readADC_Differential_0_1()) * 1000.0;
      buf[bufIdx] = mv; bufIdx = (bufIdx + 1) % AVG_N; if (bufCnt < AVG_N) bufCnt++;
      mvNow = avgMv();
      o2Now = mvToO2(mvNow);

      if (BATT_DIVIDER > 0) {
        static int bdiv = 0;
        if (++bdiv >= 20) {                            // every 2 s
          bdiv = 0;
          ads.setGain(GAIN_ONE);
          float vb = ads.computeVolts(ads.readADC_SingleEnded(2)) * BATT_DIVIDER;
          battV = battV < 1 ? vb : battV * 0.8 + vb * 0.2;
        }
      }
    }
  }

  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'c') calibrateAir();
    if (c == 'o') calibrateO2();
    if (c == 'r') { calMv = 0; calO2Mv = 0; saveCal(); flash("CAL RESET"); }
  }

  if (millis() - tDraw >= 250) {
    tDraw = millis();
    drawScreen();
    Serial.printf("mV=%.3f O2=%.2f%% batt=%.2fV stable=%d\n", mvNow, o2Now, battV, isStable());
  }
}
