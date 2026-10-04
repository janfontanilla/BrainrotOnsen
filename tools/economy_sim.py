"""Brainrot Bathhouse economy simulator.

Reads the live numbers from src/shared/Config (Economy, Tiers, LuckyBlocks), lets
any of them be overridden, and plays a rule-based player through days of
active sessions and offline stretches. Mirrors the server code:

- drops: every brainrot makes its tier's Aura every DROP_INTERVAL s; without Auto
  Collect, production stops while the 50-drop cap is full (player away at the
  stations); 2x Aura / Premium apply to collected drops only.
- offline (DataService.applyOffline): raw Aura per second x elapsed straight into
  the Aura counter (no Aura pass, no Premium); the processor only drains the
  queue that existed at logout. The pile is deposited on return.
- deposit: Aura x market (uniform 0.50-1.50, rerolled every 30 s) into the queue;
  the processor moves queue -> pending Cash at its rate; the Cash pass applies at
  Collect Cash. Group reward Cash is not multiplied.
- buying: unit price = aura x BASE_PRICE_MULTIPLIER x PRICE_GROWTH^boughtAtBuyTier;
  bulk = n x unit price; Merge! merges every triple, cascading; 80 spots.
- lucky blocks: one every 40-100 s of online production; weighted type; price =
  unlock tier aura x LUCKY_BLOCK_PRICE_MULTIPLIER; contents -1/0/+1/+2 at 60/30/9/1.

Usage:  python tools/economy_sim.py            (baseline + report)
        python tools/economy_sim.py --tuned    (proposed config)
"""

from __future__ import annotations

import argparse
import math
import random
import re
from dataclasses import dataclass, field, replace
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "src" / "shared" / "Config"

# ---------------------------------------------------------------- config ---


def load_config() -> dict:
    """Numbers from the Luau config files, so the sim follows the code."""
    cfg: dict = {}
    for line in (CONFIG / "Economy.luau").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^Economy\.([A-Z_]+) = ([0-9_.]+)", line)
        if m and not m.group(1).startswith("STUDIO_"):
            cfg[m.group(1)] = float(m.group(2).replace("_", ""))
    tiers = (CONFIG / "Tiers.luau").read_text(encoding="utf-8")
    cfg["AURA"] = [0.0] + [float(a.replace("_", "")) for a in re.findall(r"aura = ([0-9_]+) \}", tiers)]
    blocks = (CONFIG / "LuckyBlocks.luau").read_text(encoding="utf-8")
    cfg["BLOCKS"] = [
        (n, int(u), int(w))
        for n, u, w in re.findall(r'name = "(\w+)", unlockTier = (\d+), weight = (\d+)', blocks)
    ]
    m = re.search(r"CASH_PACK_HOURS = \{ S = ([0-9_.]+), M = ([0-9_.]+), L = ([0-9_.]+)", (CONFIG / "Economy.luau").read_text())
    cfg["PACK_HOURS"] = {k: float(v) for k, v in zip("SML", m.groups())} if m else {}
    # Upgrade Buy Tier cost growth per tier between TIER_GROWTH_FROM and _TO (1.0 = none).
    cfg.setdefault("BUY_TIER_UPGRADE_GROWTH", 1.0)
    cfg.setdefault("TIER_GROWTH_FROM", 1)
    cfg.setdefault("TIER_GROWTH_TO", 20)
    # Lucky block prices follow the same growth (Config/LuckyBlocks); a separate knob here
    # so the sim can test them apart.
    cfg["LUCKY_BLOCK_PRICE_GROWTH"] = cfg["BUY_TIER_UPGRADE_GROWTH"]
    cfg["MAX_TIER"] = len(cfg["AURA"]) - 1
    assert cfg["MAX_TIER"] == 20 and len(cfg["BLOCKS"]) == 9, "config parse failed"
    return cfg


LUCKY_ODDS = [(-1, 60), (0, 30), (1, 9), (2, 1)]

# ---------------------------------------------------------------- player ---


