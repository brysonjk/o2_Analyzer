# Compact O2 Analyzer — ESP32-2424S012 + ADS1115 + R-22D

A Ø46 × ~63 mm handheld puck, plus ~12 mm of the sensor's M16×1 nose and O-ring sticking out the bottom. The round display sits on top. The bottom cap unscrews to give access to both the sensor and the battery.

```
   ┌──────── BEZEL ────────┐   holds display glass, 2× M2×4 radial screws
   │   ESP32-2424S012       │   USB-C + on/off button through the side wall
   │   ADS1115 bay          │
   │── floor (wire holes) ──│
   │   LiPo pocket ↓ opens  │
   └── threaded spigot ─────┘
   ┌──────── CAP ──────────┐   unscrew → sensor + battery are accessible
   │   Molex headroom       │
   │   R-22D sensor         │   crush ribs hold it snug
   └──── M16×1 nose out ────┘   fits standard analyzer flow diverters / T-pieces
```

## Files
| File | What |
|---|---|
| `o2_analyzer.scad` | Fully parametric model (OpenSCAD). Every dimension is at the top. |
| `stl/body.stl` | Main body. Print upright (spigot down), no supports. |
| `stl/cap.stl` | Sensor cap. Print open-end up, no supports. |
| `stl/bezel.stl` | Display bezel. Already flipped face-down for printing. |
| `stl/button.stl` | Power-button plunger. |
| `stl/retainer.stl` | Sensor retainer collar. Exported petals-down; print as-is in PETG or TPU. |
| `stl/fit_test.stl` | **Print this first.** Thin rings for the display seat, sensor bore, nose hole, and a 4 mm thread pair. |
| `firmware/O2_Analyzer/O2_Analyzer.ino` | Arduino sketch. |

## ⚠️ Measure before you print
The sensor profile comes from the AII PSR-11-39-MD drawing: 40.4 mm overall and a Ø29.3 mm flange. The intermediate steps were scaled from that drawing, so check the values marked `*` in the SCAD header with calipers, then re-export:
- `s_body_d`, `s_body_h`, `s_flange_h`, `s_boss_d`, `s_oring_d` — the stepped sensor profile.
- `plug_clear` — the space behind the sensor for the Molex plug and its wire bend (11 mm).
- `glass_d`, `glass_stack`, `comp_h` — display glass diameter, glass-to-PCB height, and the tallest component under the PCB.
- `usb_angle`, `btn_angle`, `btn_z_off` — where the USB-C port and the on/off button sit around the board.
- `batt_*` — the battery size. The default is a 602030 (6×20×30 mm, ≈300 mAh). The pocket must fit inside `spigot_id` (37 mm), which allows a diagonal of up to ~36.5 mm.

Export a part with: `openscad -D 'PART="body"' -o body.stl o2_analyzer.scad` (also `cap`, `bezel`, `button`, `fit_test`, `assembly`, `exploded`, `section`).

Print in PETG or ASA with 0.2 mm layers and 4 perimeters (the thread needs them). The thread is 2 mm pitch with 0.3 mm clearance. If yours binds, raise `th_clear` to 0.35–0.4.

If the battery latches are too stiff, lower `latch_hook` to 0.8. If they're too loose, raise it to 1.2.

Tune the retainer clamp after a test assembly. If the sensor still moves with the cap tight, raise `ret_preload` to 0.8. If the cap is hard to tighten fully, lower it to 0.3. A TPU retainer works well and also absorbs shocks.

## Bill of materials
- ESP32-2424S012 (C or N version), taken out of its stock case
- ADS1115 breakout (Adafruit or clone), **without** pin headers
- R-22D type sensor with a 3-pin Molex: PSR-11-39-MD, AST-22D, or Divesoft R-22S
- A Molex mating pigtail for the sensor (sold as an "R-22 sensor cable" or a Molex KK 2.54 3-pin housing)
- A 1S LiPo, 602030 or similar, with a JST-1.25 2-pin plug
- A short JST-1.25 2-pin extension (male/female). The battery-side plug then sits in the battery bay, so you can swap the battery without opening the top.
- A JST-SH 1.0 mm 4-pin pigtail for the board's UART port
- 2× M2×4 self-tapping screws
- Optional: 2× 100 kΩ resistors and a 100 nF capacitor for the battery gauge

## Wiring
| From | To | Notes |
|---|---|---|
| Board JST-SH **3V3** | ADS1115 VDD | |
| Board JST-SH **GND** | ADS1115 GND **and** ADDR | ADDR to GND sets I2C address 0x48 |
| Board JST-SH **RX (GPIO20)** | ADS1115 SDA | The C3 lets you route I2C to any pin. The breakout already has pull-ups. |
| Board JST-SH **TX (GPIO21)** | ADS1115 SCL | |
| Sensor **+** | ADS1115 A0 | |
| Sensor **−** | ADS1115 A1 **and** GND | Grounding the − lead gives the cell a reference so it doesn't float |
| Battery + → 100k → A2 → 100k → GND | ADS1115 A2 | Optional battery gauge. Put 100 nF across the lower resistor. Set `BATT_DIVIDER 0` in the sketch if you skip it. |
| Battery JST | Extension | Extension → board's JST-1.25 BAT port |

