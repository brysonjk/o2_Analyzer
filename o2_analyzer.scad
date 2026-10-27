// =====================================================================
//  Compact O2 Analyzer  —  ESP32-2424S012 + ADS1115 + R-22D sensor
//  Parametric OpenSCAD enclosure.  Units: mm.
//
//  T layout: the display faces up, the sensor points forward (+Y) along a
//  tube under the display, so the screen reads upright while the diverter
//  is held against a cylinder valve.
//
//    BEZEL    : screws onto the threaded rim of the puck, holds the glass
//    BODY     : display puck: display seat, flexure power button, ADS1115
//               bay. Flat bottom, sits on the tube (2x M2x6 pan-head screws)
//    TUBE     : under the puck: battery pocket, plug space, 4-start threaded
//               spigot pointing forward
//    CAP      : the sensor sits on a thin floor with its threaded nose out;
//               the O-ring seals in the floor hole
//    DIVERTER : (diverter.scad) screws onto the sensor nose like a nut and
//               clamps the cap floor, so the sensor can't push back
//
//  The puck and tube print separately so both threads print upright:
//  puck rim-up, tube spigot-down, cap open end up.
//
//  Unscrew the CAP (< 1 turn)  ->  slide the battery out of the tube; with
//  the diverter off, lift the sensor out of the cap.
//
//  Render one part:  set PART below, or from the CLI:
//     openscad -D 'PART="body"' -o body.stl o2_analyzer.scad
// =====================================================================

PART = "assembly";   // assembly | exploded | section | body | tube | cap | bezel | fit_test | fit_piece
FIT  = "seat";       // with PART = "fit_piece": seat | sensor_seat | flange_ring | thread_male | thread_female

show_diverter = true;     // assembly views: show the screw-on diverter

use <diverter.scad>
div_len = 13.59;          // diverter.scad length (its z_top); its rear face clamps the cap floor

/* ---------- MEASURE THESE WITH CALIPERS BEFORE PRINTING ---------- */
// ESP32-2424S012 (bare board, out of its stock case)
pcb_d          = 37.0;   // round part of the PCB (spec drawing)
pcb_tab_w      = 14.23;  // tab at the USB-C end (spec drawing)
pcb_tab_r      = 20.0;   // centre -> end of the tab (38.5 overall - 18.5)
glass_d        = 36.0;   // round LCD module under the cover glass
cover_d        = 42.0;   // factory cover glass (measured; overhangs the board)
cover_t        = 1.75;   // cover glass thickness (flat part)
cover_bevel_w  = 2.0;    // bevelled band at its edge
cover_edge_t   = 0.5;    // thickness at the very edge
cover_under    = 3.3;    // back of the PCB -> underside of the cover glass (measured)
pcb_t          = 1.0;
comp_h         = 3.8;    // tallest part under the PCB (USB-C, module)
view_d         = 37.0;   // bezel window: the flat part of the cover glass

// USB-C and on/off button positions (angle measured CCW looking from top,
// 0° = +X).  Rotate these to match YOUR board.
usb_angle      = 270;
usb_off        = -2.6;   // USB-C sits 2.6 mm left of the tab centreline with the display
                         //   facing you (measured from the back-of-board photo, mirrored)
usb_w          = 9.6;
usb_h          = 3.8;
usb_plug_w     = 12.8;   // USB-C plug overmould, for the recess outside the slot
usb_plug_h     = 6.2;
btn_angle      = 180;    // IP5306 on/off switch: left edge with the display facing you, USB-C down
sh_angle       = 315;    // 4-pin SH 1.0 connector (lower right), under the board, side entry (test-fitted)
sh_plug_out    = 1.8;    // a plugged-in SH cable: back of the plug, past the board edge (measured)
sh_plug_w      = 7.0;    // plug width (measured, widest part)
sh_plug_h      = 3.0;    // plug height (measured)
sh_bend        = 1.5;    // room behind the plug for its wires to bend down
pad_angles     = [30, 150, 297];   // PCB support pads: clear of USB-C, switch, SH connector + plug, ESP module
btn_z_off      = 1.6;    // button centre below PCB bottom face
btn_reach      = 18.8;   // radius the flexure nub reaches in to (switch face modelled at 18.9; was 19.4,
                         //   which took ~1 mm of extra press). Lower = less travel; too low and it holds the switch down

// R-22D type sensor (PSR-11-39-MD) — measured with calipers on a real sensor
s_total_h      = 40.5;   // thread tip -> rear face
s_nose_h       = 6.59;   // threaded section: shoulder -> tip (O-ring sits at its base)
s_body_d       = 26.0;   // body between the shoulder and the flange
s_body_h       = 15.75;  // shoulder -> underside of the flange
s_flange_d     = 28.5;   // widest flange (measured 3x; the AII drawing says 29.3)
s_flange_h     = 8.5;
s_taper_h      = 3.1;    // * (not measured) chamfer from the flange to the rear boss
s_boss_d       = 14.7;   // * (not measured) rear boss, Molex recessed inside it
s_oring_d      = 18.0;   // O-ring outside diameter as installed on the sensor (17.7 loose)
s_oring_cs     = 1.7;    // O-ring thickness
s_thread_d     = 16.0;   // M16 x 1
plug_clear     = 11.0;   // space behind the boss face for the mating Molex plug + wire bend
body_clear     = 0.5;    // radial room around the body (paper label, print tolerance)
flange_clear   = 0.4;    // radial room around the flange (printed holes shrink ~0.1-0.2)

