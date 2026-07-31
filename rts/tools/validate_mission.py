#!/usr/bin/env python3
"""Cross-check a mission's data against its level scene.

Godot will not complain about a wave that spawns at a marker nobody placed, or
an objective pointed at a sector id with a typo in it - the mission just
quietly does nothing at minute six. This checks every id reference in the
mission resource against the scene, and every polygon against the play area.

Usage:  python3 rts/tools/validate_mission.py [rts_dir]
Exit code is non-zero if anything failed.
"""
from __future__ import annotations

import os
import re
import sys

RE_SECTION = re.compile(r'^\[(\w+)([^\]]*)\]\s*$')
RE_ATTR = re.compile(r'(\w+)=(?:"([^"]*)"|([^\s\]]+))')
RE_SNAME = re.compile(r'&"([^"]*)"')
RE_VEC = re.compile(r'PackedVector2Array\(([^)]*)\)')
RE_EXT = re.compile(r'ExtResource\("([^"]+)"\)')


class Block:
    def __init__(self, kind: str, attrs: dict):
        self.kind = kind
        self.attrs = attrs
        self.props: dict[str, str] = {}

    def sname(self, key: str) -> str:
        """A StringName property, unquoted. '' when absent or empty."""
        raw = self.props.get(key, "")
        match = RE_SNAME.search(raw)
        return match.group(1) if match else ""

    def snames(self, key: str) -> list[str]:
        """Every StringName inside an array property."""
        return RE_SNAME.findall(self.props.get(key, ""))

    def ints(self, key: str) -> list[int]:
        raw = self.props.get(key, "")
        return [int(n) for n in re.findall(r'-?\d+', raw)]

    def num(self, key: str, default: float = 0.0) -> float:
        raw = self.props.get(key, "")
        match = re.match(r'\s*(-?[\d.]+(?:e-?\d+)?)\s*$', raw)
        return float(match.group(1)) if match else default

    def polygon(self) -> list[tuple[float, float]]:
        match = RE_VEC.search(self.props.get("polygon", ""))
        if not match:
            return []
        nums = [float(n) for n in match.group(1).split(",") if n.strip()]
        return list(zip(nums[0::2], nums[1::2]))


def parse(path: str) -> list[Block]:
    blocks: list[Block] = []
    current: Block | None = None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith(";"):
                continue
            section = RE_SECTION.match(line)
            if section:
                attrs = {k: (q or u) for k, q, u in RE_ATTR.findall(section.group(2))}
                current = Block(section.group(1), attrs)
                blocks.append(current)
                continue
            if current is not None and "=" in line:
                key, _, value = line.partition("=")
                current.props[key.strip()] = value.strip()
    return blocks


def point_in_polygon(point, polygon) -> bool:
    x, y = point
    inside = False
    count = len(polygon)
    for i in range(count):
        x1, y1 = polygon[i]
        x2, y2 = polygon[(i + 1) % count]
        if (y1 > y) != (y2 > y):
            cross = x1 + (y - y1) / (y2 - y1) * (x2 - x1)
            if x < cross:
                inside = not inside
    return inside


def rects_overlap(a, b) -> bool:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    return ax1 < bx2 and bx1 < ax2 and ay1 < by2 and by1 < ay2


def bounds(polygon):
    xs = [p[0] for p in polygon]
    ys = [p[1] for p in polygon]
    return min(xs), min(ys), max(xs), max(ys)


