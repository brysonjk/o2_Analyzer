"""
Compact O2 Analyzer - CadQuery (OpenCASCADE B-rep) version of o2_analyzer.scad
and diverter.scad, for STEP export into Fusion 360, SolidWorks, Onshape, etc.

    python3 cad/o2_analyzer_cq.py            # writes step/*.step

Every parameter mirrors the OpenSCAD source; keep the two in sync. Parts are
exported in their natural (assembled) orientation, each at its own origin:
  body          z = 0 at the spigot end
  bezel         z = 0 at the skirt's lower edge
  cap_open      z = 0 at the cap floor (sensor nose side)
  cap_diverter  z = 0 at the nose face
  diverter      z = 0 at the nose face
plus o2_analyzer_assembly.step with everything in place (open cap + diverter),
including simple stand-ins for the bought parts.

Threads are fully modelled (helical sweeps), right-handed like the SCAD ones,
so a printed CadQuery cap mates a printed SCAD body.
"""
import math
import os
import sys
import cadquery as cq
from cadquery import Vector, Solid, Location

# ======================= parameters (from o2_analyzer.scad) =======================
pcb_d, glass_d, glass_stack, pcb_t, comp_h, view_d = 38.5, 36.6, 3.6, 1.0, 3.8, 33.0
usb_angle, usb_w, usb_h = 270, 9.6, 3.8
btn_angle, btn_z_off, btn_reach = 0, 1.6, 19.8

s_flange_d, s_flange_h = 29.3, 6.8
s_body_d, s_body_h = 25.6, 13.1
s_taper_h, s_boss_d, s_boss_h = 3.1, 14.7, 3.9
s_oring_d, s_neck_h, s_thread_d, s_thread_h = 19.9, 5.2, 16.0, 8.3
plug_clear, sensor_extra = 11.0, 0.5
sensor_h = s_body_h + s_flange_h + s_taper_h + s_boss_h
nose_len = s_neck_h + s_thread_h

batt_t, batt_w, batt_l = 6.0, 20.0, 30.0
ads_l, ads_w, ads_zone = 28.6, 18.4, 3.8

od, fit, bezel_plate, rim_h, rim_wall = 46.0, 0.30, 1.2, 3.8, 1.2
bay_n, bay_lug_w, bay_lug_h, bay_lug_z = 3, 14, 1.2, 0.6
bay_lug_depth, bay_depth, bay_twist, bay_lock = 0.7, 0.55, 30, 0.05

th_pitch, th_starts, th_depth, th_len = 2.0, 4, 0.9, 7.0
th_major, th_clear, th_relief, spigot_id = 42.4, 0.40, 1.5, 37.0

inlet_d, vent_d, vent_n = 1.6, 2.2, 6
face_d, cone_d, cone_h, nose_face_h = 18.0, 25.0, 4.0, 1.6
chamber_d, chamber_h, nose_od = 15.0, 2.0, 26.0
oring_bore = s_oring_d - 0.5

hook_n, hook_w, hook_t, hook_overlap, hook_preload = 3, 5.0, 1.4, 0.75, 0.4

latch_t, latch_w, latch_hook, latch_z0 = 1.0, 6.0, 1.0, 0.8
latch_x = batt_l / 2 + 0.5

btn_tab_w, btn_slot, btn_thin = 6.0, 0.6, 0.8

eps = 0.01
TOL = 1e-3          # fuzzy boolean tolerance (needed for clean helical-sweep booleans)

# body heights
z_batt0 = th_len
batt_zone = batt_t + 0.6
z_floor = z_batt0 + batt_zone
floor_t = 1.0
z_cav0 = z_floor + floor_t
z_pcb = z_cav0 + ads_zone + comp_h
z_glass = z_pcb + pcb_t + glass_stack
body_h = z_glass
z_rim0 = body_h - rim_h
disp_bore = pcb_d + 2 * fit + 0.4
cav_bore = od - 2 * 2.4
rim_od = od - 2 * rim_wall - 2 * fit
btn_tab_z0 = z_pcb - btn_z_off - 5.5
btn_tab_z1 = z_pcb - 0.2

# cap heights (built-in diverter style; the open style overrides z_sh)
z_ch0 = nose_face_h + cone_h
z_sface = z_ch0 + chamber_h
cap_floor = 1.6
cav_above = max(1.0, plug_clear - th_len)

