# Compact O2 Analyzer — ESP32-2424S012 + ADS1115 + R-22D

A Ø46 mm handheld analyzer made from **3 printed parts and no screws**. The round display sits on top. The cap unscrews in under one turn to give access to both the sensor and the battery.

**Choose your cap.** Both use the same body, bezel, snap hooks and thread:
| Cap | Length | Best for |
|---|---|---|
| `stl/cap_open.stl` | 60.5 mm + 11.9 mm sensor nose; 82.2 mm with `stl/diverter.stl` fitted | Using the screw-on diverter, or any standard M16×1 T-piece or inflator adapter. Bare-sensor air calibration responds in seconds. |
| `stl/cap_diverter.stl` | 80.0 mm, diverter built in | The shortest unit with nothing extra to carry or lose. The sensor nose is sealed inside the cap. |

```
   ┌──────── BEZEL ────────┐   twist-lock, holds the display glass
   │   ESP32-2424S012       │   USB-C slot + flexure power button in the wall
   │   ADS1115 bay          │
   │── floor (wire holes) ──│
   │   LiPo pocket ↓ opens  │   two spring latches hold the battery
   └── 4-start spigot ──────┘
   ┌──────── CAP ──────────┐   < 1 turn off → battery + sensor accessible
   │   Molex headroom       │
   │   R-22D sensor         │   clicks into 3 snap hooks
   └──┬── M16×1 nose ───┬───┘   open cap: nose + O-ring exposed
      │  DIVERTER       │       screw-on (optional), or built into
      └ DIN cone / yoke ┘       cap_diverter.stl
```

## Files
| File | What |
|---|---|
| `o2_analyzer.scad` | Fully parametric model (OpenSCAD). Every dimension is at the top. |
| `stl/body.stl` | Main body. Print upright (spigot down), no supports. |
| `stl/cap_open.stl` | Open cap: the sensor nose and O-ring stick out. Print open-end up, no supports. |
| `stl/cap_diverter.stl` | Cap with the diverter built in. Print nose-down, as exported, no supports. |
| `diverter.scad` → `stl/diverter.stl` | Push-on diverter for the open cap. Print nose-down, no supports. |
| `stl/diverter_threaded.stl` | The same diverter with an M16×1 thread (`mount = "thread"`). Run an M16×1 tap through it before use. |
| `stl/bezel.stl` | Twist-lock display bezel. Already flipped face-down for printing. |
| `stl/fit_test.stl` | **Print this first.** Display seat ring, sensor seat (O-ring bore and upper-body bore), flange ring, and a 4 mm thread pair. |
| `step/*.step` | The same parts as STEP solids for Fusion 360 or SolidWorks (see CAD files below). |
| `firmware/O2_Analyzer/O2_Analyzer.ino` | Arduino sketch. |

## ⚠️ Measure before you print
The sensor profile comes from the AII PSR-11-39-MD drawing: 40.4 mm overall and a Ø29.3 mm flange. The intermediate steps were scaled from that drawing, so check the values marked `*` in the SCAD header with calipers, then re-export:
- `s_body_d`, `s_body_h`, `s_flange_h`, `s_boss_d`, `s_oring_d`, `s_neck_h`, `s_thread_h` — the stepped sensor profile. `s_body_h` and `s_flange_h` decide where the snap hooks catch, so they matter most.
- `plug_clear` — the space behind the sensor for the Molex plug and its wire bend (11 mm).
- `glass_d`, `glass_stack`, `comp_h` — display glass diameter, glass-to-PCB height, and the tallest component under the PCB.
- `usb_angle`, `btn_angle`, `btn_z_off`, `btn_reach` — where the USB-C port and the on/off button sit, and how far in the button nub reaches.
- `batt_*` — the battery size. The default is a 602030 (6×20×30 mm, ≈300 mAh). The pocket must fit inside `spigot_id` (37 mm), which allows a diagonal of up to ~36.5 mm.
- `ads_zone` — 3.8 mm for the ADS1115 with its wires soldered flat. Raise it if your wiring stands taller.

Export a part with: `openscad -D 'PART="body"' -o body.stl o2_analyzer.scad` (also `cap`, `bezel`, `fit_test`, `assembly`, `exploded`, `section`). Choose the cap version with `cap_style`: `openscad -D 'cap_style="diverter"' -D 'PART="cap"' -o cap_diverter.stl o2_analyzer.scad`. The default is `"open"`.

Print in PETG or ASA with 0.2 mm layers and 4 perimeters, because the threads and snap features need them. The body/cap thread is 4-start: 2 mm between ridges, 8 mm advance per turn, and 0.4 mm clearance.

The body prints spigot-down, so its thread starts on the build plate. Turn on your slicer's **elephant foot compensation** (about 0.15 mm in Bambu Studio). Otherwise the first layers swell and the cap won't start. The spigot also has a 2 mm lead-in chamfer and thread relief at both ends to help.

