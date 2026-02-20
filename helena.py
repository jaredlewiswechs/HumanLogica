"""
Helena v1.0 — An Operating System for Humans
=============================================
Author: Jared Lewis
Date: February 19, 2026

Helena sits on Mary. She manages worlds, files, identity,
inspection, and the interface layer. She follows the same rules
as every other speaker.

Helena does not override Mary. Helena cannot override Mary.
"""

import time
import hashlib
import json
from typing import Any, Optional
from dataclasses import dataclass, field
from mary import Mary, Status, Version, SpeakerStatus, Position


# =============================================================================
# Part I — World
# =============================================================================

@dataclass
class WorldPermissions:
    """What a member can do in a world."""
    read: bool = True
    write: bool = True
    submit: bool = True
    request: bool = True
    invite: bool = False
    configure: bool = False


class WorldStatus:
    OPEN = "open"
    CLOSED = "closed"
    ARCHIVED = "archived"


@dataclass
class WorldMember:
    """A speaker's membership in a world."""
    speaker_id: int
    permissions: WorldPermissions
    joined_at: float
    role: str = "member"  # creator, member, observer


@dataclass
class World:
    """An isolated environment where speakers create, compute, interact."""
    world_id: str
    name: str
    creator_id: int
    created_at: float
    status: str = WorldStatus.OPEN
    members: dict = field(default_factory=dict)  # speaker_id -> WorldMember
    namespace: str = ""  # prefix for variables

    def is_member(self, speaker_id: int) -> bool:
        return speaker_id in self.members

    def get_permissions(self, speaker_id: int) -> Optional[WorldPermissions]:
        member = self.members.get(speaker_id)
        return member.permissions if member else None

    def can(self, speaker_id: int, permission: str) -> bool:
        perms = self.get_permissions(speaker_id)
        if perms is None:
            return False
        return getattr(perms, permission, False)


# =============================================================================
# Part II — Helena
# =============================================================================

