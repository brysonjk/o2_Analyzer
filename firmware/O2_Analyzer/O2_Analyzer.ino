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
 *   TAP         : next page: main -> detail (mV, cal, linearity) -> calibrate -> main
 *   LONG PRESS  : on the calibrate page, sample air (1-point), then optionally 100 % O2 (2-point).
 *                 Each sample waits for a stable reading and captures it automatically.
 * Serial (115200): 'c' = 1-point air cal (clears any O2 point), 'o' = add the 100 % O2 point, 'r' = reset cal
 * Power: the side button drives the IP5306 — short press turns on, hold 10 s turns off.
 */

#include <Arduino_GFX_Library.h>
#include <Adafruit_ADS1X15.h>
#include <Wire.h>
#include <Preferences.h>
#include "boot_logo.h"

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
const float O2_CAL_PCT      = 100.0;  // O2 % of the gas used for the 2-point cal (e.g. 99.5 for medical O2)
const float LIN_WARN_PCT    = 2.0;    // 2-point linearity: orange beyond +-2 % of ideal...
const float LIN_BAD_PCT     = 5.0;    // ...red beyond +-5 %
const uint32_t CAL_STABLE_MS = 5000;  // a calibration sample captures once the reading has stayed stable this long
const uint32_t CAL_TIMEOUT_MS = 60000; // ...and gives up if it never settles
const uint32_t SAMPLE_MS    = 100;
const int   AVG_N           = 20;     // 2 s rolling window

/* ---------- Display ---------- */
Arduino_DataBus *bus = new Arduino_ESP32SPI(PIN_TFT_DC, PIN_TFT_CS, PIN_TFT_SCK, PIN_TFT_MOSI, GFX_NOT_DEFINED);
// Quarter turns (0-3). In the T body the USB-C faces you and the sensor points
// away; pick the value that makes the text upright in that orientation.
#define DISPLAY_ROTATION 0
Arduino_GFX *panel   = new Arduino_GC9A01(bus, GFX_NOT_DEFINED, DISPLAY_ROTATION, true /*IPS*/);
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
float calO2Mv   = 0;      // optional mV at O2_CAL_PCT (0 = not set; set only by a 2-point cal)
float buf[AVG_N];
int   bufIdx = 0, bufCnt = 0;
float mvNow = 0, o2Now = 0;
float battV = 0;
bool  adsOk = false;
int   page  = 0;          // 0 main, 1 detail, 2 calibrate
enum CalStep { CAL_MENU, CAL_AIR, CAL_AIR_OK, CAL_O2, CAL_O2_OK };
CalStep calStep = CAL_MENU;
uint32_t calStart = 0, calStableSince = 0;
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
void centerTextAt(const char *s, int cx, int y, uint8_t size, uint16_t col) {
  gfx->setTextSize(size);
  gfx->setTextColor(col);
  int w = strlen(s) * 6 * size;
  gfx->setCursor(cx - w / 2, y);
  gfx->print(s);
}
void centerText(const char *s, int y, uint8_t size, uint16_t col) { centerTextAt(s, 120, y, size, col); }

int battPercent(float v) {
  const float tbl[][2] = {{4.20, 100}, {4.10, 90}, {4.00, 80}, {3.90, 66}, {3.80, 52},
                          {3.75, 42}, {3.70, 32}, {3.65, 20}, {3.55, 10}, {3.40, 3}, {3.30, 0}};
  if (v >= tbl[0][0]) return 100;
  for (int i = 1; i < 11; i++)
    if (v >= tbl[i][0])
      return (int)(tbl[i][1] + (v - tbl[i][0]) * (tbl[i - 1][1] - tbl[i][1]) / (tbl[i - 1][0] - tbl[i][0]));
  return 0;
}

bool twoPoint() { return calMv > 0 && calO2Mv > calMv + 1.0; }