@dataclass
class Profile:
    name: str
    cash_mult: float = 1.0  # highest Cash pass
    aura_mult: float = 1.0  # 2x Aura pass (active drops only)
    auto_collect: bool = False
    active_hours: float = 4.0  # per day
    sessions: int = 2  # per day, evenly spread
    offline_credit_hours: float | None = None  # of the hours not played; None = all
    group_member: bool = True
    # Collection: the player loops pool -> stations every CYCLE s and is away AWAY s.
    cycle: float = 90.0
    away: float = 20.0
    pickup_eff: float = 0.95  # share of drops picked up while in the pool
    collect_scale: float = 1.0  # sensitivity knob on the derived efficiency
    patient_market: bool = False  # deposit only at market >= PATIENT_MARKET
    market_luck: float = 0.0  # shifts the market mean (sensitivity), e.g. +-0.25
    # Strategy
    buy_payback_hours: float = 6.0  # buy while a unit pays back within this (real time)
    proc_backlog_target: float = 900.0  # upgrade processor while queue > this many s
    proc_max_spend: float = 0.5  # share of Cash a processor upgrade may take
    lucky: bool = True
    lucky_max_spend: float = 0.25  # share of Cash a lucky block may take
    max_days: float = 400.0


PATIENT_MARKET = 1.2
FINE_DT = 2.0  # time step for the first FINE_SECONDS of play (early game is fast)
FINE_SECONDS = 7200
COARSE_DT = 30.0  # after that; divides the 90 s station cycle and the 30 s market roll


@dataclass
class Result:
    profile: Profile
    milestones: dict = field(default_factory=dict)  # key -> (real_days, active_hours, info)
    lucky_opened: dict = field(default_factory=dict)
    max_gap_active_h: float = 0.0
    max_gap_at: str = ""
    finished: bool = False


# ---------------------------------------------------------------- sim ------


