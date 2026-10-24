# Compact O2 Analyzer — ESP32-2424S012 + ADS1115 + R-22D

A handheld analyzer (Ø46 mm body with a Ø50 mm bezel) made from **4 printed parts and no screws**: bezel, body, cap and diverter. The round display sits on top. The cap unscrews in under one turn to give access to both the sensor and the battery. It's 68.3 mm long plus the sensor's 4.8 mm threaded nose, or 81.9 mm with the diverter on.

```
   ┌──────── BEZEL ────────┐   screws onto the rim, holds the display glass
   │   ESP32-2424S012       │   USB-C slot + flexure power button in the wall
   │   ADS1115 bay          │
   │── floor (wire holes) ──│
   │   LiPo pocket ↓ opens  │   two spring latches hold the battery
   └── 4-start spigot ──────┘
   ┌──────── CAP ──────────┐   < 1 turn off → battery + sensor accessible
   │   Molex headroom       │
    \    R-22D sensor     /    cap tapers to follow the sensor
     │                  │
     └── floor + O-ring ┘       sensor shoulder sits on the floor; O-ring seals in its hole
       │  DIVERTER    │         screws onto the sensor nose and clamps the floor
       └ DIN cone/yoke┘         Ø1.6 mm restrictor inlet
```

## Files
| File | What |
|---|---|
| `o2_analyzer.scad` | Fully parametric model (OpenSCAD). Every dimension is at the top. |
| `stl/body.stl` | Main body. Print upright (spigot down), no supports. |
| `stl/cap.stl` | Cap. The sensor sits on its floor. Print open-end up, as exported, no supports (the taper is under 45°). |
| `diverter.scad` → `stl/diverter.stl` | Screw-on diverter. It also holds the sensor in. Print nose-down, no supports. |
| `stl/bezel.stl` | Screw-on display bezel. Already flipped face-down for printing. |
| `stl/fit_test.stl` | **Print this first.** Display seat ring, sensor seat (the cap floor with its O-ring hole, plus the body bore), flange ring, and a 4 mm thread pair. |
| `step/*.step` | The same parts as STEP solids for Fusion 360 or SolidWorks (see CAD files below). |
| `firmware/O2_Analyzer/O2_Analyzer.ino` | Arduino sketch. |

## ⚠️ Measure before you print
The sensor profile is measured from a real PSR-11-39-MD:
- 40.5 mm overall.
- A 6.59 mm threaded nose, with the O-ring at its base (1.7 mm thick, 18.0 mm across when fitted).
- A Ø26 × 15.75 mm body.
- A Ø28.5 × 8.5 mm flange. AII's drawing says Ø29.3 (1.154"), so other makes may differ.

Other R-22D-type sensors may differ slightly, so check them against yours. Only the rear taper and boss (marked `*`) are still estimates. `s_nose_h` and the O-ring size set how much thread the diverter grips, so they matter most. If you change the nose values or `cap_floor_t`, change them in `diverter.scad` too.
- `plug_clear` — the space behind the sensor for the Molex plug and its wire bend (11 mm).
- `pcb_d`, `pcb_tab_w`, `pcb_tab_r`: the board outline, a 37 mm circle plus a 14.23 mm tab at the USB-C end, 38.5 mm overall, from the board's spec drawing. The board has a factory **42 mm cover glass** (1.75 mm thick, bevelled to 0.5 mm over its outer 2 mm, underside 3.3 mm above the back of the board) that overhangs the board. It sits in a 42.6 mm pocket at the top of the body (`cover_d`, `cover_t`, `cover_under`), which is why the rim and bezel are wider than the rest of the body. The on/off switch sticks out about 0.4 mm past the board edge (`sw_protrude`) and has its own channel down the rim.
- `glass_d`, `glass_stack`, `comp_h` — display glass diameter, glass-to-PCB height, and the tallest component under the PCB.
- `usb_off`: the USB-C connector sits 2.6 mm left of the tab's centre with the display facing you (−2.6).
- `usb_angle`, `btn_angle`, `btn_z_off`, `btn_reach`: where the USB-C port and the on/off switch sit, and how far in the button nub reaches. Angles are measured looking at the display side: 0° is right, 270° is the USB-C end, and 180° puts the switch on the left.
- `pad_angles`: where the three board support pads go. Check that the back of your board has no parts at its edge at 30°, 150° and 300°.
- `batt_*` — the battery size. The default is a 602030 (6×20×30 mm, ≈300 mAh). The pocket must fit inside `spigot_id` (37 mm), which allows a diagonal of up to ~36.5 mm.
- `ads_zone` — 3.8 mm for the ADS1115 with its wires soldered flat. Raise it if your wiring stands taller.