s_boss_h       = s_total_h - s_nose_h - s_body_h - s_flange_h - s_taper_h;   // rest of the length
sensor_h       = s_body_h + s_flange_h + s_taper_h + s_boss_h;   // shoulder -> rear face (33.9)
nose_len       = s_nose_h;                                       // shoulder -> sensor face
oring_zone     = s_oring_cs + 0.3;                               // O-ring band below the shoulder
s_bore_body    = s_body_d + 2*body_clear;
s_bore_flange  = s_flange_d + 2*flange_clear;

// LiPo (default 602030: 6 x 20 x 30 mm, ~300 mAh)
batt_t         = 6.0;    // measured 5.96 x 20.01 x 31.01 (a real "602030" runs a little long)
batt_w         = 20.1;
batt_l         = 31.1;

// ADS1115 breakout (Adafruit / clone ≈ 28 x 17.8), no headers, wires flat
ads_l          = 28.6;
ads_w          = 18.4;
ads_zone       = 3.8;    // free height for ADS board + soldered wires

/* ---------- Enclosure ---------- */
od             = 46.0;
fit            = 0.30;   // general radial clearance
tab_clear      = 0.7;    // radial room along the sides and end of the PCB's USB-C tab
disp_clear     = 0.5;    // radial room around the display board (printed holes shrink 0.2-0.3)
sw_protrude    = 0.4;    // the on/off switch sticks out past the board's 37 mm edge
sw_notch_w     = 5.0;    // width of the channel for it down the inside of the rim
bezel_plate    = 1.2;
rim_h          = 3.8;    // threaded body rim the bezel screws onto
rim_wall       = 1.2;    // wall between the glass pocket and the rim thread root
glass_clear    = 0.3;    // radial room around the cover glass
seat_lift      = 0.45;   // raises the board (and glass) without moving the rim: a print had the glass
                         //   0.41 below the rim top, so the bezel didn't touch it. 0.45 = 0.41 + ~0.05 preload
// screw-on bezel: 3-start thread on the rim, ~3/4 turn on, seats on the rim top
bz_pitch       = 1.5;    // axial spacing between ridges (lead = 4.5 mm per turn)
bz_starts      = 3;
bz_depth       = 0.7;
bz_clear       = 0.30;   // radial clearance

// tube <-> cap thread: 4-start, so the cap closes in < 1 turn and the
// sensor wires barely twist. The sensor's flange (28.5) passes through it.
th_pitch       = 2.0;    // axial spacing between thread ridges
th_starts      = 4;      // lead = pitch * starts = 8 mm per turn
th_depth       = 0.9;
th_len         = 7.0;
th_major       = 31.0;   // male (tube spigot) major diameter
th_clear       = 0.40;   // radial clearance male/female
th_relief      = 1.5;    // undercut below the cap thread so the cap seats on the shoulder
cap_th_wall    = 1.8;    // cap wall outside the thread root

// cap: the sensor shoulder sits on a floor; the O-ring seals in its hole
cap_floor_t    = 1.8;    // = O-ring band; keep in sync with diverter.scad
cap_wall       = 2.0;    // wall around the sensor
oring_squeeze  = 0.2;    // radial squeeze on the O-ring (~12% of its 1.7 mm section)
oring_bore     = s_oring_d - 2*oring_squeeze;

// tube under the puck
tube_top_wall  = 2.5;    // between the plug space and the puck
plug_box_w     = 22.0;   // plug space: Molex plug, battery JST, leads
plug_box_h     = 9.0;
batt_clear     = 0.5;    // battery pocket clearance, sides and ends
batt_clear_t   = 0.4;    // above and below the battery (the pocket is also batt_lip taller)
batt_lip       = 1.0;    // lip at the front of the battery pocket floor; the battery rides
                         //   over it on the way in, then drops in behind it
tube_end_wall  = 2.0;
screw_x        = 13.0;   // 2x M2 screws joining puck and tube, at (±screw_x, 0)
use_inserts    = true;   // M2 heat-set inserts in the tube (false: self-tapping screws)
insert_hole_d  = 2.5;    // for M2 x 3 inserts 3.0 mm across (about OD - 0.5); check your inserts' recommendation
insert_depth   = 3.5;    // insert length + 0.5; stays above the battery pocket
screw_pilot    = 1.7;    // in the tube, when use_inserts = false
screw_hole     = 2.4;    // in the puck floor
wire_hole_d    = 4.5;

$fn = 96;
eps = 0.01;

/* ---------- Derived heights: BODY / puck (z = 0 at its flat bottom) ---------- */
z_floor   = 0;
floor_t   = 1.2;
z_cav0    = z_floor + floor_t;             // ADS cavity floor
z_pcb     = z_cav0 + ads_zone + comp_h + seat_lift;   // PCB bottom face rests here
z_glass   = z_pcb + cover_under + cover_t;  // cover glass top (as modelled)
body_h    = z_glass + 0.1 - seat_lift;     // rim top: the bezel seats here (unchanged by seat_lift)
z_rim0    = body_h - rim_h;

