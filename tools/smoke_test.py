#!/usr/bin/env python3
"""Local browser smoke test using the environment's installed Chromium."""
from __future__ import annotations

import asyncio
import mimetypes
from pathlib import Path
from urllib.parse import urlparse

from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = "https://smallworld.test"


def content_type(path: Path) -> str:
    if path.suffix == ".mjs":
        return "text/javascript"
    return mimetypes.guess_type(path.name)[0] or "application/octet-stream"


async def main() -> None:
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            headless=False,
            executable_path="/usr/bin/chromium",
            args=[
                "--no-sandbox",
                "--ignore-gpu-blocklist",
                "--enable-webgl",
                "--enable-unsafe-swiftshader",
                "--use-angle=swiftshader",
            ],
        )
        page = await browser.new_page(viewport={"width": 1440, "height": 900})
        console_messages: list[str] = []
        page_errors: list[str] = []
        page.on("console", lambda message: console_messages.append(f"{message.type}: {message.text}"))
        page.on("pageerror", lambda error: page_errors.append(str(error)))

        async def route_handler(route) -> None:
            parsed = urlparse(route.request.url)
            relative = parsed.path.lstrip("/") or "index.html"
            path = (ROOT / relative).resolve()
            if ROOT not in path.parents and path != ROOT:
                await route.fulfill(status=403, body="Forbidden")
                return
            if not path.exists() or not path.is_file():
                await route.fulfill(status=404, body="Not found")
                return
            await route.fulfill(
                status=200,
                content_type=content_type(path),
                headers={"Access-Control-Allow-Origin": "*"},
                body=path.read_bytes(),
            )

        await page.route(f"{ORIGIN}/**", route_handler)
        html = (ROOT / "index.html").read_text(encoding="utf-8")
        html = html.replace("<head>", f"<head><base href=\"{ORIGIN}/\">", 1)
        await page.set_content(html, wait_until="load", timeout=60_000)
        await page.wait_for_function("Boolean(window.__SMALL_WORLD__)", timeout=20_000)
        await page.click("#start-button")
        await page.wait_for_timeout(1_000)

        state = await page.evaluate("window.__SMALL_WORLD__.director.state")
        assert state == "ARRIVE", state
        start_z = await page.evaluate("window.__SMALL_WORLD__.player.position[2]")
        await page.keyboard.down("w")
        await page.wait_for_timeout(550)
        await page.keyboard.up("w")
        moved_z = await page.evaluate("window.__SMALL_WORLD__.player.position[2]")
        assert moved_z < start_z - 0.2, (start_z, moved_z)

        start_x = await page.evaluate("window.__SMALL_WORLD__.player.position[0]")
        await page.keyboard.down("d")
        await page.wait_for_timeout(550)
        await page.keyboard.up("d")
        moved_x = await page.evaluate("window.__SMALL_WORLD__.player.position[0]")
        assert moved_x > start_x + 0.2, (start_x, moved_x)

        canvas_size = await page.locator("#game-canvas").evaluate(
            "canvas => ({width: canvas.width, height: canvas.height})"
        )
        assert canvas_size["width"] > 100 and canvas_size["height"] > 100, canvas_size
        await page.screenshot(path=str(ROOT / "playtest-preview.png"), full_page=True)

        await page.evaluate("window.__SMALL_WORLD__.dispatch('observe')")
        await page.wait_for_function(
            "window.__SMALL_WORLD__.director.state === 'FIND_BALL'", timeout=10_000
        )

        for event in ["ball_picked_up", "ball_returned", "joined", "entered_home"]:
            accepted = await page.evaluate(
                "event => window.__SMALL_WORLD__.dispatch(event)", event
            )
            assert accepted, event
            await page.wait_for_timeout(150)

        await page.wait_for_function(
            "!document.querySelector('#end-screen').hidden", timeout=8_000
        )
        if page_errors:
            raise AssertionError("Browser errors:\n" + "\n".join(page_errors))
        serious_console = [message for message in console_messages if message.startswith("error:")]
        if serious_console:
            raise AssertionError("Console errors:\n" + "\n".join(serious_console))
        print(f"Browser smoke test passed: {canvas_size['width']}x{canvas_size['height']}")
        await browser.close()


if __name__ == "__main__":
    asyncio.run(main())
