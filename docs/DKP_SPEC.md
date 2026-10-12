# Dungeon DKP claims — specification

## Actors
- **Member addon** (`Simulacrum`, public): every guildy runs it.
- **Master extension** (`Simulacrum_Master`, private, only the GM has it): depends on `Simulacrum`, adds a Master tab.
- **Master** = the guild master (guild rank index 0). Members detect it from the guild roster.

## R1 Qualification (member side)
1. Group has exactly 5 players, all in my guild, all running the addon (addon presence via a party ping).
2. The group is inside a dungeon, and the killed encounter is that dungeon's **final boss** (`ENCOUNTER_END` success=1, matched by encounter ID table, falling back to boss name).
3. When met, each of the 5 members creates a **claim** and queues it to the master: map ID, encounter ID, encounter name, instance name, kill time (server time), sorted member list, addon version.
4. Each member's UI shows the live qualification checklist while in a group/dungeon.

## R2 Delivery
1. A claim is **broadcast to GUILD** right after the kill (reaches the master if online and all online guildies).
2. If the master is offline, the claim stays in the member's **outbox**; it is whispered to the master as soon as both are online together (master login `HELLO`, or roster shows master online).
3. Sends wait out chat lockdown (`C_ChatInfo.InChatMessagingLockdown`) and are throttled.

## R3 Member UI ("Claims" tab)
1. List of my claims with a state: *queued — master not seen online*, *delivered — waiting for party/review*, *needs review*, *flagged*, *approved — awaiting master save*, *complete (+N DKP)*, *rejected*.
2. Per party member: delivered-to-master state (e.g. "X has not been online at the same time as the master yet") and verification count, from master ACKs.
3. Info buttons/tooltips explain the whole process and why each step exists.
4. **Save pending requests** button (shown when there is unsaved data) → confirm popup explaining that it runs `/reload` and clears the chat window (true on this client), and that a normal logout also saves; only crashes/disconnects lose unsaved data.

## R4 Witnesses
1. Every other online guildy receiving a claim broadcast (not in that party) checks the guild roster for those members: online and zone == the claimed instance.
2. They create a **proof** (all claim key fields + observation time + per-member in-zone mask) and deliver it to the master like a claim (immediately or via outbox).
3. A proof alone carries enough to create the record; later claims/proofs enrich it. One proof per witness per record.
4. Witnesses also get the Save prompt for unsaved proofs.

## R5 Master processing
1. Records are keyed by map + encounter + member set, merging kill times within ±2 min. Any claim or proof may create the record.
2. On a claim while online, the master refreshes the roster and records its **own observation** of each member's zone (server data, not client-reported).
3. **Auto-accept** only if: all 5 claims received; master observed all 5 in the right instance within 10 min of the kill; all 5 are current guild members; the encounter is a known final boss; no lockout hit; claim arrived within 10 min of the kill time.
4. Otherwise → **review list** with reasons (sus flags), verification counts and per-member detail. Master can Approve / Reject.
5. **Lockout**: for each member, a kill within 15 min after another non-rejected record's kill is never auto-accepted; it goes to review flagged "lockout".
6. Accepted records are **unsaved** until the master clicks **Save & apply** (`/reload`). After reload the master extension: computes totals from the ledger, writes `DKP:<total>` into each member's **officer note** (absolute value → idempotent), whispers `DONE` to online members (offline ones get it when they are next seen online), marks the record complete.
7. Master sends ACKs (received mask, verification count, state) to party members whenever a record changes.

## R6 Probe (temporary)
Logs to `SimulacrumDB.probe` (ring buffer): API availability, instance info, encounter events, group/guild checks, roster zones, addon-message send results and receipts, lockdown state, server vs local time.