disp_bore = pcb_d + 2*disp_clear;
cav_bore  = od - 2*2.4;                    // ADS / component cavity
glass_pocket_d = cover_d + 2*glass_clear;
rim_od    = glass_pocket_d + 2*(rim_wall + bz_depth);   // bezel thread crest
bz_od     = rim_od + 2*(bz_clear + 1.5);                // bezel outside (about 50 mm)
ads_pos   = [-ads_w/2, -ads_l/2 + 0.3, z_cav0];         // long side along Y, between the support pads and the wire holes

/* ---------- Derived: CAP (z = 0 at its bottom face) ---------- */
z_sh      = cap_floor_t;                   // sensor shoulder rests on the floor
z_flange0 = z_sh + s_body_h;
z_flange1 = z_flange0 + s_flange_h;
cap_h     = z_flange1 + th_relief + th_len;   // the spigot tip stops 1.5 behind the flange
r_t       = (th_major + 2*th_clear)/2 + cap_th_wall;   // cap thread band = tube radius
s_rear_in_cap = z_sh + sensor_h;           // sensor rear face (sticks out of the cap top)

/* ---------- Derived: TUBE (same frame as the puck; sensor points +Y) ---------- */
z_ax      = -(plug_box_h/2 + tube_top_wall);           // tube axis height
chin_gap  = 0.3;                                        // between the puck's chin and the tube's collar
y_col0    = od/2 + chin_gap;                            // full-round collar starts in front of the puck
collar_wall = 2.0;                                      // solid back wall of the collar, behind the boss bore
y_f       = max((z_ax + r_t > z_rim0 - 0.2 ? bz_od/2 : od/2) + 0.6,   // spigot shoulder, clear of the bezel,
                y_col0 + collar_wall + 0.3 + (s_rear_in_cap - cap_h));  // and far enough forward that the boss bore stays inside the collar
y_srear   = y_f - (s_rear_in_cap - cap_h);              // sensor rear face
y_pk1     = y_srear - plug_clear;                       // battery pocket front (plug space ahead of it)
batt_pk_l = batt_l + 2*batt_clear + batt_lip;
z_pk1     = z_ax + batt_t/2 + batt_clear_t;            // battery pocket top
z_pk0     = z_pk1 - batt_t - 2*batt_clear_t - batt_lip; // battery pocket floor
y_bk0     = y_pk1 - batt_pk_l;                          // battery pocket rear
y_r       = y_bk0 - tube_end_wall;                      // tube rear face
y_bore0   = y_srear - 0.3;                              // boss bore starts here (inside the collar)
y_wire    = min((y_pk1 + y_col0)/2, sqrt(pow(cav_bore/2, 2) - 25) - wire_hole_d/2 - 0.3);
boss_bore = s_boss_d + 1.6;

assert(!use_inserts || -insert_depth > z_pk1 + 0.05 || screw_x - insert_hole_d/2 - (batt_w/2 + batt_clear) > 1.2, "insert holes would break into the battery pocket");
assert(z_pk0 >= z_ax - plug_box_h/2 - 0.01, "battery pocket floor below the plug space");
assert(batt_w + 2*batt_clear <= plug_box_w, "battery won't pass through the plug space");
assert(y_bore0 >= y_col0 + collar_wall - 0.01, "boss bore would break out of the collar's back face");
assert(y_wire - wire_hole_d/2 > y_pk1 + 0.3, "wire holes miss the plug space");
echo(str("z_ax ", z_ax, "  y_col0 ", y_col0, "  y_f ", y_f, "  y_srear ", y_srear, "  y_pk1 ", y_pk1, "  y_bk0 ", y_bk0, "  y_r ", y_r, "  y_wire ", y_wire, "  r_t ", r_t));

echo(str("Puck height: ", body_h, "  Cap length: ", cap_h, "  Tube: y ", y_r, " .. ", y_f + th_len));
echo(str("Overall height: ", body_h - 0.4 + bezel_plate - (z_ax - r_t),
         "   length: ", y_f + cap_h + nose_len - cap_floor_t + bz_od/2,
         "   with the diverter: ", y_f + cap_h + div_len + bz_od/2));

/* =====================================================================
   Helical thread: horizontal cross-section r(θ) extruded with twist.
   Multi-start: the profile repeats `starts` times around, and the
   extrusion twists once per lead (pitch × starts).
   ===================================================================== */
function th_prof(t, rmin, d) =             // t in [0,1): trapezoid profile
    let(f = t - floor(t))
    f < 0.12 ? rmin :
    f < 0.42 ? rmin + d * (f - 0.12) / 0.30 :
    f < 0.58 ? rmin + d :
    f < 0.88 ? rmin + d * (0.88 - f) / 0.30 :
    rmin;

module thread_section(rmin, d, starts, n = 192) {
    polygon([for (i = [0 : n - 1])
        let(a = 360 * i / n, r = th_prof(starts * a / 360, rmin, d))
        [r * cos(a), r * sin(a)]]);
}

module thread_solid(rmin, d, len, pitch, starts = 1) {
    lead = pitch * starts;
    linear_extrude(height = len, twist = -360 * len / lead,
                   slices = ceil(len / lead * 72), convexity = 8)
        thread_section(rmin, d, starts);
}

