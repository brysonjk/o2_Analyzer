// =====================================================================
//  Compact O2 Analyzer  —  ESP32-2424S012 + ADS1115 + R-22D sensor
//  Parametric OpenSCAD enclosure.  All units mm.
//
//  Layout (top to bottom), one Ø46 cylinder:
//    BEZEL  : snaps/screws over the round display
//    BODY   : display seat, ADS1115 bay, battery pocket (opens downward),
//             threaded spigot at the bottom
//    CAP    : screws onto the body, holds the R-22D sensor face-down with
//             the M16x1 nose sticking out (fits standard flow diverters)
//
//  Unscrew the CAP  ->  sensor lifts out, Molex unplugs, and the battery
//  slides out of its pocket.  Both are user-serviceable from one joint.
//
//  Render one part:  set PART below, or from the CLI:
//     openscad -D 'PART="body"' -o body.stl o2_analyzer.scad
// =====================================================================

PART = "assembly";   // assembly | body | cap | bezel | button | fit_test | all_print

/* ---------- MEASURE THESE WITH CALIPERS BEFORE PRINTING ---------- */
// ESP32-2424S012 (bare board, out of its stock case)
pcb_d          = 38.5;   // PCB outer diameter (spec: 38.5 x 37 mm)
glass_d        = 36.6;   // round display glass / backlight frame dia
glass_stack    = 3.6;    // glass top -> PCB top surface (display side)
pcb_t          = 1.0;
comp_h         = 3.8;    // tallest part under the PCB (USB-C, module)
view_d         = 33.0;   // visible window (active area ≈ Ø32.4)

// USB-C and on/off button positions (angle measured CCW looking from top,
// 0° = +X).  Rotate these to match YOUR board.
usb_angle      = 270;
usb_w          = 9.6;
usb_h          = 3.8;
btn_angle      = 0;      // IP5306 on/off button (side-actuated)
btn_d          = 3.2;    // plunger hole
btn_z_off      = 1.6;    // button centre below PCB bottom face

// R-22D type sensor — from the AII PSR-11-39-MD drawing
// (overall 1.590" = 40.4 mm, flange Ø1.154" = 29.3 mm; other steps scaled
//  from the drawing, so caliper-check the ones marked *)
s_flange_d     = 29.3;   // widest flange (dimensioned)
s_flange_h     = 6.8;    // *
s_body_d       = 25.6;   // * upper body, between flange and O-ring neck
s_body_h       = 13.1;   // *
s_taper_h      = 3.1;    // * chamfer from flange down to the rear boss
s_boss_d       = 14.7;   // * rear boss, Molex recessed inside it
s_boss_h       = 3.9;    // *
s_oring_d      = 19.9;   // * O-ring OD on the neck
s_neck_h       = 5.2;    // * shoulder -> start of thread
s_thread_d     = 16.0;   // M16 x 1
s_thread_h     = 8.3;    // * (makes the 40.4 overall)
plug_clear     = 11.0;
// Retainer collar: clamps the sensor's rear cone so it can't float.
ret_id         = 24.0;   // inner edge rests on the sensor's rear cone; passes the Molex plug
ret_preload    = 0.5;    // spring-petal deflection when the cap is fully tightened
ret_petal_t    = 0.8;   // space behind the boss face for the mating Molex plug + wire bend

sensor_h       = s_body_h + s_flange_h + s_taper_h + s_boss_h;   // shoulder -> rear face (26.9)
nose_len       = s_neck_h + s_thread_h;                          // sticks out the front (13.5)

// LiPo (default 602030: 6 x 20 x 30 mm, ~300 mAh)
batt_t         = 6.0;
batt_w         = 20.0;
batt_l         = 30.0;

// ADS1115 breakout (Adafruit / clone ≈ 28 x 17.8)
ads_l          = 28.6;
ads_w          = 18.4;
ads_zone       = 5.0;    // free height for ADS board + soldered wires

