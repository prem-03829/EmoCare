from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

try:
    IST = ZoneInfo("Asia/Kolkata")
    UTC = ZoneInfo("UTC")
except ZoneInfoNotFoundError:
    # Fallback for environments missing tz database (e.g., fresh Windows/uv envs)
    IST = timezone(timedelta(hours=5, minutes=30))
    UTC = timezone.utc


def now_ist():
    return datetime.now(IST)

def convert_utc_to_ist(dt: datetime):
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(IST)