/* ============================== BODY ================================= */
// The display puck. Flat bottom: it sits on the tube's flat top and is held
// by two M2x6 pan-head self-tapping screws driven down through its floor.
module body() {
    difference() {
        union() {
            // main shell (small chamfer at the bottom edge), stepped rim at the top
            hull() {
                translate([0, 0, 0.6]) cylinder(d = od, h = z_rim0 - 0.6);
                cylinder(d = od - 1.2, h = 0.6 + eps);
            }
            // chin: fills the curve between the puck's round front and the tube's
            // flat-backed collar, following the tube's round profile. Kept below
            // the bezel. (Inside the puck it's cut away with the cavity.)
            intersection() {
                translate([-r_t - 1, 0, 0]) cube([2*r_t + 2, y_col0 - chin_gap, z_rim0 - 0.3]);
                along_y(0, 0) cylinder(r = r_t, h = y_col0, $fn = 192);
            }
            // threaded rim for the bezel (lead-in chamfer at the top)
            translate([0, 0, z_rim0 - eps]) intersection() {
                thread_solid(rim_od/2 - bz_depth, bz_depth, rim_h + eps, bz_pitch, bz_starts);
                union() {
                    cylinder(d = rim_od + 1, h = rim_h - 0.8);
                    translate([0, 0, rim_h - 0.8 - eps]) cylinder(d1 = rim_od + 1, d2 = rim_od - 2*bz_depth - 0.6, h = 0.8 + 2*eps);
                }
            }
        }

        // screw holes to the tube, and the wire holes (sensor + battery leads)
        for (s = [-1, 1]) {
            translate([s * screw_x, 0, -eps]) cylinder(d = screw_hole, h = floor_t + 2*eps, $fn = 24);
            translate([s * 5, y_wire, -eps]) cylinder(d = wire_hole_d, h = floor_t + 2*eps, $fn = 32);
        }

        // ADS1115 + under-PCB component cavity
        translate([0, 0, z_cav0]) cylinder(d = cav_bore, h = z_pcb - z_cav0 + eps);

        // display seat: the round board and its USB-C tab, joined by a smooth
        // taper (the board's outline flares where the tab meets the circle).
        // It stays inside the rim thread's root, so the rim is unbroken.
        translate([0, 0, z_pcb - eps]) linear_extrude(body_h - z_pcb + 1) seat_2d();
        // channel for the on/off switch, which sticks out past the board edge
        rotate([0, 0, btn_angle]) translate([pcb_d/2 - 1, -sw_notch_w/2, z_pcb - btn_z_off - 1.5])
            cube([sw_protrude + disp_clear + 1.4, sw_notch_w, body_h - z_pcb + btn_z_off + 3]);

        // SH 1.0 plug: a slot down the display seat so the board drops in with
        // the cable plugged in, and a pocket in the cavity wall where its wires bend
        rotate([0, 0, sh_angle]) sh_plug_cut(body_h - z_pcb + 1);

        // USB-C slot (opening flares outward for the plug overmould)
        rotate([0, 0, usb_angle]) translate([od/2 - 4.5, usb_off, z_pcb - usb_h/2 - 0.2]) {
            rotate([0, 90, 0]) linear_extrude(5) offset(r = 0.8) offset(delta = -0.8)
                square([usb_h + 1.0, usb_w + 0.8], center = true);
            // recess for the plug's overmould (6.2 x 12.8), trimmed to stay below the bezel thread
            intersection() {
                translate([3.2, 0, 0]) rotate([0, 90, 0]) linear_extrude(3) offset(r = 1) offset(delta = -1)
                    square([usb_plug_h, usb_plug_w], center = true);
                translate([0, -20, -20]) cube([10, 40, z_rim0 - 0.15 - (z_pcb - usb_h/2 - 0.2) + 20]);
            }
        }

        // flexure power button: U-slot through the wall + thinned tab
        rotate([0, 0, btn_angle]) button_cut();

        // cover-glass pocket at the top; the ledge sits 0.15 below the glass, so
        // the board's pads carry it and the ledge only catches a press
        translate([0, 0, z_pcb + cover_under - 0.15]) cylinder(d = glass_pocket_d, h = body_h);
        translate([0, 0, body_h - 0.5]) cylinder(d1 = glass_pocket_d, d2 = glass_pocket_d + 1.0, h = 0.5 + eps);
    }

    // flexure button nub
    rotate([0, 0, btn_angle]) button_nub();

    // PCB support pads in the cavity: 3 mm wide, 1.2 mm under the board edge,
    // placed where the back of the board has no parts at its edge
    for (a = pad_angles)
        rotate([0, 0, a]) translate([pcb_d/2 - 1.2, -1.5, z_cav0])
            cube([cav_bore/2 - pcb_d/2 + 1.4, 3, z_pcb - z_cav0]);
}

/* ============================== TUBE ================================= */
// Under the puck, axis along +Y at z_ax. Round, with a flat top where the
// puck sits; a full-round collar in front of the puck carries the shoulder
// the cap seats on, then the male spigot. Inside, front to back: the bore
// for the sensor's rear boss, the plug space, then the battery pocket.
// Prints standing on the spigot (as exported), no supports.
module along_y(y0, len) { translate([0, y0, z_ax]) rotate([-90, 0, 0]) children(); }   // local z -> +Y