class Sim:
    def __init__(self, cfg: dict, p: Profile, seed: int = 1):
        self.c, self.p = cfg, p
        self.rng = random.Random(seed)
        self.aura_t = cfg["AURA"]
        self.max_tier = cfg["MAX_TIER"]
        self.cash = cfg["STARTING_CASH"]
        self.aura = 0.0
        self.queue = 0.0
        self.pending = 0.0
        self.proc_level = 1
        self.buy_tier = 1
        self.bought = 0
        self.counts = [0] * (self.max_tier + 1)
        self.highest = 0
        self.t_real = 0.0
        self.t_active = 0.0
        self.market = 1.0
        self.next_market = 0.0
        self.lucky_clock = 0.0
        self.lucky_next = self._lucky_delay()
        self.group_ready_at = 0.0  # active-time based is fine; real time used
        self.cash_earned = 0.0  # Cash collected incl. multiplier + rewards
        self.earn_log: list[tuple[float, float]] = [(0.0, 0.0)]
        self.res = Result(p)
        self.last_spend_active = 0.0
        self.max_backlog_today = 0.0
        self._rate_cache = 0.0
        self._recount()

    # -- formulas (mirror Config/Economy) --
    def base_price(self, t: int) -> float:
        return self.aura_t[t] * self.c["BASE_PRICE_MULTIPLIER"]

    def unit_price(self) -> float:
        return self.base_price(self.buy_tier) * self.c["PRICE_GROWTH"] ** self.bought

    def upgrade_cost(self) -> float | None:
        if self.buy_tier >= self.max_tier:
            return None
        return (
            self.base_price(self.buy_tier + 1)
            * self.c["BUY_TIER_UPGRADE_MULTIPLIER"]
            * self.c["BUY_TIER_UPGRADE_GROWTH"] ** self.growth_steps(self.buy_tier)
        )

    def growth_steps(self, tier: int) -> int:
        """How many times the per-tier growth applies: only between GROWTH_FROM and GROWTH_TO."""
        lo, hi = int(self.c["TIER_GROWTH_FROM"]), int(self.c["TIER_GROWTH_TO"])
        return max(0, min(tier, hi) - lo)

    def proc_rate(self, level: int | None = None) -> float:
        lv = self.proc_level if level is None else level
        return self.c["PROCESSOR_BASE_RATE"] * self.c["PROCESSOR_RATE_GROWTH"] ** (lv - 1)

    def proc_cost(self) -> float:
        return self.c["PROCESSOR_UPGRADE_BASE_COST"] * self.c["PROCESSOR_COST_GROWTH"] ** (self.proc_level - 1)

    def group_amount(self) -> float:
        return max(self.c["GROUP_REWARD_MIN"], self.base_price(self.buy_tier) * self.c["GROUP_REWARD_MULTIPLIER"])

    def block_price(self, unlock: int) -> float:
        return (
            self.aura_t[unlock]
            * self.c["LUCKY_BLOCK_PRICE_MULTIPLIER"]
            * self.c["LUCKY_BLOCK_PRICE_GROWTH"] ** self.growth_steps(unlock)
        )

    # -- state helpers --
    def _recount(self):
        self._rate_cache = sum(n * self.aura_t[t] for t, n in enumerate(self.counts)) / self.c["DROP_INTERVAL"]
        self._n = sum(self.counts)
        for t in range(self.max_tier, 0, -1):
            if self.counts[t] > 0:
                if t > self.highest:
                    for k in range(self.highest + 1, t + 1):
                        self.mark(f"highest {k}")
                    self.highest = t
                break

    def merge(self) -> int:
        m = 0
        for t in range(1, self.max_tier):
            made = self.counts[t] // 3
            if made:
                self.counts[t] -= 3 * made
                self.counts[t + 1] += made
                m += made
        if m:
            self.mark("first merge")
        self._recount()
        return m

    def mark(self, key: str):
        if key not in self.res.milestones:
            self.res.milestones[key] = {
                "day": self.t_real / 86400,
                "active_h": self.t_active / 3600,
                "cash_per_h": self.cash_per_hour(),
                "income_h": self.income_per_real_hour(),
                "proc": self.proc_level,
                "backlog_min": self.max_backlog_today / 60,
                "buy_tier": self.buy_tier,
                "highest": self.highest,
            }

    def income_per_real_hour(self) -> float:
        """Steady-state Cash per real hour from the brainrots owned now (active + offline)."""
        return sum(n * self.unit_cash_per_real_s(t) for t, n in enumerate(self.counts) if n) * 3600

    def cash_per_hour(self) -> float:
        """Average Cash per real hour over the last 24 h (whole days incl. offline)."""
        now = (self.t_real, self.cash_earned)
        past = self.earn_log[0]
        for e in reversed(self.earn_log):
            if now[0] - e[0] >= 86400:
                past = e
                break
        dt = now[0] - past[0]
        return (now[1] - past[1]) / (dt / 3600) if dt > 0 else 0.0

    def spent(self, what: str):
        gap = self.t_active - self.last_spend_active
        if gap > self.res.max_gap_active_h * 3600:
            self.res.max_gap_active_h = gap / 3600
            self.res.max_gap_at = f"before {what} at buy tier {self.buy_tier}, day {self.t_real / 86400:.1f}"
        self.last_spend_active = self.t_active

    def efficiency(self) -> float:
        if self.p.auto_collect:
            return 1.0
        if self._n == 0:
            return 1.0
        capfill = self.c["DROP_CAP"] * self.c["DROP_INTERVAL"] / self._n
        lost = max(0.0, self.p.away - capfill) / self.p.cycle
        return min(1.0, self.p.pickup_eff * (1 - lost) * self.p.collect_scale)

    def roll_market(self):
        lo, hi = self.c["MARKET_MIN"], self.c["MARKET_MAX"]
        self.market = round(self.rng.uniform(lo, hi), 2) + self.p.market_luck

    def _lucky_delay(self) -> float:
        return self.rng.uniform(self.c["LUCKY_BLOCK_SPAWN_MIN"], self.c["LUCKY_BLOCK_SPAWN_MAX"])

    # -- decisions --
    def mean_market(self) -> float:
        return ((PATIENT_MARKET + 1.5) / 2 if self.p.patient_market else 1.0) + self.p.market_luck

    def unit_cash_per_real_s(self, tier: int) -> float:
        """Long-run Cash per real second from one brainrot of `tier` for this player."""
        day = 86400.0
        active = self.p.active_hours * 3600
        credit = (day - active) if self.p.offline_credit_hours is None else self.p.offline_credit_hours * 3600
        aura_s = self.aura_t[tier] / self.c["DROP_INTERVAL"]
        per_day = aura_s * (active * self.efficiency() * self.p.aura_mult + credit)
        return per_day / day * self.mean_market() * self.p.cash_mult

    def lucky_worth(self, unlock: int) -> bool:
        """Open when the block reaches its contents more cheaply than buying + merging."""
        p_unit = self.unit_price()
        alt = 0.0
        for off, w in LUCKY_ODDS:
            t = min(unlock + off, self.max_tier)
            if t >= self.buy_tier:
                alt += w / 100 * 3 ** (t - self.buy_tier) * p_unit
            else:
                alt += w / 100 * self.aura_t[t] / self.aura_t[self.buy_tier] * p_unit
        return self.block_price(unlock) < alt

    def open_lucky(self):
        total = sum(w for _, _, w in self.c["BLOCKS"])
        r = self.rng.uniform(0, total)
        for name, unlock, w in self.c["BLOCKS"]:
            r -= w
            if r <= 0:
                break
        price = self.block_price(unlock)
        if (
            not self.p.lucky
            or unlock < self.buy_tier  # contents mostly below what the pads sell: discard
            or price > self.cash * self.p.lucky_max_spend
            or not self.lucky_worth(unlock)
        ):
            return
        if self._n >= 80:
            self.merge()
            if self._n >= 80:
                return
        rr = self.rng.uniform(0, 100)
        for off, w in LUCKY_ODDS:
            rr -= w
            if rr <= 0:
                break
        tier = min(unlock + off, self.max_tier)
        self.cash -= price
        self.counts[tier] += 1
        self.res.lucky_opened[name] = self.res.lucky_opened.get(name, 0) + 1
        self.spent("lucky block")
        self.merge()

    def visit_stations(self):
        """Deposit (unless waiting for a better market), collect Cash, spend."""
        if not self.p.patient_market or self.market >= PATIENT_MARKET:
            self.deposit()
        self.collect()
        self.spend()

    def deposit(self):
        if self.aura > 0:
            self.queue += self.aura * self.market
            self.aura = 0.0

    def collect(self):
        if self.pending > 0:
            gain = self.pending * self.p.cash_mult
            self.cash += gain
            self.cash_earned += gain
            self.pending = 0.0

    def spend(self):
        for _ in range(10_000):
            # 1. processor: keep the backlog short
            rate = self.proc_rate()
            backlog = self.queue / rate
            if backlog > self.p.proc_backlog_target and self.proc_cost() <= self.cash * self.p.proc_max_spend:
                self.cash -= self.proc_cost()
                self.proc_level += 1
                self.spent("processor upgrade")
                continue
            # 2. Upgrade Buy Tier whenever affordable
            up = self.upgrade_cost()
            if up is not None and self.cash >= up:
                self.cash -= up
                self.buy_tier += 1
                self.bought = 0
                self.mark(f"buy tier {self.buy_tier}")
                self.mark("first upgrade")
                self.spent("Upgrade Buy Tier")
                continue
            # 3. buy while a unit pays back within the horizon (merging only improves it)
            price = self.unit_price()
            payback_h = price / self.unit_cash_per_real_s(self.buy_tier) / 3600
            # Worth buying if it pays back before the next upgrade could be afforded anyway.
            horizon = self.p.buy_payback_hours
            if up is not None:
                income_h = self.income_per_real_hour()
                if income_h > 0:
                    horizon = max(horizon, (up - self.cash) / income_h)
            if payback_h <= horizon or self._n == 0:
                bought = False
                for n in (100, 25, 5, 1):
                    if n * price <= self.cash:
                        after = self.counts.copy()
                        after[self.buy_tier] += n
                        for t in range(1, self.max_tier):
                            after[t + 1] += after[t] // 3
                            after[t] %= 3
                        if sum(after) > 80:
                            continue
                        self.cash -= n * price
                        self.bought += n
                        self.counts[self.buy_tier] += n
                        self.spent("buy")
                        self.merge()
                        bought = True
                        break
                if bought:
                    continue
            break

    # -- time --
    def session(self, seconds: float):
        p = self.p
        # Login: claim the group reward once, collect what the processor made offline,
        # deposit the offline pile, spend.
        self.claim_group()
        self.roll_market()
        self.visit_stations()
        t = 0.0
        next_visit = p.cycle
        while t < seconds:
            dt = FINE_DT if self.t_active < FINE_SECONDS else COARSE_DT
            dt = min(dt, seconds - t)
            eff = self.efficiency()
            self.aura += self._rate_cache * dt * eff * p.aura_mult
            if self._n:
                self.lucky_clock += dt
                if self.lucky_clock >= self.lucky_next:
                    self.lucky_clock = 0.0
                    self.lucky_next = self._lucky_delay()
                    self.open_lucky()
            moved = min(self.queue, self.proc_rate() * dt)
            self.queue -= moved
            self.pending += moved
            t += dt
            self.t_real += dt
            self.t_active += dt
            if self.t_real >= self.next_market:
                self.roll_market()
                self.next_market = self.t_real + self.c["MARKET_INTERVAL"]
                if p.patient_market and self.market >= PATIENT_MARKET:
                    self.deposit()
            if t >= next_visit:
                next_visit += p.cycle
                self.max_backlog_today = max(self.max_backlog_today, self.queue / self.proc_rate())
                self.claim_group()
                self.visit_stations()
            if self.buy_tier >= self.max_tier and self.highest >= self.max_tier:
                return
        # Logout: deposit everything so the processor works through it offline.
        self.deposit()
        self.collect()

    def claim_group(self):
        if self.p.group_member and self.t_real >= self.group_ready_at:
            amt = self.group_amount()
            self.cash += amt
            self.cash_earned += amt
            self.group_ready_at = self.t_real + self.c["GROUP_REWARD_INTERVAL"]

    def offline(self, seconds: float, credit_seconds: float):
        self.aura += self._rate_cache * credit_seconds * self.c["OFFLINE_RATE"]
        moved = min(self.queue, self.proc_rate() * seconds)
        self.queue -= moved
        self.pending += moved
        self.t_real += seconds

    def run(self) -> Result:
        p = self.p
        day = 86400.0
        session_len = p.active_hours * 3600 / p.sessions
        gap = (day - p.active_hours * 3600) / p.sessions
        credit_total = (day - p.active_hours * 3600) if p.offline_credit_hours is None else p.offline_credit_hours * 3600
        credit_gap = credit_total / p.sessions
        while self.t_real < p.max_days * day:
            self.max_backlog_today = 0.0
            for _ in range(p.sessions):
                self.session(session_len)
                if self.buy_tier >= self.max_tier and self.highest >= self.max_tier:
                    self.res.finished = True
                    return self.res
                self.earn_log.append((self.t_real, self.cash_earned))
                self.offline(gap, credit_gap)
        return self.res