float mvToO2(float mv) {
  if (calMv <= 0) return NAN;
  if (twoPoint()) {                                  // two-point line through both cals
    float slope = (O2_CAL_PCT - AIR_O2) / (calO2Mv - calMv);
    return AIR_O2 + (mv - calMv) * slope;
  }
  return mv * AIR_O2 / calMv;                        // galvanic cells are linear through zero
}

// 2-point linearity: the O2/air mV ratio as a % of the ideal ratio (O2_CAL_PCT / AIR_O2).
// 100 % = perfectly proportional; below 100 % = the cell falls off at high O2 (current limiting).
float linearityPct() { return (calO2Mv / calMv) / (O2_CAL_PCT / AIR_O2) * 100.0; }

// R^2 of a straight-line fit through zero, air and O2: (0 %, 0 mV), (AIR_O2, calMv), (O2_CAL_PCT, calO2Mv).
// A galvanic cell gives 0 mV with no O2, so zero is a real third point; with only two points R^2 is always 1.
float calR2() {
  const float x[3] = {0, AIR_O2, O2_CAL_PCT}, y[3] = {0, calMv, calO2Mv};
  float mx = (x[0] + x[1] + x[2]) / 3, my = (y[0] + y[1] + y[2]) / 3, sxy = 0, sxx = 0, syy = 0;
  for (int i = 0; i < 3; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) * (x[i] - mx); syy += (y[i] - my) * (y[i] - my); }
  return syy > 0 ? sxy * sxy / (sxx * syy) : 0;
}