module tube() {
    difference() {
        union() {
            // lower body: round, flat on top (z = 0) where the puck sits
            intersection() {
                along_y(y_r, 0) hull() {
                    translate([0, 0, 1]) cylinder(r = r_t, h = y_f - y_r - 1);
                    cylinder(r = r_t - 1, h = 1);                      // chamfered rear edge
                }
                translate([-r_t - 1, y_r - 1, z_ax - r_t - 1]) cube([2*r_t + 2, y_f - y_r + 2, r_t + 1 - z_ax]);
            }
            // full-round collar in front of the puck (flat back face; the puck's
            // chin fills the curve behind it). Its top is trimmed flat, level with
            // the chin's top, to clear the bezel.
            intersection() {
                along_y(y_col0, 0) cylinder(r = r_t, h = y_f - y_col0);
                translate([-r_t - 1, y_col0 - 1, z_ax - r_t - 1]) cube([2*r_t + 2, y_f - y_col0 + 2, z_rim0 - 0.3 - (z_ax - r_t - 1)]);
            }
            // threaded spigot (male, 4-start) with a lead-in chamfer at the tip
            translate([0, y_f + th_len, z_ax]) rotate([90, 0, 0]) intersection() {
                thread_solid(th_major/2 - th_depth, th_depth, th_len + eps, th_pitch, th_starts);
                union() {
                    translate([0, 0, -0.05]) cylinder(d1 = th_major - 2*th_depth - 0.6, d2 = th_major + 0.6, h = 1.25);
                    translate([0, 0, 1.2 - eps]) cylinder(d = th_major + 1, h = th_len);
                }
            }
        }

        // plug space, running out through the spigot (the battery leaves this way)
        translate([-plug_box_w/2, y_pk1 - eps, z_ax - plug_box_h/2]) cube([plug_box_w, y_f + th_len - y_pk1 + 1, plug_box_h]);
        // bore for the sensor's rear boss; it rises above the tube's flat top, so
        // it starts collar_wall inside the collar and never breaks out of it
        along_y(y_bore0, 0) cylinder(d = boss_bore, h = y_f + th_len - y_bore0 + 1);
        // the spigot mouth opens out (45°) around the sensor's rear taper
        along_y(y_f + th_len - 4, 0) cylinder(d1 = boss_bore, d2 = th_major - 2*th_depth - 5.0, h = 4 + eps);
        translate([0, y_f + th_len - eps, z_ax]) rotate([-90, 0, 0]) cylinder(d = th_major - 2*th_depth - 5.0, h = 1);
        // battery pocket
        translate([-batt_w/2 - batt_clear, y_bk0, z_pk0])
            cube([batt_w + 2*batt_clear, batt_pk_l + eps, z_pk1 - z_pk0]);
        // wire holes up into the puck, screw pilot holes
        for (s = [-1, 1]) {
            translate([s * 5, y_wire, z_ax + plug_box_h/2 - eps]) cylinder(d = wire_hole_d, h = tube_top_wall + 2*eps, $fn = 32);
            if (use_inserts) {
                translate([s * screw_x, 0, -insert_depth]) cylinder(d = insert_hole_d, h = insert_depth + eps, $fn = 24);
                translate([s * screw_x, 0, -0.4]) cylinder(d1 = insert_hole_d, d2 = insert_hole_d + 0.8, h = 0.4 + eps, $fn = 24);
            } else
                translate([s * screw_x, 0, -7]) cylinder(d = screw_pilot, h = 7 + eps, $fn = 16);
        }
        // shoulder relief so the cap's last turn runs fully home
        translate([0, y_f - eps, z_ax]) rotate([-90, 0, 0]) difference() {
            cylinder(d = th_major + 2, h = 0.8 + eps);
            translate([0, 0, -eps]) cylinder(d = th_major - 2*th_depth, h = 1);
        }
    }
    // lip across the front of the battery pocket floor: lift the battery's
    // front end over it to slide the battery out
    translate([-batt_w/2 - batt_clear, y_pk1 - batt_lip, z_pk0 - eps])
        cube([batt_w + 2*batt_clear, batt_lip, batt_lip + eps]);
}

// annular sector between radii r0..r1, angles a0..a1 (deg), heights z0..z1
module sector(r0, r1, a0, a1, z0, z1) {
    translate([0, 0, z0]) rotate([0, 0, a0])
        rotate_extrude(angle = a1 - a0, $fn = 192) translate([r0, 0]) square([r1 - r0, z1 - z0]);
}

// display seat outline: board circle + tab, hulled so the junction flares
module seat_2d() {
    hull() { circle(d = disp_bore, $fn = 192); offset(r = tab_clear, $fn = 32) pcb_tab_2d(0); }   // rounded corners keep 0.6 mm of rim wall
}

// the PCB's tab, as a 2D outline grown by `off`
module pcb_tab_2d(off = 0) {
    rotate([0, 0, usb_angle - 270]) offset(delta = off)
        translate([-pcb_tab_w/2, -pcb_tab_r]) square([pcb_tab_w, pcb_tab_r]);
}

/* ---- SH 1.0 plug clearance ---- */
sh_r_slot = pcb_d/2 + sh_plug_out + 0.4;                // the plug's back, plus clearance
sh_r_bend = pcb_d/2 + sh_plug_out + sh_bend;            // wire bend pocket in the cavity wall
assert(sh_r_bend <= od/2 - 1.0, "SH plug pocket would leave the puck wall under 1 mm");