Export a part with: `openscad -D 'PART="body"' -o body.stl o2_analyzer.scad` (also `cap`, `bezel`, `fit_test`, `assembly`, `exploded`, `section`). Export the diverter with `openscad -o diverter.stl diverter.scad`.

Print in PETG or ASA with 0.2 mm layers and 4 perimeters, because the threads need them. The body/cap thread is 4-start: 2 mm between ridges, 8 mm advance per turn, and 0.4 mm clearance.

The body prints spigot-down, so its thread starts on the build plate. Turn on your slicer's **elephant foot compensation** (about 0.15 mm in Bambu Studio). Otherwise the first layers swell and the cap won't start. The spigot also has a 2 mm lead-in chamfer and thread relief at both ends to help.

**Tuning after a test print:**
| Feature | Parameter | Too stiff | Too loose |
|---|---|---|---|
| Battery latches | `latch_hook` (1.0) | 0.8 | 1.2 |
| Body/cap thread | `th_clear` (0.40) | 0.5 | 0.3 |
| Display board in the body | `disp_clear` (0.5) | 0.7 | 0.3 |
| Board's USB-C tab in the body | `tab_clear` (0.7) | 0.9 | 0.5 |
| Sensor fit in the cap | `body_clear` (0.5) / `flange_clear` (0.4) | +0.2 | −0.2 |
| O-ring seal in the cap floor | `oring_squeeze` (0.2) | 0.15 | 0.25 |
| Bezel thread | `bz_clear` (0.30) | 0.4 | 0.2 |
| Power button | `btn_reach` (19.4) | — | lower it, e.g. 19.5, if a press doesn't click the switch |

## Bill of materials
- ESP32-2424S012 (C or N version), taken out of its stock case
- ADS1115 breakout (Adafruit or clone), **without** pin headers
- R-22D type sensor with a 3-pin Molex: PSR-11-39-MD, AST-22D, or Divesoft R-22S
- A Molex mating pigtail for the sensor (sold as an "R-22 sensor cable" or a Molex KK 2.54 3-pin housing). Silicone-insulated wire is best, because it flexes the most as the cap turns.
- A 1S LiPo, 602030 or similar, with a JST-1.25 2-pin plug
- A short JST-1.25 2-pin extension (male/female). The battery-side plug then sits in the battery bay, so you can swap the battery without opening the top.
- Four thin wires (about 28–30 AWG silicone) soldered to the board's 4-pin SH 1.0 connector. There's no room in the body for a plug in that side-entry connector, so solder the wires directly to its pins, or remove the connector and solder to its pads.
- Optional: 2× 100 kΩ resistors and a 100 nF capacitor for the battery gauge

No screws are needed.

## Wiring
| From | To | Notes |
|---|---|---|
| Board SH-connector pin **3V3** | ADS1115 VDD | Solder to the pins, no plug (see the bill of materials) |
| Board SH-connector pin **GND** | ADS1115 GND **and** ADDR | ADDR to GND sets I2C address 0x48 |
| Board SH-connector pin **RX (GPIO20)** | ADS1115 SDA | The C3 lets you route I2C to any pin. The breakout already has pull-ups. |
| Board SH-connector pin **TX (GPIO21)** | ADS1115 SCL | |
| Sensor **+** | ADS1115 A0 | |
| Sensor **−** | ADS1115 A1 **and** GND | Grounding the − lead gives the cell a reference so it doesn't float |
| Battery + → 100k → A2 → 100k → GND | ADS1115 A2 | Optional battery gauge. Put 100 nF across the lower resistor. Set `BATT_DIVIDER 0` in the sketch if you skip it. |
| Battery JST | Extension | Extension → board's JST-1.25 BAT port |

