#!/bin/zsh
# Convert a wall-clock time in another time zone to this Mac's local time.
#
# @vicinae.schemaVersion 1
# @vicinae.title Time: Convert to Local
# @vicinae.mode compact
# @vicinae.packageName Time
# @vicinae.keywords ["timezone", "time zone", "convert time"]
# @vicinae.argument1 {"type":"text","placeholder":"4.30 ist"}

/usr/bin/python3 - "$1" <<'PY'
import re
import sys
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


ALIASES = {
    "utc": "UTC",
    "gmt": "UTC",
    "ist": "Asia/Kolkata",
    "india": "Asia/Kolkata",
    "indian standard time": "Asia/Kolkata",
    "pt": "America/Los_Angeles",
    "pst": "America/Los_Angeles",
    "pdt": "America/Los_Angeles",
    "pacific": "America/Los_Angeles",
    "mt": "America/Denver",
    "mst": "America/Denver",
    "mdt": "America/Denver",
    "mountain": "America/Denver",
    "ct": "America/Chicago",
    "cst": "America/Chicago",
    "cdt": "America/Chicago",
    "central": "America/Chicago",
    "et": "America/New_York",
    "est": "America/New_York",
    "edt": "America/New_York",
    "eastern": "America/New_York",
    "bst": "Europe/London",
    "uk": "Europe/London",
    "london": "Europe/London",
    "cet": "Europe/Berlin",
    "cest": "Europe/Berlin",
    "berlin": "Europe/Berlin",
    "jst": "Asia/Tokyo",
    "tokyo": "Asia/Tokyo",
    "kst": "Asia/Seoul",
    "seoul": "Asia/Seoul",
    "sgt": "Asia/Singapore",
    "singapore": "Asia/Singapore",
    "aest": "Australia/Sydney",
    "aedt": "Australia/Sydney",
    "sydney": "Australia/Sydney",
}


def fail(message):
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(1)


match = re.fullmatch(
    r"\s*(\d{1,2})(?:[.:](\d{2}))?\s*(am|pm)?\s+(.+?)\s*",
    sys.argv[1],
    re.IGNORECASE,
)
if not match:
    fail("use a time followed by a zone, for example: 4.30 ist")

hour = int(match.group(1))
minute = int(match.group(2) or 0)
meridiem = (match.group(3) or "").lower()
zone_input = match.group(4)

if minute > 59 or (meridiem and not 1 <= hour <= 12) or (not meridiem and hour > 23):
    fail("invalid time")
if meridiem:
    hour = hour % 12 + (12 if meridiem == "pm" else 0)

zone_name = ALIASES.get(zone_input.casefold(), zone_input)
try:
    source_zone = ZoneInfo(zone_name)
except ZoneInfoNotFoundError:
    fail(f"unknown time zone: {zone_input}")

source_date = datetime.now(source_zone).date()
source_time = datetime(
    source_date.year,
    source_date.month,
    source_date.day,
    hour,
    minute,
    tzinfo=source_zone,
)

# Reject wall times skipped by a daylight-saving transition.
round_trip = source_time.astimezone(timezone.utc).astimezone(source_zone)
if round_trip.replace(tzinfo=None) != source_time.replace(tzinfo=None):
    fail("that time does not exist because the clocks move forward")

local_time = source_time.astimezone()
clock = local_time.strftime("%I").lstrip("0") + local_time.strftime(":%M %p %Z")
date = local_time.strftime("%a, %b ") + str(local_time.day)
print(f"{clock} ({date})")
PY