# diverter.scad
d_od, d_th_clear, d_th_depth, d_chamber_h, d_vent_d = 26.0, 0.20, 0.60, 2.6, 2.4
d_exposed_neck = s_neck_h - cap_floor
d_z_ch0 = nose_face_h + cone_h
d_z_th0 = d_z_ch0 + d_chamber_h
d_z_th1 = d_z_th0 + s_thread_h + 0.6
d_z_top = d_z_th1 + d_exposed_neck - 0.3


# ================================ helpers ================================
def U(a, *b):
    return a.fuse(*b, tol=TOL).clean()


def C(a, *b):
    return a.cut(*b, tol=TOL).clean()


def I(a, b):
    return a.intersect(b, tol=TOL).clean()


def rz(s, deg):
    return s.rotate(Vector(0, 0, 0), Vector(0, 0, 1), deg)


def cyl(d, h, z=0.0, x=0.0, y=0.0):
    return Solid.makeCylinder(d / 2, h, Vector(x, y, z))


def cone(d1, d2, h, z=0.0):
    return Solid.makeCone(d1 / 2, d2 / 2, h, Vector(0, 0, z))


def box(x0, y0, z0, dx, dy, dz):
    return Solid.makeBox(dx, dy, dz, Vector(x0, y0, z0))


def sector(r0, r1, a0, a1, z0, z1):
    """Annular sector r0..r1, angles a0..a1 (deg, CCW from +X), heights z0..z1."""
    ang = a1 - a0
    outer = Solid.makeCylinder(r1, z1 - z0, Vector(0, 0, z0), Vector(0, 0, 1), ang)
    inner = Solid.makeCylinder(r0, z1 - z0 + 2 * eps, Vector(0, 0, z0 - eps), Vector(0, 0, 1), ang + 2)
    inner = rz(inner, -1)
    return rz(C(outer, inner), a0)


def revolve_rz(pts):
    """Revolve a closed (r, z) polygon 360° about Z."""
    return cq.Workplane("XZ").polyline(pts).close().revolve(360, (0, 0, 0), (0, 1, 0)).val()


def prism_xz(pts, y0, y1):
    """Extrude a closed (x, z) polygon from y = y0 to y = y1."""
    w = cq.Workplane("XZ", origin=(0, y1, 0)).polyline(pts).close().extrude(y1 - y0).val()
    return w


def ring_chamfer_top(d, z, size):
    """Material to cut for a 45° outer chamfer at the top edge (z) of a cylinder of dia d."""
    return C(cyl(d + 2, size + eps, z - size), cone(d, d - 2 * size, size + eps, z - size))


def ring_chamfer_bottom(d, z, size):
    return C(cyl(d + 2, size + eps, z - eps), cone(d - 2 * size, d, size + eps, z - eps))


def teardrop_x(d, x0, x1, z, rot):
    """Horizontal hole along +X (x0..x1) at height z with a 45° roof, rotated about Z."""
    r = d / 2
    c = Solid.makeCylinder(r, x1 - x0, Vector(x0, 0, z), Vector(1, 0, 0))
    roof = box(x0, -r / 2, -r / 2, x1 - x0, r, r)
    roof = roof.rotate(Vector(x0, 0, 0), Vector(1, 0, 0), 45).translate(Vector(0, 0, z + r * 0.7071))
    return rz(U(c, roof), rot)


def rounded_slot_x(x0, length, w_y, h_z, r, z, rot):
    s = (cq.Workplane("YZ", origin=(x0, 0, z)).rect(w_y, h_z).extrude(length)
         .edges("|X").fillet(r).val())
    return rz(s, rot)


def helix_ridges(r_root, depth, pitch, starts, z0, length, outward=True, overlap=0.15):
    """Trapezoidal helical ridges (right-hand), profile matching the SCAD th_prof:
    base 0.76 p, crest 0.16 p, height `depth`. Built a pitch past both ends;
    the caller trims them."""
    lead = pitch * starts
    b, c = 0.76 * pitch / 2, 0.16 * pitch / 2
    if outward:
        pts = [(r_root - overlap, -b), (r_root, -b), (r_root + depth, -c),
               (r_root + depth, c), (r_root, b), (r_root - overlap, b)]
    else:
        pts = [(r_root + overlap, -b), (r_root, -b), (r_root - depth, -c),
               (r_root - depth, c), (r_root, b), (r_root + overlap, b)]
    h = length + 2 * pitch + lead
    helix = cq.Wire.makeHelix(pitch=lead, height=h, radius=r_root)
    prof = cq.Workplane("XZ").polyline(pts).close().wire().val()
    one = Solid.sweep(prof, [], helix, isFrenet=True)
    out = one
    for k in range(1, starts):
        out = U(out, rz(one, 360 * k / starts))
    return out.translate(Vector(0, 0, z0 - pitch - lead / 2))