**Sensor polarity:** pinouts differ between brands. With a multimeter in air, find the pin pair that reads +8 to +14 mV. The red probe is on **+**, and the third pin is unused.

The board's on/off button drives its IP5306 power chip. Press once to turn on; double-press to turn off. USB-C charges the battery and programs the board. The IP5306 can switch itself off if the load drops very low, but the display backlight keeps the draw well above that level.

## Assembly
1. Solder the wires to the ADS1115. Seat it in the floor recess with double-sided foam tape, then feed the sensor and battery leads down through the two floor holes. Leave the sensor leads about 3 cm longer than the straight run. The cap turns a little under one turn, and that slack takes up the twist.
2. Solder the four ADS1115 wires to the board's SH connector pins, at the lower right with the display facing you, and plug the battery extension into the board. Drop the board in, display up, so it rests on the three support pads with the USB-C lined up with its slot. The 42 mm cover glass settles into the pocket at the top, level with the rim. The on/off switch, on the board's left edge, lines up with the flexible tab in the wall. Three small pads under the board's edge support it; they sit where the back of the board has no parts at the edge.
3. Screw the bezel onto the rim clockwise, about three-quarters of a turn, until it seats firmly on the rim's top edge. It sits just above the cover glass, so the glass and board can't lift, and its window shows the flat part of the glass. Snug by hand is enough.
4. Plug the battery into the extension in the lead channel, then push the battery up into its pocket until it clicks past the two spring latches. To remove it, hook a finger in the notch and pull it down firmly.
5. Plug the Molex into the back of the sensor. Drop the sensor nose-first into the cap so its shoulder sits on the floor and the O-ring presses into the floor hole. The threaded nose sticks out underneath.
6. Screw the cap onto the body. It takes a little under one turn.
7. Screw the diverter onto the sensor nose until it's snug against the cap floor. Hand-tight is enough. It works like a nut: the cap floor is clamped between the sensor's shoulder and the diverter, so pressing the analyzer against a valve can't push the sensor up.

To change the sensor, unscrew the diverter and the cap, then lift the sensor out.

**Power button:** press the flat recess on the side of the body. The tab flexes inward and its nub presses the board's button.

## Firmware
Install the **GFX Library for Arduino** (moononournation) and **Adafruit ADS1X15** libraries. Choose the board **ESP32C3 Dev Module** and set *USB CDC On Boot* to Enabled.

### Startup animation
![Startup animation](firmware/boot_animation.gif)

At power-on, bubbles rise and two oxygen atoms drift together and bond. The pair bursts into the gauge ring, and the initials are then traced in light, followed by the title and a dedication line. It lasts about 5 s; tap the screen to skip it. To personalise it, edit the defines above `drawBootFrame()` in the sketch:
- `BOOT_INITIALS` takes 1–5 letters or digits (default `"FSS"`).
- `BOOT_TITLE` is the title line.
- `BOOT_LINE` is the small line under the title (`""` hides it).
- `BOOT_MS` sets the length.

The simulator plays the same animation, so you can preview a change there first; change the constants at the top of its boot-animation block to match.

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

## Diverter: analyzing a cylinder
The diverter screws onto the sensor's M16×1 nose. Its thread starts right at its rear face, so it grips all of the exposed thread, about 5 turns. The sensor's O-ring seals in the cap floor, which keeps gas away from the electronics even with the diverter off, and the diverter's rear face tightens flat against the floor.

Gas enters through a Ø1.6 mm restrictor in the nose, passes through a small chamber over the sensor face, and exits through 6 side vents. The vents have 11–14× the inlet's area, so the sensor stays at roughly ambient pressure and the reading isn't pushed high. The vents sit just behind the cone, so they stay outside the valve.

