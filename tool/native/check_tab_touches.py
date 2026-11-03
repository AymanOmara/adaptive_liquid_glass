"""Check real native taps, Flutter overlays and appearance replacement.

Run on a booted 402x874 iOS 26.4 simulator:
  tool/fidelity/.venv/bin/python tool/native/check_tab_touches.py UDID
      [--bitmap | --custom]

--bitmap runs GlassTabBar over a photo (the stock native bar); --custom the
same bar kept on the Flutter renderer in native mode.

Uses a normal app fixture so a test binding does not mediate device input.
Requires idb and its companion, as do the fidelity motion recordings.
"""

import pathlib
import re
import subprocess
import sys
import time


def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    udid = sys.argv[1]
    bitmap = "--bitmap" in sys.argv[2:]
    # The custom Flutter bar in native mode: no UIKit host, Flutter's own
    # gestures, native glyphs and lens.
    custom = "--custom" in sys.argv[2:]
    prefix = ("system-tabs-custom" if custom
              else "system-tabs-bitmap" if bitmap else "system-tabs")
    idb = root / "tool/fidelity/.venv/bin/idb"
    subprocess.run([str(idb), "connect", udid], check=True, timeout=60)
    log = root / f"build/native-limitations/{prefix}-real-touch.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w") as output:
        process = subprocess.Popen(
            ["flutter", "run", "--debug", "--no-pub", "-d", udid,
             "--target", "integration_test/native_tab_touch_app.dart",
             f"--dart-define=NATIVE_TAB_BITMAP={str(bitmap).lower()}",
             f"--dart-define=NATIVE_TAB_CUSTOM={str(custom).lower()}"],
            cwd=root / "example", stdin=subprocess.PIPE, stdout=output,
            stderr=subprocess.STDOUT, text=True,
        )
        try:
            deadline = time.monotonic() + 180
            while "NATIVE_TAB_READY" not in log.read_text():
                if time.monotonic() > deadline:
                    raise AssertionError("Fixture did not start")
                time.sleep(0.1)
            time.sleep(3)
            hosts = "NATIVE_TAB_HOSTS:0" if custom else "NATIVE_TAB_HOSTS:1"
            assert hosts in log.read_text(), log.read_text()

            def tap(x, y):
                subprocess.run([str(idb), "ui", "tap", "--udid", udid, str(x), str(y)], check=True, timeout=10)
                time.sleep(1)

            def picks():
                return [int(i) for i in re.findall(r"NATIVE_TAB_PICK:(\d+)", log.read_text())]

            def screenshot(phase):
                subprocess.run(["xcrun", "simctl", "io", udid, "screenshot",
                                str(log.parent / f"{prefix}-{phase}.png")], check=True)

            tap(201, 822)
            tap(115, 822)
            assert picks() == [1, 0], log.read_text()
            screenshot("exposed")
            tap(80, 125)
            assert "NATIVE_TAB_COVER:true" in log.read_text()
            tap(201, 822)
            assert log.read_text().count("NATIVE_TAB_OVERLAY") == 1, log.read_text()
            assert picks() == [1, 0], log.read_text()
            screenshot("covered")
            tap(80, 125)
            tap(201, 822)
            assert picks() == [1, 0, 1], log.read_text()
            if bitmap or custom:
                press = subprocess.Popen([str(idb), "ui", "tap", "--udid", udid,
                                          "--duration", "2", "201", "822"])
                time.sleep(0.9)
                screenshot("held")
                assert press.wait(timeout=10) == 0
                time.sleep(1)
                assert picks() == [1, 0, 1]
            tap(80, 195)
            assert "NATIVE_TAB_DARK:true" in log.read_text()
            tap(115, 822)
            assert picks() == [1, 0, 1, 0], log.read_text()
            screenshot("rethemed")
            print("PASS: quick taps, Flutter overlay exclusion, recovery and re-theme")
            return 0
        finally:
            if process.poll() is None:
                process.stdin.write("q\n")
                process.stdin.flush()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.wait(timeout=10)


if __name__ == "__main__":
    sys.exit(main())