/* ---------- Enclosure ---------- */
od             = 46.0;
fit            = 0.30;   // general radial clearance
bezel_plate    = 1.2;
rim_h          = 3.8;    // body rim engaged inside the bezel skirt
rim_wall       = 1.2;    // bezel skirt wall

// thread between body and cap
th_pitch       = 2.0;
th_depth       = 0.9;
th_len         = 7.0;
th_major       = 42.4;   // male (body spigot) major diameter
th_clear       = 0.30;   // radial clearance male/female
spigot_id      = 37.0;   // must pass the battery diagonal (36.1 for 602030)

cap_floor      = 1.6;

$fn = 96;
eps = 0.01;

/* ---------- Derived heights (body z=0 at spigot end) ---------- */
z_batt0   = th_len;                        // battery pocket bottom opening
batt_zone = batt_t + 1.2;
z_floor   = z_batt0 + batt_zone;           // floor between battery & ADS
floor_t   = 1.2;
z_cav0    = z_floor + floor_t;             // ADS cavity floor
z_pcb     = z_cav0 + ads_zone + comp_h;    // PCB bottom face rests here
z_glass   = z_pcb + pcb_t + glass_stack;   // glass top
body_h    = z_glass;
z_rim0    = body_h - rim_h;

disp_bore = pcb_d + 2*fit + 0.4;
cav_bore  = od - 2*2.4;                    // ADS / component cavity

// the spigot bore (th_len deep) is already free space above the cap cavity
cav_above = max(1.0, plug_clear - th_len);
cap_h     = cap_floor + sensor_h + cav_above + th_len;
echo(str("Retainer height: ", ret_z1 - ret_z0));
echo(str("Body height: ", body_h, "  Cap height: ", cap_h));
echo(str("Overall height (excl. nose): ", body_h + bezel_plate + cap_h - th_len,
         "   nose protrudes: ", nose_len - cap_floor));

/* =====================================================================
   Helical thread: horizontal cross-section r(θ) extruded with twist.
   Exact single-start helix; same generator for male and female.
   ===================================================================== */
function th_prof(t, rmin, d) =             // t in [0,1): trapezoid profile
    let(f = t - floor(t))
    f < 0.12 ? rmin :
    f < 0.42 ? rmin + d * (f - 0.12) / 0.30 :
    f < 0.58 ? rmin + d :
    f < 0.88 ? rmin + d * (0.88 - f) / 0.30 :
    rmin;

module thread_section(rmin, d, n = 120) {
    polygon([for (i = [0 : n - 1])
        let(a = 360 * i / n, r = th_prof(a / 360, rmin, d))
        [r * cos(a), r * sin(a)]]);
}

module thread_solid(rmin, d, len, pitch) {
    linear_extrude(height = len, twist = -360 * len / pitch,
                   slices = ceil(len / pitch * 20), convexity = 6)
        thread_section(rmin, d);
}