**Fit:**
- **Yoke (A-clamp) valve:** press the flat Ø18 mm face onto the valve's outlet O-ring.
- **DIN valve:** the cone seats in the mouth of the DIN socket.

**Steps:**
1. Calibrate in air first. With the diverter on, air reaches the sensor through the vents by diffusion, so give it about a minute to settle. Or calibrate with the diverter off, which responds in seconds, but screw it back on before you measure, because it's what holds the sensor in. Wait for STABLE, then long-press to calibrate.
2. Hold the analyzer firmly against the valve outlet, then crack the valve **just** enough to hear a gentle hiss. You want roughly 1–2 L/min; the sensor is rated for 0.5–2 SCFH. Don't open it further.
3. Wait for STABLE (about 10–20 s), then read the value.
4. Close the valve **before** pulling the analyzer away.
5. Point the vents away from your face, and never use it on a fully open valve.

A higher flow doesn't give a more accurate reading. It builds pressure at the sensor face and reads high. If the reading creeps up as you open the valve more, you're over-flowing.

If the flow is hard to control on your valves, change the inlet with `inlet_d` in `diverter.scad`. Use about 1.2 for a gentler flow, or 2.0 if the reading responds too slowly.

## CAD files (STEP) for Fusion 360, SolidWorks, Onshape

> **Out of date:** the STEP files and `cad/o2_analyzer_cq.py` were made from an earlier version, before the sensor was measured, before the screw-on bezel, and before the cap floor that the diverter clamps. They need regenerating before you use them for anything dimensional. The STLs in `stl/` are current.
The `step/` folder has every printed part as a true solid, with exact cylinders, faces and fully modeled threads. Open them with **File → Open** in Fusion 360 or SolidWorks. You can sketch on faces, fillet, cut and measure, then save in that program's own format.

| File | Part | Origin (z = 0) |
|---|---|---|
| `step/body.step` | Body | spigot end |
| `step/bezel.step` | Bezel | lower edge of the skirt |
| `step/cap_open.step` | Open cap | cap floor |
| `step/cap_diverter.step` | Cap with built-in diverter | nose face |
| `step/diverter.step` | Screw-on diverter | nose face |
| `step/o2_analyzer_assembly.step` | Everything assembled (open cap + diverter), with stand-ins for the sensor, display, ADS1115 and battery | — |

Parts are in their assembled orientation, not their print orientation. For printing, use the STLs in `stl/`, or flip the bezel and the built-in cap nose-down in your slicer.

A STEP file has no feature history, so you edit the solid directly (Fusion's Press/Pull, SolidWorks' Move Face). For parametric changes, edit `cad/o2_analyzer_cq.py`, which is a CadQuery port of the SCAD model with the same parameter names, and regenerate everything with:

```
pip install cadquery
python3 cad/o2_analyzer_cq.py          # or: python3 cad/o2_analyzer_cq.py body cap_open
```

Each STEP part matches its OpenSCAD STL to within 0.7% of volume and has identical outer dimensions. Keep the two sources in sync if you change parameters.

## Opening in VS Code
1. Clone this repo (VS Code: **Git: Clone**), or unzip the project somewhere permanent.
2. Open the folder in VS Code with **File → Open Folder…**.
3. Install the two recommended extensions when VS Code prompts you: **PlatformIO IDE** and **OpenSCAD**.
4. **Firmware:** PlatformIO detects `firmware/platformio.ini`. The first build downloads the ESP32 toolchain and both libraries, which takes a few minutes. Then use the PlatformIO toolbar at the bottom of the window:
   - ✓ builds the firmware.
   - → uploads it to the board.
   - 🔌 opens the serial monitor at 115200 baud.

   If the upload doesn't connect, hold the board's BOOT button while you plug in USB-C.
5. **Enclosure:** open any `.scad` file and click *Preview in OpenSCAD*. This needs the OpenSCAD app installed, from openscad.org. After you change parameters, export the STLs from OpenSCAD.