uint16_t linColor() {
  float dev = fabsf(linearityPct() - 100.0);
  return dev <= LIN_WARN_PCT ? C_OK : dev <= LIN_BAD_PCT ? C_WARN : C_BAD;
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

float spreadMv() {
  float lo = 1e9, hi = -1e9;
  for (int i = 0; i < bufCnt; i++) { lo = min(lo, buf[i]); hi = max(hi, buf[i]); }
  return hi - lo;
}

bool isStable() {
  if (bufCnt < AVG_N || calMv <= 0) return false;
  return spreadMv() * AIR_O2 / calMv < STABLE_BAND_PCT;
}

// Stability without a calibration: the same band, relative to the reading itself.
bool isStableRaw() {
  float mv = avgMv();
  return bufCnt >= AVG_N && mv > 0.3 && spreadMv() < mv * STABLE_BAND_PCT / AIR_O2;
}

// 1-point cal in air. Clears any O2 point, so an old O2 point is never paired with a new air point.
bool calibrateAir() {
  float mv = avgMv();
  if (mv < SENSOR_MIN_MV * 0.5) { flash("AIR CAL FAILED"); return false; }
  calMv = mv; calO2Mv = 0; saveCal();
  flash(mv < SENSOR_MIN_MV ? "CAL: WEAK SENSOR" : "CAL 20.9% OK");
  return true;
}

// Second point in O2_CAL_PCT oxygen, after an air cal. Rejects ratios far from ideal (wrong gas or bad air cal).
bool calibrateO2() {
  float mv = avgMv(), ideal = O2_CAL_PCT / AIR_O2;
  if (calMv <= 0)                                     { flash("CAL AIR FIRST"); return false; }
  if (mv < calMv * ideal * 0.8 || mv > calMv * ideal * 1.2) { flash("O2 CAL FAILED: GAS?"); return false; }
  calO2Mv = mv; saveCal(); flash("2-POINT CAL OK");
  return true;
}

void calStartSample(CalStep s) { calStep = s; calStart = millis(); calStableSince = 0; }

// Runs the calibrate page's sampling steps. A cell creeps toward its final value, so the 2 s window can
// look steady while it's still ~1 % short; requiring CAL_STABLE_MS of continuous stability lets that tail die out.
void calTick() {
  if (calStep != CAL_AIR && calStep != CAL_O2) return;
  uint32_t now = millis(), t = now - calStart;
  bool air = calStep == CAL_AIR;
  if (!isStableRaw()) calStableSince = 0;
  else if (!calStableSince) calStableSince = now;
  if (calStableSince && now - calStableSince >= CAL_STABLE_MS) {
    if (air) calStep = calibrateAir() ? CAL_AIR_OK : CAL_MENU;
    else     calStep = calibrateO2()  ? CAL_O2_OK  : CAL_AIR_OK;
  } else if (t > CAL_TIMEOUT_MS) {
    flash("NOT STABLE: TRY AGAIN");
    calStep = air ? CAL_MENU : CAL_AIR_OK;
  }
}

/* ================================ Drawing ================================ */
void drawCalPage() {
  char l[28];
  centerText("CALIBRATE", 44, 2, C_DIM);
  snprintf(l, sizeof l, "%.2f mV", mvNow);
  centerText(l, 70, 3, C_FG);
  bool sampling = calStep == CAL_AIR || calStep == CAL_O2;
  if (sampling) {
    bool st = isStableRaw();
    centerText(calStep == CAL_AIR ? "SAMPLING AIR" : "SAMPLING O2", 108, 2, C_FG);
    if (st && calStableSince) {
      snprintf(l, sizeof l, "STABLE: CAPTURE IN %lus", (CAL_STABLE_MS - min(CAL_STABLE_MS, millis() - calStableSince) + 999) / 1000);
      centerText(l, 132, 1, C_OK);
    } else {
      centerText("WAITING FOR STABLE", 132, 1, C_WARN);
    }
    if (calStep == CAL_O2) {
      snprintf(l, sizeof l, "%.2fx AIR (IDEAL %.2f)", mvNow / calMv, O2_CAL_PCT / AIR_O2);
      centerText(l, 148, 1, C_DIM);
    }
    centerText("TAP: CANCEL", 176, 1, C_DIM);
  } else if (calStep == CAL_AIR_OK) {
    centerText("AIR SAVED", 104, 2, C_OK);
    centerText("1-POINT CAL DONE", 126, 1, C_DIM);
    centerText("FOR 2-POINT: FLOW O2,", 144, 1, C_ACCENT);
    centerText("THEN HOLD TO SAMPLE", 156, 1, C_ACCENT);
    centerText("TAP: FINISH", 176, 1, C_DIM);
  } else if (calStep == CAL_O2_OK) {
    float lin = linearityPct(), dev = fabsf(lin - 100);
    centerText("2-POINT SAVED", 100, 2, C_OK);
    snprintf(l, sizeof l, "LIN %.1f%%", lin);           centerText(l, 124, 2, linColor());
    snprintf(l, sizeof l, "R2 %.4f", calR2());          centerText(l, 146, 1, linColor());
    centerText(dev <= LIN_WARN_PCT ? "SENSOR LINEAR" : dev <= LIN_BAD_PCT ? "MARGINAL: RECHECK" : "NON-LINEAR: REPLACE",
               158, 1, linColor());
    centerText("TAP: FINISH", 176, 1, C_DIM);
  } else {                                           // CAL_MENU
    if (twoPoint()) {
      centerText("NOW: 2-POINT CAL", 108, 1, C_DIM);
      snprintf(l, sizeof l, "LIN %.1f%%  R2 %.4f", linearityPct(), calR2());
      centerText(l, 120, 1, linColor());
    } else {
      centerText(calMv > 0 ? "NOW: 1-POINT CAL (AIR)" : "NOT CALIBRATED", 108, 1, calMv > 0 ? C_DIM : C_WARN);
    }
    centerText("HOLD: START AIR CAL", 144, 1, C_ACCENT);
    centerText("SENSOR IN FRESH AIR", 156, 1, C_DIM);
    centerText("TAP: BACK TO MAIN", 176, 1, C_DIM);
  }
}

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
    drawBigNumber(o2Now, 106, 76, valid ? (sensorWeak ? C_WARN : C_FG) : C_DIM, valid);
    gfx->setTextSize(3); gfx->setTextColor(C_DIM); gfx->setCursor(188, 125); gfx->print("%");   // clear of the last digit, bottoms aligned

    if (valid) {
      char l[24];
      float fo2 = o2Now / 100.0;
      if (fo2 > 0.05) {
        int mod14 = (int)((1.4 / fo2 - 1) * 33.0);
        int mod16 = (int)((1.6 / fo2 - 1) * 33.0);
        // two columns, depth over its PO2, with the label between: narrow enough to stay clear of the ring
        snprintf(l, sizeof l, "%d", max(0, mod14)); centerTextAt(l, 86, 156, 2, C_FG);
        snprintf(l, sizeof l, "%d", max(0, mod16)); centerTextAt(l, 154, 156, 2, C_FG);
        centerTextAt("MOD", 120, 160, 1, C_DIM);
        centerTextAt("@1.4", 86, 176, 1, C_DIM);
        centerTextAt("FT", 120, 176, 1, C_DIM);
        centerTextAt("@1.6", 154, 176, 1, C_DIM);
      }
    }
  } else if (page == 1) {
    char l[28];
    centerText("DETAIL", 44, 2, C_DIM);
    snprintf(l, sizeof l, "%.2f mV", mvNow);              centerText(l, 76, 3, C_FG);
    snprintf(l, sizeof l, "air cal %.2f mV", calMv);      centerText(l, 116, 1, C_DIM);
    if (calO2Mv > 0) { snprintf(l, sizeof l, "O2 cal %.2f mV", calO2Mv); centerText(l, 130, 1, C_DIM); }
    snprintf(l, sizeof l, "%.1f %%", o2Now);              centerText(valid ? l : "--", 146, 2, C_FG);
    if (BATT_DIVIDER > 0) { snprintf(l, sizeof l, "batt %.2f V", battV); centerText(l, 172, 1, C_DIM); }
    if (twoPoint()) { snprintf(l, sizeof l, "LIN %.1f%%  R2 %.4f", linearityPct(), calR2()); centerText(l, 186, 1, linColor()); }
    else if (calMv > 0) centerText("1-POINT CAL (AIR)", 186, 1, C_DIM);
  } else {
    drawCalPage();
  }

  // status line
  const char *st; uint16_t sc;
  if (!adsOk)                  { st = "NO ADC";       sc = C_BAD; }
  else if (calMv <= 0)         { st = "NOT CALIBRATED"; sc = C_WARN; }
  else if (mvNow < 0.3)        { st = "NO SENSOR";    sc = C_BAD; }
  else if (sensorWeak)         { st = "SENSOR WEAK";  sc = C_WARN; }
  else if (stable)             { st = "STABLE";       sc = C_OK; }
  else                         { st = "SETTLING";     sc = C_WARN; }
  if (page == 2)               { st = "";             sc = C_BG; }   // the calibrate page has its own prompts
  if (millis() < msgUntil)     { st = msg;            sc = C_ACCENT; }
  centerText(st, 200, 1, sc);

  // page dots
  for (int i = 0; i < 3; i++) {
    if (i == page) gfx->fillCircle(112 + i * 8, 218, 2, C_FG);
    else           gfx->drawCircle(112 + i * 8, 218, 2, C_DIM);
  }

  gfx->flush();
}