## Known problems / decisions
- **Code self-signature is not possible.** Addons cannot read their own files, and `string.dump` is disabled. Even a build-time hash constant can be copied by a modified addon. Integrity has to come from the protocol (independent senders + server data), not from the client.
- **The location check is the only server-truth.** It depends on the guild roster's zone field showing the dungeon name for members inside an instance. The probe verifies this; if it shows the outer zone instead, location checks are much weaker.
- **Witness proofs are only as honest as the witness.** They read the same roster the master would; their value is in covering time when the master is offline. Verification counts are a hint, not proof.
- **Kill time is self-reported** when the master is offline. When online, the master trusts the arrival time instead.
- **Collusion/multiboxing:** 5 accounts controlled by one person, or 5 colluding modified clients, still pass. Lockout, review and roster checks reduce, not remove, this.
- **Instance ID is not a unique run ID.** Classic dungeons have no lockout ID, so records are matched by map + encounter + member set + time window.
- **Final boss IDs** for Forever dungeons are unknown until probed; boss-name fallback works in English clients only.
- **Officer notes**: 31 characters max, require edit permission (GM ok), and members can only read them if their rank may view officer notes.
- **Addon messages**: 255 bytes, throttled; blocked/dropped during boss-encounter lockdown, so sends happen after `ENCOUNTER_END` once lockdown clears.
- SavedVariables are written on `/reload` and on normal logout/exit, so the Save button only protects against crashes and disconnects.

## Probe findings (beta build 1.60.1 / 70338, 2026-10-12)
- Present: `GetServerTime`, `GetInstanceInfo`, `UnitIsInMyGuild`, `C_GuildInfo.GuildRoster/SetNote/CanEditOfficerNote/CanViewOfficerNote`, `C_ChatInfo.InChatMessagingLockdown`, `C_AddOns.*`.
- **Missing**: `GuildRosterSetOfficerNote`, `CanEditOfficerNote` (global), `string.dump`, `debug.getinfo`, `GetAddOnMetadata` (global). Officer notes are written with `C_GuildInfo.SetNote(guid, note, false)`.
- `string.dump`/`debug.getinfo` missing confirms an addon cannot fingerprint its own code.
- Server time equals local time on this machine (not something to rely on for other players).
- `/reload` clears the chat window (observed).
- **Officer notes cannot be written by addons**: `C_GuildInfo.SetNote` raises `ADDON_ACTION_FORBIDDEN` (and the "blocked from an action only available to the Blizzard UI" popup), even from a slash command. R5.6 must change: the master's SavedVariables ledger is the source of truth; officer notes can only be a manual mirror.
- Guild roster (real guild, 10 members): names are full "First Surname" without realm, zone and online state are present, rank index 0 = GM, GUIDs span connected realms (Player-4613-..., Player-4619-...). `IsGuildLeader`, `CanEditOfficerNote`, `CanViewOfficerNote` all true for the GM.
- Addon-message sender is the full name ("Lerius Hillmont"), whispering by full name works, GUILD sends return success.
- Still to verify in a real dungeon run with addon users: roster zone for members inside an instance, `ENCOUNTER_END` IDs for each final boss, chat lockdown timing, addon-message delivery on GUILD/PARTY.

## Implementation
- Member side: `Simulacrum/Claims.lua`, `Simulacrum/UI/Claims.lua`, probe in `Simulacrum/Probe.lua` (`/simprobe`, `/simprobe run`, `/simprobe clear`).
- Master side: private `Simulacrum_Master` addon (kept outside this repo).
- `/simtest` simulates a qualifying Deadmines run (with the master extension it also simulates the other 4 claims and 3 witnesses).

## Signed ledger (replaces officer notes)
- Every DKP change is an entry `seq|time|name|amount|reason`, signed by the guild master with RSA-1024 over SHA-256 (pure Lua, `Crypto.lua`). Public key in `LedgerKey.lua`; private key only in the master extension's `Key.lua` (gitignored, back it up).
- Members verify every entry (≈3 ms) and keep the ledger in SavedVariables; totals = sum of entries. Corrections are new (negative) entries; nothing is ever edited.
- Sync: `V~head~keyId` announcements (login, after publishing), `G~from~to` requests, `L~...~sig` entries over whispers. Any member can relay; relays cannot forge or alter entries, and gaps in `seq` show what is missing. The master answers peers that are behind; members only answer while the master is offline.
- Master flow: approved claims and manual awards stay "accepted" until the master saves (/reload). After the reload they become entries (seq from the saved counter, time = kill time), are signed in the background, published and announced, and members get their `D` notification. A crash before the next save regenerates identical entries and signatures.
- A new key wipes members' ledgers on their next login (key id mismatch).

## Dungeon run recorder (`Runs.lua`)
`SimulacrumDB.runs`: instance/map/difficulty, encounter-journal boss list (final boss = last; its encounter ID feeds claim detection), encounter start/end, kills with qualification result, loot, group composition, guild-roster zone samples while inside, deaths.