def male_thread(r_root, depth, pitch, starts, z0, length):
    core = cyl(2 * r_root, length, z0)
    return U(core, helix_ridges(r_root, depth, pitch, starts, z0, length))


def female_cut(r_root, depth, pitch, starts, z0, length, clear):
    """Volume to remove for a female thread that mates male_thread(r_root, ...)."""
    rr = r_root + clear
    v = U(cyl(2 * rr, length, z0), helix_ridges(rr, depth, pitch, starts, z0, length))
    return I(v, cyl(2 * (rr + depth + 1), length, z0))


# ================================= BODY ==================================
def bayonet_slot():
    r_in, r_out = rim_od / 2 - bay_depth, rim_od / 2 + 1
    lug0 = z_rim0 + bay_lug_z
    zg0 = lug0 - 0.15
    ztop0 = lug0 + bay_lug_h + 0.15
    ztop1 = lug0 + bay_lug_h - bay_lock
    aE = bay_lug_w / 2 + 2
    aEnd = -(bay_twist + bay_lug_w / 2 + 1)
    s = sector(r_in, r_out, -aE, aE, zg0, body_h + 1)
    N = 10
    for i in range(N):
        a1 = aE - (aE - aEnd) * i / N
        a0 = aE - (aE - aEnd) * (i + 1) / N
        s = U(s, sector(r_in, r_out, a0 - 0.01, a1 + 0.01, zg0, ztop0 - (ztop0 - ztop1) * i / (N - 1)))
    return s


def battery_latch():
    r_wall = spigot_id / 2
    root = box(latch_x, -latch_w / 2, latch_z0,
               math.sqrt(r_wall ** 2 - (latch_w / 2) ** 2) - latch_x + 0.6, latch_w, 1.5)
    beam = box(latch_x, -latch_w / 2, latch_z0, latch_t, latch_w, z_batt0 + 0.6 - latch_z0)
    hook = prism_xz([(latch_x, z_batt0 - 1.8), (latch_x - latch_hook, z_batt0 - 0.8),
                     (latch_x - latch_hook, z_batt0), (latch_x, z_batt0 + 0.6)],
                    -latch_w / 2, latch_w / 2)
    return U(root, beam, hook)


def button_cut():
    r_in = cav_bore / 2
    parts = []
    for s in (-1, 1):
        parts.append(box(r_in - 1, s * (btn_tab_w / 2 + btn_slot / 2) - btn_slot / 2, btn_tab_z0,
                         od / 2 - r_in + 2, btn_slot, btn_tab_z1 - btn_tab_z0 + btn_slot))
    parts.append(box(r_in - 1, -btn_tab_w / 2 - btn_slot, btn_tab_z1,
                     od / 2 - r_in + 2, btn_tab_w + 2 * btn_slot, btn_slot))
    parts.append(box(od / 2 - btn_thin, -btn_tab_w / 2 - btn_slot, btn_tab_z0 - 1.5,
                     2, btn_tab_w + 2 * btn_slot, btn_tab_z1 - btn_tab_z0 + btn_slot + 1.5))
    return rz(U(*parts), btn_angle)


def button_nub():
    r_in = cav_bore / 2
    zc = z_pcb - btn_z_off
    tip = Solid.makeCone(1.5, 1.0, r_in + 0.1 - btn_reach, Vector(r_in + 0.1, 0, zc), Vector(-1, 0, 0))
    web = prism_xz([(r_in + 0.1, zc - 1.6), (r_in + 0.1, zc), (btn_reach + 0.3, zc)], -0.8, 0.8)
    return rz(U(tip, web), btn_angle)