/* ============================== Boot animation ============================== */
// The logo fades in and holds, then cross-fades into the animation: bubbles rise,
// two oxygen atoms bond and burst into the gauge ring, then the initials are traced
// in light. About 8 s in all; a tap skips it.
#define BOOT_INITIALS "FSS"          // 1-5 letters or digits
#define BOOT_TITLE    "O2 ANALYZER"
#define BOOT_LINE     "DIVE SAFE"    // small line under the title ("" for none)
#define BOOT_MS       5000
#define LOGO_MS       3000           // logo on screen (fade-in + hold) before the cross-fade starts
#define LOGO_IN_MS    400
#define LOGO_XFADE_MS 800            // overlaps the first LOGO_XFADE_MS of the animation

// Stroke font on a 5 x 9 grid: each point is two digits "xy" (x 0-4 left to right, y 0-8 top to bottom),
// consecutive points are joined, "/" lifts the pen.
static const char *const FONT_AZ[] = {
  "08 00 40 48/04 44", "00 30 41 43 34 04 34 45 47 38 08 00", "41 30 10 01 07 18 38 47", "00 20 42 46 28 08 00",
  "40 00 08 48/04 24", "40 00 08/04 24", "41 30 10 01 07 18 38 47 44 24", "00 08/40 48/04 44", "00 40/20 28/08 48",
  "40 47 38 18 07", "00 08/40 04 48", "00 08 48", "08 00 24 40 48", "08 00 48 40", "10 30 41 47 38 18 07 01 10",
  "08 00 30 41 43 34 04", "10 30 41 47 38 18 07 01 10/26 48", "08 00 30 41 43 34 04 34 48",
  "41 30 10 01 03 14 34 45 47 38 18 07", "00 40/20 28", "00 07 18 38 47 40", "00 28 40", "00 08 24 48 40",
  "00 48/40 08", "00 24/40 24 28", "00 40 08 48"
};
static const char *const FONT_09[] = {
  "10 30 41 47 38 18 07 01 10", "10 20 28", "01 10 30 41 43 08 48", "01 10 30 41 43 34 14 34 45 47 38 18 07",
  "00 04 44/40 48", "40 00 04 34 45 47 38 08", "41 30 10 01 07 18 38 47 45 34 04", "00 40 28",
  "10 30 41 43 34 14 03 01 10 14 34 45 47 38 18 07 05 14", "44 14 03 01 10 30 41 47 38 18 07"
};