def main(root: str) -> int:
    scene_path = os.path.join(root, "missions/m04_athelney/m04_the_causeway_at_athelney.tscn")
    mission_path = os.path.join(root, "missions/m04_athelney/m04_mission.tres")
    errors: list[str] = []
    warnings: list[str] = []

    for path in (scene_path, mission_path):
        if not os.path.exists(path):
            print("missing: %s" % path)
            return 1

    scene = parse(scene_path)
    mission = parse(mission_path)

    # --- referenced files exist, load_steps are right ----------------------
    for path in (scene_path, mission_path):
        blocks = parse(path)
        head = blocks[0]
        declared = int(head.attrs.get("load_steps", 0))
        counted = sum(1 for b in blocks if b.kind in ("ext_resource", "sub_resource")) + 1
        if declared != counted:
            errors.append("%s: load_steps=%d but %d resources are declared"
                          % (os.path.basename(path), declared, counted))
        for block in blocks:
            if block.kind != "ext_resource":
                continue
            res = block.attrs.get("path", "")
            if res.startswith("res://"):
                target = os.path.join(root, res[len("res://"):])
                if not os.path.exists(target):
                    errors.append("%s: ext_resource path not found: %s"
                                  % (os.path.basename(path), res))

    # --- index the scene ---------------------------------------------------
    scene_nodes = [b for b in scene if b.kind == "node"]
    by_name = {b.attrs.get("name", ""): b for b in scene_nodes}
    polygons: dict[str, list] = {}
    for block in scene_nodes:
        if block.attrs.get("type") == "CollisionPolygon2D":
            parent = block.attrs.get("parent", "")
            polygons[parent.split("/")[-1]] = block.polygon()

    sectors, triggers, markers, cover_groups, terrain = {}, {}, {}, {}, {}
    for block in scene_nodes:
        script = RE_EXT.search(block.props.get("script", ""))
        script_id = script.group(1) if script else ""
        name = block.attrs.get("name", "")
        if script_id == "3_sector":
            sectors[block.sname("sector_id")] = (name, block)
        elif script_id == "5_trigger":
            triggers[block.sname("trigger_id")] = (name, block)
        elif script_id == "4_spawn":
            markers[block.sname("spawn_id")] = (name, block)
        elif script_id == "1_cover":
            tag = block.sname("group_tag")
            if tag:
                cover_groups.setdefault(tag, []).append((name, block))
        elif script_id == "2_terrain":
            terrain[name] = block

    # --- index the mission -------------------------------------------------
    squad_ids = set()
    for block in mission:
        if block.kind == "ext_resource" and "factions/" in block.attrs.get("path", ""):
            squad_ids.add(os.path.basename(block.attrs["path"]).replace(".tres", ""))

    subs = {b.attrs.get("id", ""): b for b in mission if b.kind == "sub_resource"}
    resource = next((b for b in mission if b.kind == "resource"), None)

    def sub_kind(block: Block) -> str:
        script = RE_EXT.search(block.props.get("script", ""))
        return {"2_act": "act", "3_obj": "objective", "4_wave": "wave",
                "5_event": "event"}.get(script.group(1) if script else "", "?")

    acts = [b for b in subs.values() if sub_kind(b) == "act"]
    objectives = [b for b in subs.values() if sub_kind(b) == "objective"]
    waves = [b for b in subs.values() if sub_kind(b) == "wave"]
    events = [b for b in subs.values() if sub_kind(b) == "event"]

    def check_sector(sid: str, where: str) -> None:
        if sid and sid not in sectors:
            errors.append("%s references unknown sector '%s'" % (where, sid))

    def check_marker(mid: str, where: str) -> None:
        if mid and mid not in markers:
            errors.append("%s references unknown spawn marker '%s'" % (where, mid))

    def check_trigger(tid: str, where: str) -> None:
        if tid and tid not in triggers:
            errors.append("%s references unknown trigger '%s'" % (where, tid))

    def check_squad(qid: str, where: str) -> None:
        if qid and qid not in squad_ids:
            errors.append("%s references unknown squad '%s'" % (where, qid))

    for objective in objectives:
        oid = objective.sname("objective_id")
        where = "objective '%s'" % oid
        check_sector(objective.sname("target_sector"), where)
        check_marker(objective.sname("target_marker"), where)
        check_squad(objective.sname("target_unit"), where)
        group = objective.sname("target_group")
        if group:
            members = cover_groups.get(group, [])
            if not members:
                errors.append("%s targets cover group '%s' with no members in the scene"
                              % (where, group))
            else:
                needed = int(objective.num("required_count", 1))
                if needed > len(members):
                    errors.append("%s needs %d of group '%s' but only %d exist"
                                  % (where, needed, group, len(members)))
                kind = int(objective.num("kind", 0))
                if kind == 6:  # DESTROY_OBJECTS
                    solid = [m for m in members if m[1].props.get("destructible") == "true"]
                    if len(solid) < needed:
                        errors.append("%s must destroy %d of '%s' but only %d are destructible"
                                      % (where, needed, group, len(solid)))

    for wave in waves:
        wid = wave.sname("wave_id")
        where = "wave '%s'" % wid
        for marker in wave.snames("spawn_markers"):
            check_marker(marker, where)
        for squad in wave.snames("squad_ids"):
            check_squad(squad, where)
        check_sector(wave.sname("order_sector"), where)
        check_sector(wave.sname("target_sector"), where)
        check_trigger(wave.sname("trigger_id"), where)
        ids = wave.snames("squad_ids")
        counts = wave.ints("squad_counts")
        if len(ids) != len(counts):
            errors.append("%s: %d squad_ids but %d squad_counts"
                          % (where, len(ids), len(counts)))
        if not wave.snames("spawn_markers"):
            errors.append("%s has no spawn markers" % where)

    event_ids = {e.sname("event_id") for e in events}
    for event in events:
        eid = event.sname("event_id")
        where = "event '%s'" % eid
        check_trigger(event.sname("trigger_id"), where)
        check_sector(event.sname("target_sector"), where)
        check_squad(event.sname("target_unit"), where)
        check_marker(event.sname("target_marker"), where)
        group = event.sname("cover_group")
        if group and group not in cover_groups:
            errors.append("%s burns cover group '%s' with no members" % (where, group))
        for chained in event.snames("chained_event_ids"):
            if chained not in event_ids:
                errors.append("%s chains to unknown event '%s'" % (where, chained))

    act_ids = set()
    for act in acts:
        aid = act.sname("act_id")
        act_ids.add(aid)
        where = "act '%s'" % aid
        for marker in act.snames("deploy_spawn_markers"):
            check_marker(marker, where)
            if marker in markers and not markers[marker][1].sname("squad_id"):
                errors.append("%s deploys '%s', which has no squad_id" % (where, marker))
        check_sector(act.sname("advance_sector"), where)
        check_trigger(act.sname("advance_trigger"), where)
        if act.num("reinforcement_interval") > 0:
            check_marker(act.sname("reinforcement_marker"), where)
            check_squad(act.sname("reinforcement_squad_id"), where)
            for sid in act.snames("reinforcement_sectors"):
                check_sector(sid, where)
        # The advance condition must be reachable.
        advance = int(act.num("advance", 0))
        if advance == 0:
            target = act.sname("advance_objective")
            owned = {objectives[i].sname("objective_id")
                     for i in range(len(objectives))}
            if target not in owned:
                errors.append("%s advances on unknown objective '%s'" % (where, target))
        elif advance == 2 and not act.sname("advance_sector"):
            errors.append("%s advances on SECTOR_HELD but names no sector" % where)

    # Triggers must be armed during an act that actually listens for them.
    for tid, (name, block) in triggers.items():
        allowed = block.snames("active_in_acts")
        for bad in [a for a in allowed if a not in act_ids]:
            errors.append("trigger '%s' is armed in unknown act '%s'" % (tid, bad))
        listeners = [e for e in events if e.sname("trigger_id") == tid]
        listeners += [w for w in waves if w.sname("trigger_id") == tid]
        if not listeners:
            warnings.append("trigger '%s' (%s) fires but nothing listens for it" % (tid, name))

    if resource is not None:
        for sid in resource.snames("critical_sectors"):
            check_sector(sid, "mission.critical_sectors")
        for qid in resource.snames("protected_units"):
            check_squad(qid, "mission.protected_units")
        scene_ref = resource.props.get("level_scene", "").strip('"')
        if scene_ref.startswith("res://"):
            if not os.path.exists(os.path.join(root, scene_ref[len("res://"):])):
                errors.append("mission.level_scene does not exist: %s" % scene_ref)

    # --- geometry ----------------------------------------------------------
    play = (0.0, 0.0, 2400.0, 1800.0)
    if resource is not None:
        inner = re.search(r'Rect2\(([^)]*)\)', resource.props.get("play_area", ""))
        nums = re.findall(r'-?[\d.]+', inner.group(1)) if inner else []
        if len(nums) == 4:
            x, y, w, h = (float(n) for n in nums)
            play = (x, y, x + w, y + h)

    for name, poly in polygons.items():
        if not poly:
            errors.append("node '%s' has an empty collision polygon" % name)
            continue
        if len(poly) < 3:
            errors.append("node '%s' has a degenerate polygon (%d points)" % (name, len(poly)))
        x1, y1, x2, y2 = bounds(poly)
        if x1 < play[0] or y1 < play[1] or x2 > play[2] or y2 > play[3]:
            warnings.append("node '%s' extends outside the play area" % name)

    # Sectors are capture volumes; overlapping ones double-count occupants.
    sector_boxes = [(name, bounds(polygons[name])) for _, (name, _b) in sectors.items()
                    if name in polygons]
    for i in range(len(sector_boxes)):
        for j in range(i + 1, len(sector_boxes)):
            if rects_overlap(sector_boxes[i][1], sector_boxes[j][1]):
                errors.append("sector volumes overlap: %s and %s"
                              % (sector_boxes[i][0], sector_boxes[j][0]))

    # A spawn inside impassable ground strands whatever arrives there.
    impassable = {name: polygons[name] for name, block in terrain.items()
                  if block.props.get("passable_on_foot") == "false" and name in polygons}
    for mid, (name, block) in markers.items():
        inner = re.search(r'Vector2\(([^)]*)\)', block.props.get("position", ""))
        nums = re.findall(r'-?[\d.]+', inner.group(1)) if inner else []
        if len(nums) != 2:
            errors.append("spawn '%s' has no position" % mid)
            continue
        point = (float(nums[0]), float(nums[1]))
        if not (play[0] <= point[0] <= play[2] and play[1] <= point[1] <= play[3]):
            errors.append("spawn '%s' is outside the play area" % mid)
        for tname, poly in impassable.items():
            if point_in_polygon(point, poly):
                errors.append("spawn '%s' sits inside impassable terrain '%s'" % (mid, tname))

    # Every sector should be reachable-ish: warn if it has no spawn aimed at it.
    aimed = {w.sname("order_sector") for w in waves}
    aimed |= {b.sname("default_order_target") for _n, b in markers.values()}
    for sid in sectors:
        if sid not in aimed:
            warnings.append("sector '%s' is never a wave or spawn order target" % sid)

    # --- report ------------------------------------------------------------
    for warning in warnings:
        print("WARN  %s" % warning)
    for error in errors:
        print("FAIL  %s" % error)
    print("\n%d cover volumes, %d terrain regions, %d sectors, %d triggers, %d spawns"
          % (len(polygons) - len(sectors) - len(triggers) - len(terrain),
             len(terrain), len(sectors), len(triggers), len(markers)))
    print("%d acts, %d objectives, %d waves, %d events, %d squads"
          % (len(acts), len(objectives), len(waves), len(events), len(squad_ids)))
    print("%d error(s), %d warning(s)" % (len(errors), len(warnings)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
        os.path.dirname(os.path.abspath(__file__)))))