module sh_plug_cut(h_up) {
    // slot down the seat for the plug, from the board edge to just past the plug's back
    translate([pcb_d/2 - 1, -(sh_plug_w/2 + 0.4), z_pcb - eps]) cube([sh_r_slot - pcb_d/2 + 1, sh_plug_w + 0.8, h_up]);
    // pocket behind the plug, under the board, for the wires to turn down
    translate([cav_bore/2 - 1, -(sh_plug_w/2 + 1.0), z_pcb - sh_plug_h - 3]) cube([sh_r_bend - cav_bore/2 + 1, sh_plug_w + 2.0, sh_plug_h + 3 + eps]);
}

/* ---- flexure button ---- */
btn_tab_w   = 8.0;
btn_tab_z0  = z_pcb - btn_z_off - 5.5;   // hinge (bottom)
btn_tab_z1  = z_pcb - 0.2;               // free end, kept below the bezel rim
btn_slot    = 0.6;
btn_thin    = 0.8;                       // outer recess -> tab is 1.6 thick
btn_dome_d  = 6.4;                       // raised thumb dome on the tab
btn_dome_h  = 1.4;                       // from the recess floor (0.6 proud of the body)
btn_dome_z  = (btn_tab_z0 + btn_tab_z1) / 2 - 0.2;   // middle of the tab: levers the nub ~1.6x

module button_cut() {
    r_in = cav_bore/2;
    // U-shaped slot: two sides + top, hinge left at the bottom
    for (s = [-1, 1])
        translate([r_in - 1, s * (btn_tab_w/2 + btn_slot/2) - btn_slot/2, btn_tab_z0])
            cube([od/2 - r_in + 2, btn_slot, btn_tab_z1 - btn_tab_z0 + btn_slot]);
    translate([r_in - 1, -btn_tab_w/2 - btn_slot, btn_tab_z1])
        cube([od/2 - r_in + 2, btn_tab_w + 2*btn_slot, btn_slot]);
    // outer recess thins the tab and gives the thumb a locator
    translate([od/2 - btn_thin, -btn_tab_w/2 - btn_slot, btn_tab_z0 - 1.5])
        cube([2, btn_tab_w + 2*btn_slot, btn_tab_z1 - btn_tab_z0 + btn_slot + 1.5]);
}

module button_nub() {
    r_in = cav_bore/2;
    // thumb dome on the outside of the tab (sides under 45°, prints on the wall)
    r_fl = od/2 - btn_thin;
    R    = (pow(btn_dome_d/2, 2) + pow(btn_dome_h, 2)) / (2 * btn_dome_h);
    intersection() {
        translate([r_fl + btn_dome_h - R, 0, btn_dome_z]) sphere(r = R, $fn = 64);
        translate([r_fl - eps, -btn_dome_d, btn_dome_z - btn_dome_d]) cube([btn_dome_h + 1, 2*btn_dome_d, 2*btn_dome_d]);
    }
    zc = z_pcb - btn_z_off;
    // tapered pin from the tab's inner face to btn_reach, 45° underside
    hull() {
        translate([r_in + 0.1, 0, zc]) rotate([0, -90, 0]) cylinder(d = 3.0, h = eps, $fn = 24);
        translate([btn_reach, 0, zc]) rotate([0, -90, 0]) cylinder(d = 2.0, h = eps, $fn = 24);
        translate([r_in + 0.1, 0, zc - 1.6]) rotate([0, -90, 0]) cylinder(d = 0.6, h = eps, $fn = 12);
    }
}

/* ============================== BEZEL ================================ */
// Screws onto the threaded rim (3-start, about 3/4 turn) and seats on the
// rim's top face, just above the cover glass, so the glass and board can't
// lift. The window shows the flat part of the glass and hides its bevel.
// The skirt is 0.4 mm short of the body shoulder, so it's the rim top that
// it tightens against. It is wider (bz_od) than the 46 mm body below it.
module bezel() {
    skirt_h = rim_h - 0.4;
    difference() {
        cylinder(d = bz_od, h = skirt_h + bezel_plate);
        // female thread (the helix solid is filled to the centre, so it also clears the inside)
        translate([0, 0, -eps]) thread_solid(rim_od/2 - bz_depth + bz_clear, bz_depth, skirt_h + eps, bz_pitch, bz_starts);
        translate([0, 0, -eps]) cylinder(d1 = rim_od + 2*bz_clear + 0.8, d2 = rim_od - 2*bz_depth, h = 0.8);   // lead-in
        // display window with outward chamfer
        translate([0, 0, skirt_h - eps]) cylinder(d = view_d, h = bezel_plate + 2*eps);
        translate([0, 0, skirt_h + bezel_plate - 0.6]) cylinder(d1 = view_d, d2 = view_d + 1.2, h = 0.6 + eps);
        // grip flutes
        for (i = [0 : 23]) rotate([0, 0, i * 15])
            translate([bz_od/2 + 0.5, 0, -eps]) cylinder(d = 1.6, h = skirt_h + bezel_plate - 0.8, $fn = 12);
        // top outer edge chamfer
        translate([0, 0, skirt_h + bezel_plate - 0.6])
            difference() { cylinder(d = bz_od + 1, h = 1); cylinder(d1 = bz_od, d2 = bz_od - 1.2, h = 0.6 + eps); }
    }
}