static inline uint16_t rgb565(int r, int g, int b) { return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3); }
static uint16_t mix565(uint16_t a, uint16_t b, float f) {
  if (f <= 0) return a;
  if (f >= 1) return b;
  int ar = (a >> 11) & 31, ag = (a >> 5) & 63, ab = a & 31, br = (b >> 11) & 31, bg = (b >> 5) & 63, bb = b & 31;
  return ((int)(ar + (br - ar) * f) << 11) | ((int)(ag + (bg - ag) * f) << 5) | (int)(ab + (bb - ab) * f);
}
static inline float clamp01(float x) { return x < 0 ? 0 : x > 1 ? 1 : x; }
static inline float ramp(float t, float t0, float t1) { return clamp01((t - t0) / (t1 - t0)); }
static inline float easeOut(float x) { x = 1 - x; return 1 - x * x * x; }
static uint32_t hash32(uint32_t x) {
  x ^= x >> 16; x *= 0x7feb352d; x ^= x >> 15; x *= 0x846ca68b; x ^= x >> 16; return x;
}
static const char *glyph(char c) {
  if (c >= 'a' && c <= 'z') c -= 32;
  if (c >= 'A' && c <= 'Z') return FONT_AZ[c - 'A'];
  if (c >= '0' && c <= '9') return FONT_09[c - '0'];
  return "";
}

