"""데모 화면을 headless 브라우저로 확인한다.

화면이 도는 동안의 콘솔 오류를 모으고, ADR-0001 의 결정(추가를 받기 전에 제거한
값은 병합 뒤에도 살아나지 않는다)을 실제 브라우저에서 확인한다.
"""

import pathlib
import sys

from playwright.sync_api import Page, sync_playwright

HERE = pathlib.Path(__file__).resolve().parent
PAGE = (HERE / "index.html").as_uri()
SHOT = HERE / "demo.png"


def run_scenario(page: Page, problems: list[str]) -> None:
    """값을 넣고, 관찰 전 제거를 하고, 병합한 뒤 화면을 확인한다."""

    def state(i: int) -> str:
        return page.inner_text(f"#state-{i}")

    if state(0) != "-" or state(1) != "-":
        problems.append("처음에는 두 복제본이 비어 있어야 한다")

    for value in ("1", "2", "3"):
        page.click(f"#a-add-{value}")
    if state(0) != "1,2,3":
        problems.append(f"A 에 넣은 값이 보여야 하는데 {state(0)!r}")
    if state(1) != "-":
        problems.append(f"B 는 아직 비어 있어야 하는데 {state(1)!r}")

    # B 는 3 을 한 번도 받은 적이 없지만 제거한다
    page.click("#b-del-3")
    page.click("#merge")

    if state(0) != "1,2":
        problems.append(f"병합 뒤 A 에서 3 이 사라져야 하는데 {state(0)!r}")
    if state(1) != "1,2":
        problems.append(f"병합 뒤 B 도 같은 상태여야 하는데 {state(1)!r}")
    if state(2) != "1,2":
        problems.append(f"병합 결과도 같아야 하는데 {state(2)!r}")
    if not page.inner_text("#verdict").endswith("같음"):
        problems.append("세 패널이 수렴했다고 표시되어야 한다")

    # 수렴한 순간을 기록으로 남긴다
    page.screenshot(path=str(SHOT), full_page=True)

    # 다시 시작하면 비워진다
    page.click("#reset")
    if state(0) != "-" or state(1) != "-":
        problems.append("다시 시작하면 두 복제본이 비어야 한다")


def main() -> int:
    problems: list[str] = []
    errors: list[str] = []

    def on_console(message) -> None:
        if message.type == "error":
            errors.append(f"console.error: {message.text}")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        # 화면이 도는 동안의 오류를 모은다 (goto 전에 등록)
        page.on("console", on_console)
        page.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))
        try:
            page.goto(PAGE)
            page.wait_for_load_state("load")
            run_scenario(page, problems)
        finally:
            browser.close()

    for problem in problems:
        print("실패:", problem)
    for error in errors:
        print("브라우저 오류:", error)
    if problems or errors:
        return 1

    print(f"데모 검사 통과 (스크린샷 {SHOT})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
