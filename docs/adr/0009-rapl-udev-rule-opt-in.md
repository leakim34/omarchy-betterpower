# 0009. Opt-in udev rule for RAPL counters, installed through pkexec

Date: 2026-09-06
Status: Accepted. Amends 0003.

## Context

ADR 0003 kept v1 free of privileged paths. The power draw section needs Intel RAPL energy
counters, which the kernel makes root-only since the PLATYPUS side-channel fix. Reading them
through pkexec on every sample would prompt every two seconds; a helper daemon would be a
second process to own. The counters themselves are harmless to a user who already runs code
on the machine; the kernel default guards against unprivileged local attackers.

## Decision

A helper in `bin/`, run through pkexec once when the user presses Enable, installs a udev
rule that makes `energy_uj` readable by the `wheel` group (mode 0440) and applies it to the
present devices. The same helper removes the rule. Nothing runs privileged at startup or on a
timer, and the section works without the rule by showing what is locked and why. Per-process
power is not shown at all: it would be an estimate presented as a measurement.

## Consequences

One password prompt, ever, and only on request. Members of `wheel` on the machine can read the
counters afterwards; the README says so and gives the removal command. Revisit if the kernel
gains a per-user grant for powercap or if UPower starts exporting these values.