// Draw the first `prog` (0..1) of a glyph with a round pen of radius r inside box x, y, w, h.
// Returns the length drawn; the pen tip goes to *tx, *ty. Pass draw=false to only measure.
static float traceGlyph(const char *g, float x, float y, float w, float h, float prog, int r, uint16_t col,
                        float *tx, float *ty, bool draw = true) {
  float left = prog, px = 0, py = 0, done = 0;
  const float step = max(1.0f, r * 0.5f);
  bool pen = false;
  for (int i = 0; g[i];) {
    if (g[i] == '/') { pen = false; i++; continue; }
    if (g[i] == ' ') { i++; continue; }
    float qx = x + (g[i] - '0') * w / 4, qy = y + (g[i + 1] - '0') * h / 8;
    i += 2;
    if (pen) {
      if (left <= 0) break;
      float L = hypotf(qx - px, qy - py), run = min(L, left);
      if (draw) {
        for (float s = 0; s < run; s += step)
          gfx->fillCircle(lroundf(px + (qx - px) * s / L), lroundf(py + (qy - py) * s / L), r, col);
        *tx = px + (qx - px) * run / L; *ty = py + (qy - py) * run / L;
        gfx->fillCircle(lroundf(*tx), lroundf(*ty), r, col);
      }
      left -= L; done += run;
    }
    px = qx; py = qy; pen = true;
  }
  return done;
}
static void traceGlyphFrac(const char *g, float x, float y, float w, float h, float frac, int r, uint16_t col,
                           float *tx, float *ty) {
  float total = traceGlyph(g, x, y, w, h, 1e9, r, col, tx, ty, false);
  traceGlyph(g, x, y, w, h, frac * total, r, col, tx, ty);
}
static void sparkle(int x, int y, int s, uint16_t col) {
  gfx->fillRect(x - s, y, 2 * s + 1, 1, col);
  gfx->fillRect(x, y - s, 1, 2 * s + 1, col);
  if (s > 2) gfx->fillRect(x - 1, y - 1, 3, 3, col);
}
static void typeText(const char *s, int y, uint8_t size, uint16_t col, int n) {
  gfx->setTextSize(size); gfx->setTextColor(col);
  gfx->setCursor(120 - (int)strlen(s) * 6 * size / 2, y);
  for (int i = 0; s[i] && i < n; i++) gfx->print(s[i]);
}