/* ============================== BODY ================================= */
module body() {
    difference() {
        union() {
            // main tube (above spigot), stepped rim at the top for the bezel
            translate([0, 0, th_len]) cylinder(d = od, h = z_rim0 - th_len);
            translate([0, 0, z_rim0 - eps]) cylinder(d = od - 2*rim_wall - 2*fit, h = rim_h + eps);
            // threaded spigot (male) with a lead-in chamfer
            intersection() {
                thread_solid(th_major/2 - th_depth, th_depth, th_len + eps, th_pitch);
                union() {
                    translate([0, 0, -0.05]) cylinder(d1 = th_major - 2*th_depth - 0.6, d2 = th_major + 0.6, h = 1.25);
                    translate([0, 0, 1.2 - eps]) cylinder(d = th_major + 1, h = th_len);
                }
            }
        }

        // spigot bore (sensor Molex + wiring space, battery passes through)
        translate([0, 0, -eps]) cylinder(d = spigot_id, h = th_len + 2*eps);

        // battery pocket (opens downward) + side channel for its plug/leads
        translate([0, 0, z_batt0 - eps]) {
            translate([-batt_l/2 - 0.4, -batt_w/2 - 0.4, 0])
                cube([batt_l + 0.8, batt_w + 0.8, batt_zone + eps]);
            // lead channel along +Y edge (JST-1.25 extension sits here)
            translate([-9, batt_w/2, 0]) cube([18, 6.0, batt_zone + eps]);
            // finger notch to pull the battery
            translate([0, -batt_w/2 - 0.4, 0]) scale([1, 0.45, 1])
                cylinder(r = 7, h = batt_zone * 0.6);
        }

        // wire pass-throughs in the floor: battery leads + sensor leads
        translate([ 6, batt_w/2 + 3, z_floor - 1]) cylinder(d = 4.2, h = floor_t + 2, $fn = 32);
        translate([-6, batt_w/2 + 3, z_floor - 1]) cylinder(d = 4.2, h = floor_t + 2, $fn = 32);

        // ADS1115 + under-PCB component cavity
        translate([0, 0, z_cav0]) cylinder(d = cav_bore, h = z_pcb - z_cav0 + eps);
        // ADS pocket in floor (0.8 deep locator)
        translate([-ads_l/2, -ads_w/2 - 3, z_cav0 - 0.8]) cube([ads_l, ads_w, 1]);

        // display seat
        translate([0, 0, z_pcb]) cylinder(d = disp_bore, h = body_h);
        // leave 3 support pads for the PCB: cut cavity between them
        // (pads are what remains of the ledge between disp_bore and cav_bore)

        // USB-C slot (opening flares outward for the plug overmould)
        rotate([0, 0, usb_angle]) translate([od/2 - 3.5, 0, z_pcb - usb_h/2 - 0.2]) {
            rotate([0, 90, 0]) linear_extrude(4) offset(r = 1.2) offset(delta = -1.2)
                square([usb_h + 0.6, usb_w + 0.6], center = true);
            translate([2.2, 0, 0]) rotate([0, 90, 0]) linear_extrude(3) offset(r = 2)
                square([usb_h + 3, usb_w + 3.4], center = true);
        }

        // on/off button plunger bore
        rotate([0, 0, btn_angle]) translate([0, 0, z_pcb - btn_z_off])
            rotate([0, 90, 0]) {
                cylinder(d = btn_d + 0.3, h = od);
                translate([0, 0, cav_bore/2 - 0.5]) cylinder(d = btn_d + 2.6, h = 1.4); // plunger flange recess
            }

        // two M2 radial screw holes through the rim for the bezel
        for (a = [45, 225]) rotate([0, 0, a])
            translate([od/2 - rim_wall - 4, 0, z_rim0 + rim_h/2]) rotate([0, 90, 0])
                cylinder(d = 1.6, h = 6, $fn = 24);

        // top chamfer on rim inner edge (eases display insertion)
        translate([0, 0, body_h - 0.8]) cylinder(d1 = disp_bore, d2 = disp_bore + 1.6, h = 0.8 + eps);
    }

    // PCB support pads in the cavity (3 pads, skip USB + button sectors)
    for (a = [usb_angle + 120, usb_angle + 240, usb_angle + 60])
        if (abs(((a - btn_angle + 540) % 360) - 180) > 20)
        rotate([0, 0, a]) translate([cav_bore/2 - 2.4, -2, z_cav0])
            cube([2.6, 4, z_pcb - z_cav0]);

    // battery latches: two spring beams inside the spigot, one at each short
    // end of the battery.  Push the battery up -> it snaps past the hooks;
    // pull down firmly with the finger notch to remove.
    for (m = [0, 1]) mirror([m, 0, 0]) battery_latch();
}