def body():
    r_root = th_major / 2 - th_depth
    b = U(cyl(od, z_rim0 - th_len, th_len), cyl(rim_od, rim_h + eps, z_rim0 - eps))
    male = male_thread(r_root, th_depth, th_pitch, th_starts, 0, th_len + eps)
    clip = U(cone(th_major - 2 * th_depth - 1.0, th_major + 0.6, 2.05, -0.05),
             cyl(th_major + 1, th_len, 2.0 - eps))
    b = U(b, I(male, clip))

    cuts = [
        cyl(spigot_id, th_len + 2 * eps, -eps),
        box(-batt_l / 2 - 0.4, -batt_w / 2 - 0.4, z_batt0 - eps, batt_l + 0.8, batt_w + 0.8, batt_zone + eps),
        box(-9, batt_w / 2, z_batt0 - eps, 18, 6.0, batt_zone + eps),
        cq.Workplane().center(0, -batt_w / 2 - 0.4).ellipse(7, 7 * 0.45)
          .extrude(batt_zone * 0.6).val().translate(Vector(0, 0, z_batt0 - eps)),
        cyl(4.2, floor_t + 2, z_floor - 1, 6, batt_w / 2 + 3),
        cyl(4.2, floor_t + 2, z_floor - 1, -6, batt_w / 2 + 3),
        cyl(cav_bore, z_pcb - z_cav0 + eps, z_cav0),
        box(-ads_l / 2, -ads_w / 2 - 3, z_cav0 - 0.6, ads_l, ads_w, 1),
        cyl(disp_bore, body_h, z_pcb),
        rounded_slot_x(od / 2 - 3.5, 4, usb_w + 0.6, usb_h + 0.6, 1.19, z_pcb - usb_h / 2 - 0.2, usb_angle),
        rounded_slot_x(od / 2 - 3.5 + 2.2, 3, usb_w + 3.4 + 4, usb_h + 3 + 4, 1.99, z_pcb - usb_h / 2 - 0.2, usb_angle),
        button_cut(),
        # thread relief at the shoulder
        C(cyl(th_major + 2, 0.78, th_len - 0.8), cyl(th_major - 2 * th_depth + 0.1, 1, th_len - 0.8 - eps)),
        # top chamfer on the rim's inner edge
        cone(disp_bore, disp_bore + 1.6, 0.8 + eps, body_h - 0.8),
    ]
    for k in range(bay_n):
        cuts.append(rz(bayonet_slot(), k * 360 / bay_n))
    b = C(b, *cuts)

    adds = [button_nub()]
    for a in (usb_angle + 120, usb_angle + 240, usb_angle + 60):
        if abs(((a - btn_angle + 540) % 360) - 180) > 20:
            adds.append(rz(box(cav_bore / 2 - 2.4, -2, z_cav0, 2.6, 4, z_pcb - z_cav0), a))
    latch = battery_latch()
    adds += [latch, latch.mirror("YZ")]
    return U(b, *adds)


# ================================= BEZEL =================================
def bezel():
    skirt_h, skirt_id = rim_h, od - 2 * rim_wall
    b = cyl(od, skirt_h + bezel_plate)
    cuts = [
        cyl(skirt_id, skirt_h + eps, -eps),
        cyl(view_d, bezel_plate + 2 * eps, skirt_h - eps),
        cone(view_d, view_d + 1.6, 0.8 + eps, skirt_h + bezel_plate - 0.8),
        cyl(glass_d + 0.5, 0.4 + eps, skirt_h - eps),
        ring_chamfer_top(od, skirt_h + bezel_plate, 0.6),
    ]
    for k in range(bay_n):
        n = box(-0.6, -0.6, -0.5 - eps, 1.2, 1.2, 1.0)
        cuts.append(rz(rz(n, 45).translate(Vector(od / 2, 0, 0)), k * 360 / bay_n))
    b = C(b, *cuts)
    lugs = [rz(sector(skirt_id / 2 - bay_lug_depth, skirt_id / 2 + 0.2, -bay_lug_w / 2, bay_lug_w / 2,
                      bay_lug_z, bay_lug_z + bay_lug_h), k * 360 / bay_n) for k in range(bay_n)]
    return U(b, *lugs)