void drawBootFrame(uint32_t t) {
  const uint16_t WHITE = 0xFFFF, GLOW = rgb565(0, 70, 96), DEEP = rgb565(0, 4, 18), SHALLOW = rgb565(0, 46, 78);
  const float fadeIn = ramp(t, 0, 500);

  // 1. Water: vertical gradient, lighter at the surface
  for (int y = 0; y < 240; y += 6) gfx->fillRect(0, y, 240, 6, mix565(0, mix565(SHALLOW, DEEP, y / 240.0f), fadeIn));

  // 2. Rising bubbles
  for (int i = 0; i < 18; i++) {
    uint32_t h = hash32(i * 7919 + 17);
    int r = 2 + h % 5, speed = 30 + (h >> 8) % 50;
    float y = 250 - fmodf(t * speed / 1000.0f + (h >> 16) % 260, 270);
    float x = 20 + (h >> 4) % 200 + 5 * sinf(t * 0.004f + i);
    uint16_t c = mix565(DEEP, rgb565(80, 170, 200), fadeIn * (0.35f + 0.65f * (y / 240)));
    gfx->drawCircle(lroundf(x), lroundf(y), r, c);
    gfx->fillRect(lroundf(x - r / 2.0f), lroundf(y - r / 2.0f), 1, 1, WHITE);
  }

  // 3. Two oxygen atoms drift in and bond: O + O -> O2
  if (t < 1250) {
    float a = easeOut(ramp(t, 100, 950)), pulse = ramp(t, 950, 1250);
    for (int k = -1; k <= 1; k += 2) {
      int x = lroundf(120 + k * (13 + 125 * (1 - a))), y = lroundf(120 + k * 40 * (1 - a) * (1 - a));
      int r = 16 + pulse * 6;
      gfx->fillCircle(x, y, r, mix565(rgb565(0, 60, 80), WHITE, pulse));
      gfx->drawCircle(x, y, r, C_ACCENT);
      gfx->setTextSize(2); gfx->setTextColor(mix565(WHITE, C_ACCENT, pulse));
      gfx->setCursor(x - 5, y - 7); gfx->print("O");
    }
  }
  // 4. ...and burst into a shock ring
  if (t >= 1200 && t < 1800) {
    float f = ramp(t, 1200, 1800);
    int rr = lroundf(20 + 96 * easeOut(f));
    uint16_t c = mix565(mix565(WHITE, C_ACCENT, f), DEEP, f * f);
    for (int d = 0; d < 3; d++) gfx->drawCircle(120, 120, rr - d, c);
  }

  // 5. Gauge ring sweeps round from the top, ticks light up behind it
  if (t >= 1500) {
    float p = easeOut(ramp(t, 1500, 2500));
    gfx->fillArc(120, 120, 119, 113, 0, 360, rgb565(0, 30, 44));
    gfx->fillArc(120, 120, 119, 113, 270, 270 + 360 * p, C_ACCENT);
    for (int k = 0; k < 60 && k * 6 <= 360 * p; k++) {
      float ang = (270 + k * 6) * DEG_TO_RAD, ca = cosf(ang), sa = sinf(ang);
      int r0 = k % 5 ? 107 : 103;
      gfx->drawLine(lroundf(120 + r0 * ca), lroundf(120 + r0 * sa), lroundf(120 + 109 * ca), lroundf(120 + 109 * sa),
                    k % 5 ? C_DIM : C_ACCENT);
    }
    if (p < 1) {
      float ang = (270 + 360 * p) * DEG_TO_RAD;
      gfx->fillCircle(lroundf(120 + 116 * cosf(ang)), lroundf(120 + 116 * sinf(ang)), 5, WHITE);
    }
  }

  // 6. The initials are traced in light, one after the other
  const char *ini = BOOT_INITIALS;
  int n = strlen(ini), cw = 40, gap = 14;
  if (n * cw + (n - 1) * gap > 172) { gap = 10; cw = (172 - (n - 1) * gap) / n; }
  int chh = min(66, (int)(cw * 1.65f)), pen = max(3, cw * 5 / 40);
  int x0 = 120 - (n * cw + (n - 1) * gap) / 2, y0 = 118 - chh;
  const uint32_t LT0 = 1700, LSTEP = 320, LDUR = 800;
  for (int pass = 0; pass < 2; pass++) {
    for (int i = 0; i < n; i++) {
      float prog = easeOut(ramp(t, LT0 + i * LSTEP, LT0 + i * LSTEP + LDUR));
      if (prog <= 0) continue;
      uint32_t done = LT0 + i * LSTEP + LDUR;
      int x = x0 + i * (cw + gap);
      float tx = -1, ty = -1;
      if (pass == 0) {
        traceGlyphFrac(glyph(ini[i]), x + pen, y0 + pen, cw - 2 * pen, chh - 2 * pen, prog, pen + 4, GLOW, &tx, &ty);
      } else {
        uint16_t col = mix565(WHITE, C_ACCENT, ramp(t, done, done + 600));
        traceGlyphFrac(glyph(ini[i]), x + pen, y0 + pen, cw - 2 * pen, chh - 2 * pen, prog, pen, col, &tx, &ty);
        if (prog < 1 && tx >= 0) {
          gfx->fillCircle(lroundf(tx), lroundf(ty), pen + 2, WHITE);
          sparkle(lroundf(tx), lroundf(ty), pen + 6, WHITE);
        }
      }
    }
  }

  // 7. Twinkles around the letters once they're finished
  const uint32_t tDone = LT0 + (n - 1) * LSTEP + LDUR;
  for (int i = 0; i < 7; i++) {
    uint32_t h = hash32(i * 104729 + 3);
    float st = (float)tDone - 200 + h % 900, life = ramp(t, st, st + 500);
    if (life <= 0 || life >= 1) continue;
    int s = lroundf(1 + 5 * sinf(life * PI));
    sparkle(x0 - 6 + (h >> 8) % (n * cw + (n - 1) * gap + 12), y0 - 8 + (h >> 20) % (chh + 16), s, WHITE);
  }

  // 8. Title types itself out, then the dedication line fades in
  const uint32_t TT = tDone + 100;
  int len = strlen(BOOT_TITLE);
  int typed = ramp(t, TT, TT + len * 45) * len;
  if (typed > 0) typeText(BOOT_TITLE, 136, 2, C_FG, typed);
  if (typed > 0 && typed < len && ((t / 80) & 1)) gfx->fillRect(120 - len * 6 + typed * 12, 136, 10, 14, C_ACCENT);
  float lineF = ramp(t, TT + len * 45, TT + len * 45 + 500);
  if (strlen(BOOT_LINE) && lineF > 0) typeText(BOOT_LINE, 162, 1, mix565(DEEP, C_FG, lineF * 0.7f), 99);

  // 9. Iris closes to black
  float iris = ramp(t, BOOT_MS - 550, BOOT_MS);
  if (iris > 0) gfx->fillArc(120, 120, 121, max(1, (int)lroundf(121 * (1 - iris * iris))), 0, 360, C_BG);
}