**Tuning after a test print:**
| Feature | Parameter | Too stiff | Too loose |
|---|---|---|---|
| Battery latches | `latch_hook` (1.0) | 0.8 | 1.2 |
| Body/cap thread | `th_clear` (0.40) | 0.5 | 0.3 |
| Sensor fit in the cap | `sensor_extra` (0.5) | 0.7 | 0.3 |
| Sensor snap hooks | `hook_overlap` (0.75) / `hook_preload` (0.4) | `hook_overlap` 0.6 | `hook_preload` 0.6 |
| Bezel twist-lock | `bay_lock` (0.05) | 0 | 0.10 |
| Power button | `btn_reach` (19.8) | — | lower it, e.g. 19.5, if a press doesn't click the switch |

## Bill of materials
- ESP32-2424S012 (C or N version), taken out of its stock case
- ADS1115 breakout (Adafruit or clone), **without** pin headers
- R-22D type sensor with a 3-pin Molex: PSR-11-39-MD, AST-22D, or Divesoft R-22S
- A Molex mating pigtail for the sensor (sold as an "R-22 sensor cable" or a Molex KK 2.54 3-pin housing). Silicone-insulated wire is best: it flexes the most as the cap turns.
- A 1S LiPo, 602030 or similar, with a JST-1.25 2-pin plug
- A short JST-1.25 2-pin extension (male/female). The battery-side plug then sits in the battery bay, so you can swap the battery without opening the top.
- A JST-SH 1.0 mm 4-pin pigtail for the board's UART port
- Optional: 2× 100 kΩ resistors and a 100 nF capacitor for the battery gauge

No screws are needed.

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
1. Solder the wires to the ADS1115. Seat it in the floor recess with double-sided foam tape, then feed the sensor and battery leads down through the two floor holes. Leave the sensor leads about 3 cm longer than the straight run. The cap turns a little under one turn, and that slack takes up the twist.
2. Plug the JST-SH pigtail and the battery extension into the board. Drop the board in, display up, so it rests on the three support pads with the USB-C lined up with its slot. The power button lines up with the flexible tab in the wall.
3. Fit the bezel: line up the three small notches on its lower edge with the three slots in the rim, press it down flat, then turn it clockwise about 30° until it stops. To remove it, turn it counter-clockwise and lift it off. Nothing has to flex, so it won't crack.
4. Plug the battery into the extension in the lead channel, then push the battery up into its pocket until it clicks past the two spring latches. To remove it, hook a finger in the notch and pull it down firmly.
5. Plug the Molex into the back of the sensor. Push the sensor nose-first into the cap until the flange clicks under the three hooks.
   - **Open cap:** the nose and O-ring come out through the floor hole.
   - **Built-in cap:** the O-ring seals in the bore below the sensor, so gas from the diverter can't reach the electronics.
6. Screw the cap on. It takes a little under one turn.

To change the sensor, unscrew the cap and pull the sensor straight up by its rear boss. The 45° hooks let go with a firm pull.

**Power button:** press the flat recess on the side of the body. The tab flexes inward and its nub presses the board's button.

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

## Diverter: analyzing a cylinder
The diverter is either the screw-on part on the open cap, or the bottom of `cap_diverter.stl`. Both work the same way.

**Separate diverter (open cap):** push it straight onto the sensor nose until it stops against the cap. Its counterbore slides over the sensor's O-ring, which both seals it and holds it on. Pull it straight off to remove it. While you're measuring, you're pressing it toward the analyzer, so it can't work loose.

- If it's too loose, it falls off or leaks. Shrink `oring_bore` by 0.1–0.2 mm in `diverter.scad`. If it's too tight, enlarge it by the same amount.
- `stl/diverter_threaded.stl` screws onto the M16×1 thread instead. Printed 1 mm pitch threads are rarely clean, so run an M16×1 tap through it first. Then it threads on and stops against the cap.
- Both versions leave 1 mm of extra room behind the O-ring (`neck_margin`), so they still seat if your sensor's neck is a little longer than the drawing suggests.

Gas enters through a Ø1.6 mm restrictor in the nose, passes through a small chamber over the sensor face, and exits through 6 side vents. The vents have 11–14× the inlet's area, so the sensor stays at roughly ambient pressure and the reading isn't pushed high. The vents sit just behind the cone, so they stay outside the valve.

**Fit:**
- **Yoke (A-clamp) valve:** press the flat Ø18 mm face onto the valve's outlet O-ring.
- **DIN valve:** the cone seats in the mouth of the DIN socket.

**Steps:**
1. Calibrate in air first. With the diverter on, air reaches the sensor through the vents by diffusion, so give it about a minute to settle. With the open cap you can also calibrate with the diverter off, which responds in seconds. Wait for STABLE, then long-press to calibrate.
2. Hold the analyzer firmly against the valve outlet, then crack the valve **just** enough to hear a gentle hiss. You want roughly 1–2 L/min; the sensor is rated for 0.5–2 SCFH. Don't open it further.
3. Wait for STABLE (about 10–20 s), then read the value.
4. Close the valve **before** pulling the analyzer away.
5. Point the vents away from your face, and never use it on a fully open valve.

A higher flow doesn't give a more accurate reading. It builds pressure at the sensor face and reads high. If the reading creeps up as you open the valve more, you're over-flowing.

If the flow is hard to control on your valves, change the inlet with `inlet_d` (in `diverter.scad` or `o2_analyzer.scad`). Use about 1.2 for a gentler flow, or 2.0 if the reading responds too slowly.

## CAD files (STEP) for Fusion 360, SolidWorks, Onshape
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