# ================================== CAP ==================================
def cap(style):
    z_sh = z_sface + nose_len if style == "diverter" else cap_floor
    z_flange0 = z_sh + s_body_h
    z_flange1 = z_flange0 + s_flange_h
    tot = z_sh + sensor_h + cav_above + th_len
    r_fb = s_flange_d / 2 + fit + sensor_extra

    if style == "diverter":
        sh = U(cyl(nose_od, z_sh - 4 + eps),
               cone(nose_od, od, (od - nose_od) / 2, z_sh - 4),
               cyl(od, tot - (z_sh - 4 + (od - nose_od) / 2) + eps, z_sh - 4 + (od - nose_od) / 2 - eps),
               cone(face_d, cone_d, cone_h + eps, nose_face_h),
               cyl(face_d, nose_face_h + eps))
        trim = C(cyl(nose_od + 2, z_ch0, -eps),
                 cone(face_d, cone_d, cone_h + 2 * eps, nose_face_h - eps),
                 cyl(face_d, nose_face_h + 2 * eps, -eps))
        cuts = [trim,
                cyl(inlet_d, z_ch0 + 2 * eps, -eps),
                cone(4.0, inlet_d, 1.2, -eps),
                cyl(chamber_d, chamber_h + eps, z_ch0),
                cyl(s_thread_d + 1.4, z_sh - z_ch0 - 0.8 + eps, z_ch0 + 0.8),
                cyl(oring_bore, 4.6 + eps, z_sh - 4.6),
                cone(oring_bore, oring_bore + 1.2, 0.6 + eps, z_sh - 0.6)]
        for i in range(vent_n):
            cuts.append(teardrop_x(vent_d, chamber_d / 2 - 1.5, nose_od / 2 + 1, z_ch0 + chamber_h / 2,
                                   i * 360 / vent_n + 30))
        sh = C(sh, *cuts)
        z_fl = z_sh + 6
    else:
        sh = C(cyl(od, tot), cyl(s_oring_d + 1.0, cap_floor + 2 * eps, -eps),
               ring_chamfer_bottom(od, 0, 0.8))
        z_fl = 2

    r_root = th_major / 2 - th_depth
    cuts = [
        cyl(s_body_d + 2 * (fit + sensor_extra), s_body_h + eps, z_sh),
        cone(s_body_d + 2 * (fit + sensor_extra), 2 * r_fb, 0.6 + eps, z_flange0 - 0.6),
        cyl(2 * r_fb, sensor_h - s_body_h + eps, z_flange0),
        cyl(th_major - 2 * th_depth + 2 * th_clear - 0.2, cav_above + 2 * eps, z_sh + sensor_h - eps),
        female_cut(r_root, th_depth, th_pitch, th_starts, tot - th_len, th_len + eps, th_clear),
        cone(th_major - 2 * th_depth + 2 * th_clear - 0.6, th_major + 2 * th_clear + 0.8, 1 + eps, tot - 1.0),
        cyl(th_major + 2 * th_clear + 0.4, th_relief + eps, tot - th_len - th_relief),
    ]
    for i in range(hook_n):
        cuts.append(rz(box(s_body_d / 2, -hook_w / 2 - 0.8, z_flange0 - 4,
                           r_fb + hook_t + 1.2 - s_body_d / 2, hook_w + 1.6,
                           z_flange1 - hook_preload + 2.8 - (z_flange0 - 4)), i * 360 / hook_n))
    for i in range(18):
        cuts.append(rz(cyl(2.4, tot - th_len - z_fl - 1, z_fl, od / 2 + 0.6, 0), i * 20))
    c = C(sh, *cuts)

    # snap hooks
    z_root = z_flange0 - 4
    zc = z_flange1 - hook_preload
    r_tip = s_flange_d / 2 - hook_overlap
    beam = box(r_fb, -hook_w / 2, z_root - eps, hook_t, hook_w, zc + 2.2 - z_root)
    catch = prism_xz([(r_fb + eps, zc - (r_fb - s_flange_d / 2)),
                      (r_tip, zc + (s_flange_d / 2 - r_tip)),
                      (r_tip, zc + (s_flange_d / 2 - r_tip) + 0.4),
                      (r_fb + eps, zc + (s_flange_d / 2 - r_tip) + 0.4 + (r_fb - r_tip))],
                     -hook_w / 2, hook_w / 2)
    hook = U(beam, catch)
    return U(c, *[rz(hook, i * 360 / hook_n) for i in range(hook_n)])