static bool fingerDown() {
  uint8_t d[1];
  return digitalRead(PIN_TP_INT) == LOW && touchRead(0x02, d, 1) && d[0] > 0;
}

// Blend the logo over what's in the canvas: f = 1 shows only the logo, f = 0 leaves the canvas.
static void blendLogo(float f) {
  uint16_t *fb = ((Arduino_Canvas *)gfx)->getFramebuffer();
  int w = lroundf(clamp01(f) * 256);
  if (w == 0) return;
  for (int i = 0; i < BOOT_LOGO_W * BOOT_LOGO_H; i++) {
    uint16_t a = BOOT_LOGO[i], b = fb[i];
    int r = (((a >> 11) & 31) * w + ((b >> 11) & 31) * (256 - w)) >> 8;
    int g = (((a >> 5) & 63) * w + ((b >> 5) & 63) * (256 - w)) >> 8;
    int bl = ((a & 31) * w + (b & 31) * (256 - w)) >> 8;
    fb[i] = (r << 11) | (g << 5) | bl;
  }
}

void bootAnimation() {
  uint32_t t0 = millis();
  for (uint32_t t = 0; t < LOGO_MS + BOOT_MS; t = millis() - t0) {
    if (t > 400 && fingerDown()) break;          // tap to skip
    if (t < LOGO_MS) {
      gfx->fillScreen(C_BG);
      blendLogo(ramp(t, 0, LOGO_IN_MS));
    } else {
      drawBootFrame(t - LOGO_MS);
      blendLogo(1 - ramp(t, LOGO_MS, LOGO_MS + LOGO_XFADE_MS));
    }
    gfx->flush();
  }
  for (uint32_t w = millis(); fingerDown() && millis() - w < 3000;) delay(20);   // don't let the skip tap change page
  gfx->fillScreen(C_BG); gfx->flush();
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

  bootAnimation();

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
  else if (finger && down && !longDone && millis() - downAt > 1500) {
    longDone = true;
    if (page == 2) {
      if (calStep == CAL_MENU || calStep == CAL_O2_OK) calStartSample(CAL_AIR);
      else if (calStep == CAL_AIR_OK)                  calStartSample(CAL_O2);
    } else if (page == 0) {
      flash("CAL: TAP TO PAGE 3");
    }
  }
  else if (!finger && down) {
    down = false;
    if (!longDone && millis() - downAt < 600) {
      if (page == 2 && calStep == CAL_AIR)      calStep = CAL_MENU;     // cancel, nothing changed
      else if (page == 2 && calStep == CAL_O2)  calStep = CAL_AIR_OK;   // cancel, keep the air cal
      else { page = (page + 1) % 3; calStep = CAL_MENU; }
    }
  }
}

void loop() {
  static uint32_t tSample = 0, tDraw = 0;

  handleTouch();
  calTick();

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