latch_x    = batt_l/2 + 0.5;   // beam inner face (just behind the pocket wall)
latch_t    = 1.0;              // beam thickness (flex direction)
latch_w    = 6.0;
latch_hook = 1.0;              // how far the hook reaches under the battery edge (0.5 overlap)
latch_z0   = 0.8;              // clear of the retainer petals below the spigot end

module battery_latch() {
    r_wall = spigot_id/2;
    // root: ties the beam into the spigot wall
    translate([latch_x, -latch_w/2, latch_z0])
        cube([sqrt(r_wall*r_wall - (latch_w/2)*(latch_w/2)) - latch_x + 0.6, latch_w, 1.5]);
    // beam
    translate([latch_x, -latch_w/2, latch_z0]) cube([latch_t, latch_w, z_batt0 + 0.6 - latch_z0]);
    // hook: 45° lead-in below, ~30° retaining ramp above (battery rests on it)
    translate([0, latch_w/2, 0]) rotate([90, 0, 0]) linear_extrude(latch_w)
        polygon([[latch_x, z_batt0 - 1.8], [latch_x - latch_hook, z_batt0 - 0.8],
                 [latch_x - latch_hook, z_batt0 + 0.0], [latch_x, z_batt0 + 0.6]]);
}

/* ============================== BEZEL ================================ */
module bezel() {
    skirt_h = rim_h;
    difference() {
        union() {
            cylinder(d = od, h = skirt_h + bezel_plate);
        }
        translate([0, 0, -eps]) cylinder(d = od - 2*rim_wall, h = skirt_h + eps);
        // display window with outward chamfer
        translate([0, 0, skirt_h - eps]) cylinder(d = view_d, h = bezel_plate + 2*eps);
        translate([0, 0, skirt_h + bezel_plate - 0.8]) cylinder(d1 = view_d, d2 = view_d + 1.6, h = 0.8 + eps);
        // glass recess (glass sits 0.4 into the plate, so it can't shift)
        translate([0, 0, skirt_h - eps]) cylinder(d = glass_d + 0.5, h = 0.4 + eps);
        // M2 screw clearance + countersink
        for (a = [45, 225]) rotate([0, 0, a])
            translate([od/2 - 3, 0, skirt_h/2]) rotate([0, 90, 0]) {
                cylinder(d = 2.3, h = 6, $fn = 24);
                translate([0, 0, 2.2]) cylinder(d1 = 2.3, d2 = 4.2, h = 1.0, $fn = 24);
            }
        // top outer edge chamfer
        translate([0, 0, skirt_h + bezel_plate - 0.6])
            difference() { cylinder(d = od + 1, h = 1); cylinder(d1 = od, d2 = od - 1.2, h = 0.6 + eps); }
    }
}

/* =============================== CAP ================================= */
module cap() {
    tot = cap_h;
    difference() {
        cylinder(d = od, h = tot);
        // female thread (top)
        translate([0, 0, tot - th_len])
            thread_solid(th_major/2 - th_depth + th_clear, th_depth, th_len + eps, th_pitch);
        translate([0, 0, tot - 1.0]) cylinder(d1 = th_major - 2*th_depth + 2*th_clear - 0.6, d2 = th_major + 2*th_clear + 0.8, h = 1 + eps);
        // Molex plug headroom (opened to thread minor so the retainer petals fit)
        translate([0, 0, cap_floor + sensor_h - eps]) cylinder(d = th_major - 2*th_depth + 2*th_clear - 0.2, h = cav_above + 2*eps);
        // stepped sensor bore: upper body (centres the sensor) then flange
        translate([0, 0, cap_floor]) cylinder(d = s_body_d + 2*fit, h = s_body_h + eps);
        translate([0, 0, cap_floor + s_body_h]) cylinder(d = s_flange_d + 2*fit, h = sensor_h - s_body_h + eps);
        translate([0, 0, cap_floor + s_body_h - 0.6]) cylinder(d1 = s_body_d + 2*fit, d2 = s_flange_d + 2*fit, h = 0.6 + eps);
        // nose hole (O-ring passes through when the sensor drops in)
        translate([0, 0, -eps]) cylinder(d = s_oring_d + 1.0, h = cap_floor + 2*eps);
        // bottom outer chamfer
        translate([0, 0, -eps]) difference() {
            cylinder(d = od + 1, h = 0.8);
            cylinder(d1 = od - 1.6, d2 = od, h = 0.8 + eps);
        }
        // grip flutes
        for (i = [0 : 17]) rotate([0, 0, i * 20])
            translate([od/2 + 0.6, 0, 2]) cylinder(d = 2.4, h = tot - th_len - 3, $fn = 16);
    }
    // 4 crush ribs on the upper-body section
    for (i = [0 : 3]) rotate([0, 0, 45 + i * 90])
        translate([s_body_d/2 + fit - 0.35, -0.6, cap_floor])
            cube([0.8, 1.2, s_body_h - 1]);
}