# ======================= SCREW-ON DIVERTER (diverter.scad) =======================
def diverter():
    d = U(cyl(d_od, d_z_top - d_z_ch0, d_z_ch0),
          cone(face_d, cone_d, cone_h + eps, nose_face_h),
          cyl(face_d, nose_face_h + eps))
    r_root = s_thread_d / 2 - d_th_depth
    cuts = [
        cyl(inlet_d, d_z_ch0 + 2 * eps, -eps),
        cone(4.0, inlet_d, 1.2, -eps),
        cyl(chamber_d, d_chamber_h + eps, d_z_ch0),
        female_cut(r_root, d_th_depth, 1.0, 1, d_z_th0, d_z_th1 - d_z_th0, d_th_clear),
        cyl(oring_bore, d_z_top - d_z_th1 + 2 * eps, d_z_th1 - eps),
        cone(oring_bore, oring_bore + 2.0, 1.0 + eps, d_z_top - 1.0),
    ]
    for i in range(vent_n):
        cuts.append(teardrop_x(d_vent_d, chamber_d / 2 - 1.5, d_od / 2 + 1, d_z_ch0 + d_chamber_h / 2,
                               i * 360 / vent_n + 30))
    for i in range(12):
        cuts.append(rz(cyl(2.2, d_z_top, d_z_th0 + 2.0, d_od / 2 + 0.5, 0), i * 30 + 15))
    return C(d, *cuts)


# ============================ reference stand-ins ============================
def dummy_sensor():
    s = U(cyl(s_body_d, s_body_h), cyl(s_flange_d, s_flange_h, s_body_h),
          cone(s_flange_d, s_boss_d, s_taper_h, s_body_h + s_flange_h),
          cyl(s_boss_d, s_boss_h, sensor_h - s_boss_h - eps),
          cyl(17.3, s_neck_h, -s_neck_h), cyl(s_thread_d, s_thread_h, -s_thread_h - s_neck_h))
    return s


def dummy_display():
    return U(cyl(pcb_d, pcb_t), cyl(glass_d, glass_stack, pcb_t))


# ================================= export =================================
def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    parts = {
        "body": body,
        "bezel": bezel,
        "cap_open": lambda: cap("open"),
        "cap_diverter": lambda: cap("diverter"),
        "diverter": diverter,
    }
    only = sys.argv[1:]
    built = {}
    for name, fn in parts.items():
        if only and name not in only:
            continue
        s = fn()
        built[name] = s
        cq.exporters.export(cq.Workplane().add(s), os.path.join(out_dir, f"{name}.step"))
        bb = s.BoundingBox()
        print(f"{name:13s} valid={s.isValid()}  solids={len(s.Solids())}  volume={s.Volume():9.1f} mm3  "
              f"bbox=({bb.xlen:.1f} x {bb.ylen:.1f} x {bb.zlen:.1f})", flush=True)

    if not only:
        cap_h_open = cap_floor + sensor_h + cav_above + th_len
        z_cap = th_len - cap_h_open
        a = cq.Assembly(name="o2_analyzer")
        a.add(built["body"], name="body", color=cq.Color(0.25, 0.44, 0.63))
        a.add(built["bezel"], name="bezel", loc=Location(Vector(0, 0, z_rim0)), color=cq.Color(0.17, 0.19, 0.21))
        a.add(built["cap_open"], name="cap_open", loc=Location(Vector(0, 0, z_cap)), color=cq.Color(0.85, 0.87, 0.88))
        a.add(built["diverter"], name="diverter", loc=Location(Vector(0, 0, z_cap - 0.3 - d_z_top)),
              color=cq.Color(0.12, 0.62, 0.56))
        a.add(dummy_sensor(), name="ref_sensor_R22D", loc=Location(Vector(0, 0, z_cap + cap_floor)),
              color=cq.Color(0.14, 0.15, 0.17))
        a.add(dummy_display(), name="ref_display", loc=Location(Vector(0, 0, z_pcb)), color=cq.Color(0.11, 0.25, 0.48))
        a.add(box(-ads_l / 2, -ads_w / 2 - 3, z_cav0, ads_l, ads_w, 1.6), name="ref_ADS1115",
              color=cq.Color(0.42, 0.24, 0.60))
        a.add(box(-batt_l / 2, -batt_w / 2, z_batt0 + 0.3, batt_l, batt_w, batt_t), name="ref_LiPo_602030",
              color=cq.Color(0.79, 0.80, 0.82))
        a.export(os.path.join(out_dir, "o2_analyzer_assembly.step"))
        print("assembly written", flush=True)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    main(os.path.join(here, "..", "step"))