/* =============================== CAP ================================= */
// Slim all the way: cap_wall around the sensor body and flange, then the
// thread band (the same diameter as the tube). Prints open end up; the
// taper is under 45° so it needs no supports.
module cap() {
    tot  = cap_h;
    r_fb = s_bore_flange/2;                  // flange bore radius
    r_lo = s_bore_body/2 + cap_wall;         // around the sensor body
    r_mi = r_fb + cap_wall;                  // around the flange
    z_t0 = tot - th_len - th_relief;         // thread band (full width) from here up
    z_c0 = z_t0 - (r_t - r_mi) * 1.2;        // taper start (~40° from vertical)
    difference() {
        rotate_extrude($fn = 128) polygon([
            [0, 0], [r_lo - 0.6, 0], [r_lo, 0.6],
            [r_lo, z_flange0 - (r_mi - r_lo) - 0.1], [r_mi, z_flange0 - 0.1],
            [r_mi, z_c0], [r_t, z_t0], [r_t, tot], [0, tot]]);
        // floor hole: the O-ring seals here
        translate([0, 0, -eps]) cylinder(d = oring_bore, h = z_sh + 2*eps);
        translate([0, 0, z_sh - 0.3]) cylinder(d1 = oring_bore, d2 = oring_bore + 0.6, h = 0.3 + eps);
        // sensor body bore, then the flange bore
        translate([0, 0, z_sh]) cylinder(d = s_bore_body, h = s_body_h + eps);
        translate([0, 0, z_flange0]) cylinder(d = 2*r_fb, h = z_t0 - z_flange0 + eps);
        // relief below the thread: room for the spigot tip so the cap seats on the shoulder
        translate([0, 0, z_t0 - eps]) cylinder(d = th_major + 2*th_clear + 0.4, h = th_relief + 2*eps);
        // ---- spigot thread (female, 4-start) ----
        translate([0, 0, tot - th_len])
            thread_solid(th_major/2 - th_depth + th_clear, th_depth, th_len + eps, th_pitch, th_starts);
        translate([0, 0, tot - 1.0]) cylinder(d1 = th_major - 2*th_depth + 2*th_clear - 0.6, d2 = th_major + 2*th_clear + 0.8, h = 1 + eps);

        // grip flutes on the thread band
        for (i = [0 : 17]) rotate([0, 0, i * 20])
            translate([r_t + 0.5, 0, z_t0 + 0.6]) cylinder(d = 2.0, h = tot - z_t0, $fn = 16);
    }
}

// horizontal hole with a 45° roof (prints without support when z is up)
module teardrop_x(d, len) {
    rotate([0, 90, 0]) linear_extrude(len) hull() {
        circle(d = d, $fn = 24);
        translate([-d * 0.707, 0]) square(0.01, center = true);
    }
}

/* ===================== FIT TEST (print first) ======================== */
// Display seat ring, sensor seat (cap floor + body bore), flange ring, and
// 4 mm of the tube/cap thread (male ring + female ring).
// Each piece is its own module (and PART), so they can be printed one at a time;
// fit_test() lays them all out together.
fit_pieces = ["seat", "sensor_seat", "flange_ring", "thread_male", "thread_female"];
fit_pos    = [[-4, 0, 0], [52, 0, 0], [88, 0, 0], [0, 50, 0], [42, 50, 0]];

module fit_piece(name) {
    if (name == "seat") difference() {           // display seat: drop the board in (tab, switch and
                                                  // SH plug into their notches), glass pocket on top
        cylinder(d = glass_pocket_d + 4, h = 3.5);
        translate([0, 0, 2]) cylinder(d = glass_pocket_d, h = 2);
        translate([0, 0, -eps]) linear_extrude(3) seat_2d();
        rotate([0, 0, btn_angle]) translate([pcb_d/2 - 1, -sw_notch_w/2, -eps]) cube([sw_protrude + disp_clear + 1.4, sw_notch_w, 3]);
        rotate([0, 0, sh_angle]) translate([pcb_d/2 - 1, -(sh_plug_w/2 + 0.4), -eps]) cube([sh_r_slot - pcb_d/2 + 1, sh_plug_w + 0.8, 3]);
    }
    // sensor seat: the cap floor (O-ring hole) with the body bore above it.
    // The sensor should sit on the floor with its O-ring snug in the hole,
    // and the diverter should screw on underneath and clamp it.
    if (name == "sensor_seat") difference() {
        cylinder(d = s_bore_body + 2*cap_wall, h = z_sh + 3);
        translate([0, 0, -eps]) cylinder(d = oring_bore, h = z_sh + 2*eps);
        translate([0, 0, z_sh - 0.3]) cylinder(d1 = oring_bore, d2 = oring_bore + 0.6, h = 0.3 + eps);
        translate([0, 0, z_sh]) cylinder(d = s_bore_body, h = 4);
    }
    // flange bore ring: the flange should drop through the female ring too
    if (name == "flange_ring") difference() {
        cylinder(d = s_bore_flange + 2*cap_wall, h = 2);
        translate([0, 0, -eps]) cylinder(d = s_bore_flange, h = 3);
    }
    // thread pair: male (as on the tube's spigot) and female (as in the cap)
    if (name == "thread_male") difference() {
        union() {
            intersection() {
                thread_solid(th_major/2 - th_depth, th_depth, 4, th_pitch, th_starts);
                union() {
                    translate([0, 0, -0.05]) cylinder(d1 = th_major - 2*th_depth - 0.6, d2 = th_major + 0.6, h = 1.25);
                    translate([0, 0, 1.2 - eps]) cylinder(d = th_major + 1, h = 4);
                }
            }
            translate([0, 0, 4 - eps]) cylinder(r = r_t, h = 1.5);      // shoulder
        }
        translate([0, 0, -eps]) cylinder(d = th_major - 2*th_depth - 4, h = 6);
    }
    if (name == "thread_female") difference() {
        cylinder(r = r_t, h = 4);
        translate([0, 0, -eps]) thread_solid(th_major/2 - th_depth + th_clear, th_depth, 4 + 2*eps, th_pitch, th_starts);
        translate([0, 0, 4 - 1.0]) cylinder(d1 = th_major - 2*th_depth + 2*th_clear - 0.6, d2 = th_major + 2*th_clear + 0.8, h = 1 + eps);
    }
}