/* ========================= SENSOR RETAINER ============================ */
// Sits on the sensor's rear cone; its spring petals are pressed by the end
// of the body's threaded spigot, clamping the sensor shoulder to the cap
// floor.  Print petals-down (as exported) in PETG or TPU, no supports.
z_flange_top = cap_floor + s_body_h + s_flange_h;
cone_r0      = s_flange_d / 2;
cone_r1      = s_boss_d / 2;
function cone_z(r) = z_flange_top + 0.2 + s_taper_h * (cone_r0 - r) / (cone_r0 - cone_r1);
ret_z0       = cone_z(ret_id / 2);                 // flat bottom edge touches the cone here
ret_z1       = cap_h - th_len + ret_preload;       // petal top (spigot end + preload)
ret_od       = s_flange_d + 2*fit - 0.4;           // tube OD inside the flange bore
ret_petal_od = th_major - 2*th_depth + 2*th_clear - 0.6;

module retainer() {
    difference() {
        union() {
            translate([0, 0, ret_z0]) cylinder(d = ret_od, h = ret_z1 - ret_z0);
            translate([0, 0, ret_z1 - ret_petal_t]) cylinder(d = ret_petal_od, h = ret_petal_t);
        }
        translate([0, 0, ret_z0 - 1]) cylinder(d = ret_id, h = ret_z1 - ret_z0 + 2);
        // 8 slots split the flange into spring petals
        for (i = [0 : 7]) rotate([0, 0, i * 45])
            translate([ret_od/2 - 0.3, -0.7, ret_z1 - ret_petal_t - 1]) cube([10, 1.4, ret_petal_t + 2]);
        // wire notch so the sensor leads can lie flat if needed
        translate([-2.5, ret_id/2 - 1, ret_z1 - 3]) cube([5, 4, 4]);
    }
}

/* ======================= BUTTON PLUNGER ============================== */
module button() {
    wall_len = od/2 - cav_bore/2 + 0.6;
    cylinder(d = btn_d - 0.2, h = wall_len + 0.6, $fn = 32);   // shaft
    cylinder(d = btn_d + 2.0, h = 1.0, $fn = 32);              // inner flange (stops fall-out)
    translate([0, 0, wall_len + 0.6]) sphere(d = btn_d - 0.2, $fn = 32);
}