class Helena:
    """
    The operating system. Where humans live.
    
    Helena is a speaker. She follows the same rules.
    She cannot override Mary. She issues expressions through Mary.
    """

    def __init__(self):
        # Boot Mary first
        self.mary = Mary()

        # Helena is a speaker (id: 1, created by root)
        self.speaker = self.mary.create_speaker(0, "helena")

        # World registry
        self._worlds: dict[str, World] = {}
        self._next_world_id: int = 0

        # Block list (helena-level, not mary-level)
        self._blocks: dict[int, set] = {}  # speaker_id -> set of blocked speaker_ids

        # Subscriptions
        self._subscriptions: dict[int, list] = {}  # speaker_id -> list of subscriptions

        # Log boot
        self.mary.write(self.speaker.id, "system.status", "booted")
        self.mary.write(self.speaker.id, "system.boot_time", time.time())

    # ── Speaker Management (wraps Mary) ───────────────────────────────

    def create_speaker(self, name: str) -> int:
        """Create a new speaker. Returns speaker_id."""
        speaker = self.mary.create_speaker(self.speaker.id, name)
        if speaker:
            # Create profile variables
            self.mary.write(speaker.id, "profile.name", name)
            self.mary.write(speaker.id, "profile.created_at", time.time())
            return speaker.id
        return -1

    def get_speaker_name(self, speaker_id: int) -> str:
        """Get a speaker's display name."""
        name = self.mary.read(self.speaker.id, speaker_id, "profile.name")
        if name:
            return name
        speaker = self.mary.registry.get(speaker_id)
        return speaker.name if speaker else f"speaker_{speaker_id}"

    # ── World Management ──────────────────────────────────────────────

    def create_world(self, creator_id: int, name: str,
                     default_permissions: WorldPermissions = None,
                     entry_open: bool = False) -> Optional[str]:
        """Create a new world. Returns world_id."""
        if not self.mary.registry.authenticate(creator_id):
            return None

        world_id = f"world_{self._next_world_id}"
        self._next_world_id += 1

        world = World(
            world_id=world_id,
            name=name,
            creator_id=creator_id,
            created_at=time.time(),
            namespace=world_id,
        )

        # Creator gets full permissions
        creator_perms = WorldPermissions(
            read=True, write=True, submit=True,
            request=True, invite=True, configure=True,
        )
        world.members[creator_id] = WorldMember(
            speaker_id=creator_id,
            permissions=creator_perms,
            joined_at=time.time(),
            role="creator",
        )

        self._worlds[world_id] = world

        # Log in mary
        self.mary.write(self.speaker.id, f"worlds.{world_id}.name", name)
        self.mary.write(self.speaker.id, f"worlds.{world_id}.creator", creator_id)
        self.mary.write(self.speaker.id, f"worlds.{world_id}.status", WorldStatus.OPEN)

        # Log creation in the ledger through an expression
        self.mary.submit(
            speaker_id=creator_id,
            condition_label="⊤",
            action=f"create_world:{world_id}:{name}",
            action_fn=lambda: True,
        )

        return world_id

    def join_world(self, speaker_id: int, world_id: str,
                   permissions: WorldPermissions = None) -> bool:
        """Join a world. Returns success."""
        world = self._worlds.get(world_id)
        if not world:
            return False
        if world.status != WorldStatus.OPEN:
            return False
        if not self.mary.registry.authenticate(speaker_id):
            return False

        if permissions is None:
            permissions = WorldPermissions()

        world.members[speaker_id] = WorldMember(
            speaker_id=speaker_id,
            permissions=permissions,
            joined_at=time.time(),
        )

        self.mary.submit(
            speaker_id=speaker_id,
            condition_label=f"invited_to:{world_id}",
            action=f"join_world:{world_id}",
            action_fn=lambda: True,
        )

        return True

    def invite_to_world(self, inviter_id: int, target_id: int, world_id: str,
                        permissions: WorldPermissions = None) -> bool:
        """Invite a speaker to a world. Inviter must have invite permission."""
        world = self._worlds.get(world_id)
        if not world:
            return False
        if not world.can(inviter_id, "invite"):
            return False
        if not self.mary.registry.authenticate(target_id):
            return False

        # Log the invitation
        self.mary.submit(
            speaker_id=inviter_id,
            condition_label="⊤",
            action=f"invite:{target_id}:to:{world_id}",
            action_fn=lambda: True,
        )

        # Auto-join with specified permissions (simplified — real version would require acceptance)
        return self.join_world(target_id, world_id, permissions)

    def leave_world(self, speaker_id: int, world_id: str) -> bool:
        """Leave a world. History remains."""
        world = self._worlds.get(world_id)
        if not world:
            return False
        if speaker_id not in world.members:
            return False

        del world.members[speaker_id]

        self.mary.submit(
            speaker_id=speaker_id,
            condition_label="⊤",
            action=f"leave_world:{world_id}",
            action_fn=lambda: True,
        )

        return True

    def archive_world(self, caller_id: int, world_id: str) -> bool:
        """Archive a world. Read-only from here on."""
        world = self._worlds.get(world_id)
        if not world:
            return False
        if world.creator_id != caller_id:
            return False

        world.status = WorldStatus.ARCHIVED
        self.mary.write(self.speaker.id, f"worlds.{world_id}.status", WorldStatus.ARCHIVED)

        self.mary.submit(
            speaker_id=caller_id,
            condition_label="⊤",
            action=f"archive_world:{world_id}",
            action_fn=lambda: True,
        )

        return True

    def get_world(self, world_id: str) -> Optional[World]:
        """Get a world by ID."""
        return self._worlds.get(world_id)

    def list_worlds(self, speaker_id: int) -> list[World]:
        """List worlds a speaker belongs to."""
        return [w for w in self._worlds.values() if w.is_member(speaker_id)]

    # ── World-Scoped Operations ───────────────────────────────────────

    def world_write(self, speaker_id: int, world_id: str,
                    var_name: str, value: Any) -> bool:
        """Write a variable within a world's namespace."""
        world = self._worlds.get(world_id)
        if not world:
            return False
        if not world.can(speaker_id, "write"):
            return False
        if world.status == WorldStatus.ARCHIVED:
            return False

        # Namespace the variable
        full_var = f"{world_id}.{speaker_id}.{var_name}"
        return self.mary.write(speaker_id, full_var, value)

    def world_read(self, caller_id: int, world_id: str,
                   owner_id: int, var_name: str) -> Any:
        """Read a variable within a world's namespace."""
        world = self._worlds.get(world_id)
        if not world:
            return None
        if not world.can(caller_id, "read"):
            return None

        full_var = f"{world_id}.{owner_id}.{var_name}"
        return self.mary.read(caller_id, owner_id, full_var)

    def world_list_vars(self, caller_id: int, world_id: str,
                        owner_id: int) -> list[str]:
        """List variables for a speaker in a world."""
        world = self._worlds.get(world_id)
        if not world:
            return []
        if not world.can(caller_id, "read"):
            return []

        prefix = f"{world_id}.{owner_id}."
        all_vars = self.mary.list_vars(caller_id, owner_id)
        return [v.replace(prefix, "") for v in all_vars if v.startswith(prefix)]

    # ── Communication (World-Scoped) ──────────────────────────────────

    def world_request(self, caller_id: int, target_id: int, world_id: str,
                      action: str, data: Any = None) -> Optional[int]:
        """Send a request within a world."""
        world = self._worlds.get(world_id)
        if not world:
            return None
        if not world.can(caller_id, "request"):
            return None
        if not world.is_member(target_id):
            return None

        req = self.mary.request(caller_id, target_id,
                                f"{world_id}:{action}", data)
        return req.request_id if req else None

    # ── Blocking ──────────────────────────────────────────────────────

    def block(self, speaker_id: int, target_id: int) -> bool:
        """Block a speaker. Unilateral."""
        if speaker_id not in self._blocks:
            self._blocks[speaker_id] = set()
        self._blocks[speaker_id].add(target_id)

        self.mary.submit(
            speaker_id=speaker_id,
            condition_label="⊤",
            action=f"block:{target_id}",
            action_fn=lambda: True,
        )
        return True

    def unblock(self, speaker_id: int, target_id: int) -> bool:
        """Unblock a speaker."""
        if speaker_id in self._blocks:
            self._blocks[speaker_id].discard(target_id)
        return True

    def is_blocked(self, speaker_id: int, by_speaker: int) -> bool:
        """Check if speaker_id is blocked by by_speaker."""
        return speaker_id in self._blocks.get(by_speaker, set())

    # ── Inspection ────────────────────────────────────────────────────

    def inspect_world(self, caller_id: int, world_id: str) -> Optional[dict]:
        """Full world inspection."""
        world = self._worlds.get(world_id)
        if not world:
            return None
        if not world.can(caller_id, "read"):
            return None

        members_info = []
        for sid, member in world.members.items():
            members_info.append({
                "id": sid,
                "name": self.get_speaker_name(sid),
                "role": member.role,
                "joined_at": member.joined_at,
            })

        return {
            "world_id": world.world_id,
            "name": world.name,
            "creator": self.get_speaker_name(world.creator_id),
            "status": world.status,
            "members": members_info,
            "created_at": world.created_at,
        }

    def inspect_variable_history(self, caller_id: int, world_id: str,
                                 owner_id: int, var_name: str) -> list[dict]:
        """Get full history of a variable in a world."""
        world = self._worlds.get(world_id)
        if not world or not world.can(caller_id, "read"):
            return []

        full_var = f"{world_id}.{owner_id}.{var_name}"
        result = self.mary.inspect_variable(caller_id, owner_id, full_var)
        if result:
            return result.get("history", [])
        return []

    def audit(self, caller_id: int, world_id: str,
              from_time: float = None, to_time: float = None) -> list[dict]:
        """Audit a world — all ledger entries for this world."""
        world = self._worlds.get(world_id)
        if not world or not world.can(caller_id, "read"):
            return []

        entries = self.mary.ledger_search(
            caller_id,
            from_time=from_time,
            to_time=to_time,
        )

        # Filter to entries involving world members or world namespace
        member_ids = set(world.members.keys())
        world_entries = [
            {
                "entry_id": e.entry_id,
                "speaker": self.get_speaker_name(e.speaker_id),
                "speaker_id": e.speaker_id,
                "operation": e.operation,
                "action": e.action,
                "status": e.status.value if e.status else None,
                "timestamp": e.timestamp,
                "break_reason": e.break_reason,
            }
            for e in entries
            if e.speaker_id in member_ids or world_id in (e.action or "")
        ]

        return world_entries

    # ── File Operations (Variables as Files) ──────────────────────────

    def create_file(self, speaker_id: int, world_id: str,
                    filename: str, content: Any) -> bool:
        """Create a file (variable with content) in a world."""
        return self.world_write(speaker_id, world_id, f"file.{filename}", content)

    def read_file(self, caller_id: int, world_id: str,
                  owner_id: int, filename: str) -> Any:
        """Read a file from a world."""
        return self.world_read(caller_id, world_id, owner_id, f"file.{filename}")

    def update_file(self, speaker_id: int, world_id: str,
                    filename: str, content: Any) -> bool:
        """Update a file (old content preserved in ledger)."""
        return self.world_write(speaker_id, world_id, f"file.{filename}", content)

    def file_history(self, caller_id: int, world_id: str,
                     owner_id: int, filename: str) -> list[dict]:
        """Get file change history."""
        return self.inspect_variable_history(
            caller_id, world_id, owner_id, f"file.{filename}"
        )

    # ── Content Hashing ───────────────────────────────────────────────

    @staticmethod
    def hash_content(content: Any) -> str:
        """Generate a content hash for receipts."""
        data = json.dumps(content, sort_keys=True, default=str)
        return hashlib.sha256(data.encode()).hexdigest()[:16]

    # ── System State ──────────────────────────────────────────────────

    def state(self) -> dict:
        """Helena system state."""
        return {
            "mary": self.mary.state(),
            "worlds": len(self._worlds),
            "world_list": [
                {"id": w.world_id, "name": w.name, "members": len(w.members),
                 "status": w.status}
                for w in self._worlds.values()
            ],
        }

    def __repr__(self):
        s = self.state()
        return (f"Helena(worlds={s['worlds']}, "
                f"speakers={s['mary']['speakers']}, "
                f"ledger={s['mary']['ledger_entries']})")