**Sensor polarity:** pinouts differ between brands. With a multimeter in air, find the pin pair that reads +8 to +14 mV. The red probe is on **+**, and the third pin is unused.

The board's on/off button drives its IP5306 power chip. Press once to turn on; double-press to turn off. USB-C charges the battery and programs the board. The IP5306 can switch itself off if the load drops very low, but the display backlight keeps the draw well above that level.

## Assembly
1. Solder the wires to the ADS1115. Seat it in the floor recess with double-sided foam tape, then feed the sensor and battery leads down through the two floor holes.
2. Plug the JST-SH pigtail and the battery extension into the board. Drop the board in, display up, so it rests on the three support pads with the USB-C lined up with its slot.
3. Insert the button plunger from inside, before the board goes in, flange inward.
4. Press the bezel on and fit the 2× M2 screws.
5. Plug the battery into the extension in the lead channel, then push the battery up into its pocket until it clicks past the two spring latches. To remove it, hook a finger in the notch and pull it down firmly.
6. Drop the sensor into the cap thread-first, so the nose and O-ring come out through the floor hole. Plug the Molex into the back of the sensor.
7. Drop the retainer collar over the plug so it sits on the sensor's rear cone, with its petals facing up. Screw the cap on. The end of the body's threaded spigot presses the petals down about 0.5 mm, which clamps the sensor's shoulder against the cap floor so it can't move.

## Firmware
Install the **GFX Library for Arduino** (moononournation) and **Adafruit ADS1X15** libraries. Choose the board **ESP32C3 Dev Module** and set *USB CDC On Boot* to Enabled.

The display shows:
- the O2 % in large seven-segment digits
- an arc gauge around the rim
- MOD in feet at PO2 1.4 and 1.6
- battery %
- a STABLE / SETTLING status (STABLE means readings have stayed within 0.15 % for 2 s)
- warnings for a weak or missing sensor

The controls are:
- **Long-press** the screen to calibrate to 20.9 % air.
- **Tap** to switch to the detail page (raw mV and calibration values).
- On the serial console, `c` calibrates to air, `o` calibrates to 100 % O2 (optional second point), and `r` resets.

Calibration is saved in flash. Recalibrate before each use, as you would with any analyzer.

The pin map at the top of the sketch is the commonly published one for this board. If the screen stays dark, check `PIN_TFT_*` first.

## Cylinder flow diverter (`diverter.scad` → `stl/diverter.stl`)
The diverter screws onto the sensor's M16×1 nose. Its counterbore seals radially on the sensor's O-ring.

**How the gas flows:** gas enters through a Ø1.6 mm restrictor in the nose, passes through a small chamber over the sensor face, and exits through 6 side vents. The vents have about 14× the inlet's area, so the sensor stays at roughly ambient pressure and the reading isn't pushed high. The vents sit just behind the cone, so they stay outside the valve.

**Fit:**
- **Yoke (A-clamp) valve:** press the flat Ø18 mm face onto the valve's outlet O-ring.
- **DIN valve:** the cone seats in the mouth of the DIN socket.

**Printing:**
- Print it nose-down, as exported, in PETG, or TPU 95A for a softer seal on the valve. Use 0.12–0.16 mm layers and no supports.
- Printed 1 mm pitch threads are rarely clean. Run an M16×1 tap through it (or set `th_clear = 0` and tap). Thread it on by hand until it stops against the cap.

**Analyzing a cylinder:**
1. Calibrate in air first, with the diverter fitted.
2. Hold the diverter firmly against the valve outlet, then crack the valve **just** enough to hear a gentle hiss. You want roughly 1–2 L/min; the sensor is rated for 0.5–2 SCFH. Don't open it further.
3. Wait for STABLE (about 10–20 s), then read the value.
4. Close the valve **before** pulling the analyzer away.
5. Point the vents away from your face, and never use it on a fully open valve.

A higher flow doesn't give a more accurate reading. It builds pressure at the sensor face and reads high. If the reading creeps up as you open the valve more, you're over-flowing.

## Opening in VS Code
1. Unzip the project somewhere permanent, for example `Documents/o2`.
2. In VS Code, choose **File → Open Workspace from File…** and pick `o2_analyzer.code-workspace`.
3. Install the two recommended extensions when VS Code prompts you: **PlatformIO IDE** and **OpenSCAD**.
4. **Firmware:** PlatformIO detects `firmware/platformio.ini`. The first build downloads the ESP32 toolchain and both libraries, which takes a few minutes. Then use the PlatformIO toolbar at the bottom of the window:
   - ✓ builds the firmware.
   - → uploads it to the board.
   - 🔌 opens the serial monitor at 115200 baud.

   If the upload doesn't connect, hold the board's BOOT button while you plug in USB-C.
5. **Enclosure:** open any `.scad` file and click *Preview in OpenSCAD*. This needs the OpenSCAD app installed, from openscad.org. After you change parameters, export the STLs from OpenSCAD.