def simulate(cfg: dict, p: Profile, seeds=(1, 2, 3)) -> Result:
    """Median over a few seeds (market + lucky randomness)."""
    results = [Sim(cfg, p, s).run() for s in seeds]
    results.sort(key=lambda r: r.milestones.get("highest 20", {}).get("day", 1e9))
    return results[len(results) // 2]


# ---------------------------------------------------------------- report ---

FREE = Profile("Free (no passes)", active_hours=2.0)
X7 = Profile("x7 Cash", cash_mult=7.0, active_hours=2.0)
WHALE = Profile("Whale (x12, 2x Aura, Auto Collect)", cash_mult=12.0, aura_mult=2.0, auto_collect=True, active_hours=2.0)


def fmt_num(x: float) -> str:
    for unit, v in (("Qa", 1e15), ("T", 1e12), ("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if abs(x) >= v:
            return f"{x / v:.3g}{unit}"
    return f"{x:.0f}"


def when(res: Result, key: str) -> str:
    m = res.milestones.get(key)
    if not m:
        return "-"
    if m["active_h"] < 1:
        return f"{m['active_h'] * 60:.1f} min"
    return f"d{m['day']:.1f} ({m['active_h']:.1f} h played)"


def summary(cfg: dict, profiles, title: str):
    print(f"\n=== {title} ===")
    keys = ["first merge", "first upgrade", "buy tier 5", "buy tier 10", "buy tier 15", "buy tier 20", "highest 20"]
    rows = [(p.name, simulate(cfg, p)) for p in profiles]
    print("| milestone | " + " | ".join(n for n, _ in rows) + " |")
    print("|---|" + "---|" * len(rows))
    for k in keys:
        print(f"| {k} | " + " | ".join(when(r, k) for _, r in rows) + " |")
    return rows


def milestone_table(res: Result):
    print(f"\n=== Milestones: {res.profile.name} ===")
    print("| milestone | day | hours played | Cash / real hour | processor Lv | worst backlog that day |")
    print("|---|---|---|---|---|---|")
    keys = [f"buy tier {t}" for t in (2, 5, 8, 10, 12, 15, 18, 20)] + [f"highest {t}" for t in (5, 10, 15, 20)]
    for k in keys:
        m = res.milestones.get(k)
        if m:
            print(
                f"| {k} | {m['day']:.2f} | {m['active_h']:.1f} | {fmt_num(m['income_h'])} | {m['proc']} | {m['backlog_min']:.0f} min |"
            )
    print(f"Lucky blocks opened: {res.lucky_opened or 'none'}")
    print(f"Longest stretch of play without spending: {res.max_gap_active_h:.2f} h ({res.max_gap_at})")
    steps = [res.milestones.get(f"buy tier {t}", {}).get("active_h") for t in range(2, 21)]
    prev = None
    cliffs = []
    for t, (a, b) in enumerate(zip([0.0] + steps, steps), start=2):
        if a is None or b is None:
            continue
        d = b - a
        if prev and d > 4 * prev and d > 0.25:
            cliffs.append(f"buy tier {t}: {d:.2f} h vs {prev:.2f} h")
        prev = d if d > 0 else prev
    print(f"Cliffs (> 4x the previous step): {cliffs or 'none'}")


def packs_table(cfg: dict, res_by_name: dict):
    print("\n=== Cash packs (hours of brainrot income) at each buy tier, vs the step to the next tier ===")
    print("| buy tier | S | M | L | that step takes (x7 / free, real time) |")
    print("|---|---|---|---|---|")
    for t in (2, 5, 10, 12, 15, 18):
        cells = []
        steps = []
        for name in ("x7", "free"):
            ms = res_by_name[name].milestones
            a, b = ms.get(f"buy tier {t}"), ms.get(f"buy tier {t + 1}")
            steps.append(f"{(b['day'] - a['day']) * 24:.1f} h" if a and b else "-")
        x7 = res_by_name["x7"].milestones.get(f"buy tier {t}")
        raw = x7["income_h"] / 7 if x7 else 0  # raw Aura per hour, before the x7 pass
        for size in "SML":
            cells.append(fmt_num(max(raw, cfg["STARTING_CASH"]) * cfg["PACK_HOURS"][size]))
        print(f"| {t} | " + " | ".join(cells) + f" | {' / '.join(steps)} |")


def tuned_config(cfg: dict) -> dict:
    c = dict(cfg)
    c.update(TUNING)
    return c


# Overrides to try on top of the live Config (empty = the live numbers). The live
# numbers were tuned with this file on 2026-10-04.
TUNING: dict = {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tuned", action="store_true")
    args = ap.parse_args()
    cfg = load_config()
    if args.tuned:
        cfg = tuned_config(cfg)
    rows = summary(cfg, [FREE, X7, WHALE], "tuned" if args.tuned else "baseline (today's config)")
    res = dict(rows)
    milestone_table(res[X7.name])
    packs_table(cfg, {"x7": res[X7.name], "free": res[FREE.name]})


if __name__ == "__main__":
    main()