module fit_test() {
    for (i = [0 : len(fit_pieces) - 1]) translate(fit_pos[i]) fit_piece(fit_pieces[i]);
}

/* ======================== Reference dummies ========================== */
module dummy_sensor() {   // z = 0 at the shoulder
    color("#333") {
        cylinder(d = s_body_d, h = s_body_h);
        translate([0, 0, s_body_h]) cylinder(d = s_flange_d, h = s_flange_h);
        translate([0, 0, s_body_h + s_flange_h]) cylinder(d1 = s_flange_d, d2 = s_boss_d, h = s_taper_h);
        translate([0, 0, sensor_h - s_boss_h - eps]) cylinder(d = s_boss_d, h = s_boss_h);
        translate([0, 0, -s_nose_h]) cylinder(d = s_thread_d, h = s_nose_h + eps);
    }
    color("black") translate([0, 0, -s_oring_cs/2 - 0.05]) rotate_extrude() translate([(s_oring_d - s_oring_cs)/2, 0]) circle(d = s_oring_cs, $fn = 16);
    color("white") translate([-4, -2.5, sensor_h]) cube([8, 5, 6]);       // mating plug
    color("red") for (x = [-2.5, 0, 2.5]) translate([x, 0, sensor_h + 6]) cylinder(d = 1.2, h = 3, $fn = 8);
}
module dummy_display() {
    color("darkgreen") linear_extrude(pcb_t) union() { circle(d = pcb_d); pcb_tab_2d(); }
    color("black") translate([0, 0, pcb_t]) cylinder(d = glass_d, h = cover_under - pcb_t);       // LCD module
    color("#202830") translate([0, 0, cover_under]) rotate_extrude() polygon([                  // cover glass
        [0, 0], [cover_d/2, 0], [cover_d/2, cover_edge_t],
        [cover_d/2 - cover_bevel_w, cover_t], [0, cover_t]]);
    color("royalblue") translate([0, 0, cover_under + cover_t - 0.05]) cylinder(d = 32.4, h = 0.1);
    color("gray") rotate([0, 0, usb_angle]) translate([pcb_tab_r - 7.3, usb_off - 4.5, -3.2]) cube([7.3, 9, 3.2]);
}

/* ============================ Output ================================= */
// cap frame -> assembly: cap z axis points back (-Y), its top on the shoulder
module at_cap(dy = 0) { translate([0, y_f + cap_h + dy, z_ax]) rotate([90, 0, 0]) children(); }

module assembly(explode = 0) {
    color("#3a6ea5") body();
    color("#4f86c0") translate([0, 0, -explode * 0.8]) tube();
    translate([0, 0, z_rim0 + explode * 1.2]) color("#2c2c2c") bezel();
    translate([0, 0, z_pcb + explode * 0.8]) dummy_display();
    color("purple") translate(ads_pos + [0, 0, explode * 0.4]) cube([ads_w, ads_l, 1.6]);
    color("orange") translate([-batt_w/2, y_bk0 + batt_clear - explode * 1.5, z_pk0 + 0.05 - explode * 0.8]) cube([batt_w, batt_l, batt_t]);
    translate([0, 0, -explode * 0.8]) at_cap(explode * 1.5) {
        color("#e0e0e0") cap();
        translate([0, 0, z_sh + explode * 0.8]) dummy_sensor();
        if (show_diverter)
            color("#1f9e8f") translate([0, 0, -div_len - explode * 1.0]) diverter();
    }
}

if (PART == "assembly")        assembly(0);
else if (PART == "exploded")   assembly(18);
else if (PART == "section")    difference() { assembly(0); translate([0, -80, -60]) cube([80, 200, 120]); }
else if (PART == "body")       body();
else if (PART == "tube")       translate([0, 0, y_f + th_len]) rotate([-90, 0, 0]) tube();   // spigot down
else if (PART == "bezel")      translate([0, 0, rim_h + bezel_plate]) rotate([180, 0, 0]) bezel();
else if (PART == "cap")        cap();
else if (PART == "fit_test")   fit_test();
else if (PART == "fit_piece")  fit_piece(FIT);     // one fit-test piece: -D 'FIT="seat"' (see fit_pieces)