/* ===================== FIT TEST (print first) ======================== */
// Thin slices of every critical diameter: display seat, sensor bore,
// nose hole, and 3 mm of mating thread.  ~15 min of printing.
module fit_test() {
    // display seat ring
    difference() { cylinder(d = disp_bore + 3, h = 2); translate([0,0,-eps]) cylinder(d = disp_bore, h = 3); }
    // sensor ring + nose ring
    translate([52, 0, 0]) difference() {          // floor + upper-body step + flange step
        cylinder(d = s_flange_d + 2*fit + 3, h = 6);
        translate([0, 0, -eps]) cylinder(d = s_oring_d + 1.0, h = 7);
        translate([0, 0, cap_floor]) cylinder(d = s_body_d + 2*fit, h = 7);
        translate([0, 0, 4]) cylinder(d = s_flange_d + 2*fit, h = 7);
    }
    // thread pair
    translate([0, 54, 0]) intersection() { body(); cylinder(d = od + 1, h = 4); }
    translate([54, 54, 0]) difference() {
        cylinder(d = od, h = 4);
        translate([0, 0, -eps]) thread_solid(th_major/2 - th_depth + th_clear, th_depth, 4 + 2*eps, th_pitch);
    }
}

/* ======================== Reference dummies ========================== */
module dummy_sensor() {
    color("#333") {
        cylinder(d = s_body_d, h = s_body_h);
        translate([0, 0, s_body_h]) cylinder(d = s_flange_d, h = s_flange_h);
        translate([0, 0, s_body_h + s_flange_h]) cylinder(d1 = s_flange_d, d2 = s_boss_d, h = s_taper_h);
        translate([0, 0, sensor_h - s_boss_h - eps]) cylinder(d = s_boss_d, h = s_boss_h);
        translate([0, 0, -s_neck_h]) cylinder(d = 17.3, h = s_neck_h);
        translate([0, 0, -s_thread_h - s_neck_h]) cylinder(d = s_thread_d, h = s_thread_h);
    }
    color("black") translate([0, 0, -3]) rotate_extrude() translate([8.65 + 0.6, 0]) circle(d = 1.6, $fn = 16);
    color("white") translate([-4, -2.5, sensor_h]) cube([8, 5, 6]);       // mating plug
    color("red") for (x = [-2.5, 0, 2.5]) translate([x, 0, sensor_h + 6]) cylinder(d = 1.2, h = 3, $fn = 8);
}
module dummy_display() {
    color("darkgreen") cylinder(d = pcb_d, h = pcb_t);
    color("black") translate([0, 0, pcb_t]) cylinder(d = glass_d, h = glass_stack);
    color("royalblue") translate([0, 0, pcb_t + glass_stack - 0.05]) cylinder(d = 32.4, h = 0.1);
    color("gray") rotate([0, 0, usb_angle]) translate([pcb_d/2 - 7, -4.5, -3.2]) cube([7.3, 9, 3.2]);
}

/* ============================ Output ================================= */
module assembly(explode = 0) {
    cap_tot = cap_h;
    color("#3a6ea5") body();
    translate([0, 0, body_h - rim_h + explode * 1.2]) color("#2c2c2c") bezel();
    translate([0, 0, z_pcb + explode * 0.8]) dummy_display();
    color("purple") translate([-ads_l/2, -ads_w/2 - 3, z_cav0]) cube([ads_l, ads_w, 1.6]);
    color("orange") translate([-batt_l/2, -batt_w/2, z_batt0 + 0.4 - explode * 0.5]) cube([batt_l, batt_w, batt_t]);
    translate([0, 0, th_len - cap_tot - explode]) {
        color("#e0e0e0") cap();
        color("#d08030") translate([0, 0, explode * 0.4]) retainer();
        translate([0, 0, cap_floor]) dummy_sensor();
    }
}

if (PART == "assembly")        assembly(0);
else if (PART == "exploded")   assembly(18);
else if (PART == "section")    difference() { assembly(0); translate([0, -50, -60]) cube([100, 100, 140]); }
else if (PART == "body")       body();
else if (PART == "bezel")      translate([0, 0, rim_h + bezel_plate]) rotate([180, 0, 0]) bezel();
else if (PART == "cap")        cap();
else if (PART == "retainer")   translate([0, 0, ret_z1]) rotate([180, 0, 0]) retainer();
else if (PART == "button")     button();
else if (PART == "fit_test")   fit_test();
