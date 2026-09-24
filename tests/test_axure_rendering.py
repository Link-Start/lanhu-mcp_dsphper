"""Rendered Axure evidence excludes hidden text and crops pathological canvases."""

from pathlib import Path

import pytest
from PIL import Image as PillowImage
from playwright.async_api import Error as PlaywrightError

from lanhu_mcp_server import _select_axure_screenshot_clip, screenshot_page_internal


def test_screenshot_clip_only_targets_large_sparse_canvases():
    issue_metrics = {
        "documentWidth": 19994,
        "documentHeight": 20009,
        "contentBounds": {"x": 50, "y": 100, "width": 1699, "height": 2301},
    }
    assert _select_axure_screenshot_clip(issue_metrics) == {
        "x": 18,
        "y": 68,
        "width": 1763,
        "height": 2365,
    }
    assert _select_axure_screenshot_clip({
        "documentWidth": 1920,
        "documentHeight": 1256,
        "contentBounds": {"x": 0, "y": 0, "width": 1920, "height": 1256},
    }) is None


@pytest.mark.asyncio
async def test_render_filters_hidden_text_and_crops_large_sparse_page(tmp_path):
    resource = tmp_path / "resource"
    output = tmp_path / "output"
    resource.mkdir()
    (resource / "page.html").write_text(
        """<!doctype html><html><head><style>
        html,body { margin:0; width:20000px; height:20000px; }
        #visible { position:absolute; left:50px; top:100px; width:1700px; height:2300px; }
        #opacity { opacity:0; position:absolute; left:4000px; top:4000px; }
        #display { display:none; }
        </style></head><body>
        <div id="visible">VISIBLE REQUIREMENT</div>
        <div id="opacity">GHOST OPACITY</div>
        <div id="display">GHOST DISPLAY</div>
        </body></html>""",
        encoding="utf-8",
    )
    try:
        result = await screenshot_page_internal(
            str(resource), ["page"], str(output), return_base64=False,
            version_id="issue-126", capture_screenshot=True, include_design_info=False,
        )
    except PlaywrightError as exc:
        if "Executable doesn't exist" in str(exc):
            pytest.skip("Playwright Chromium is not installed in this environment")
        raise

    page = result[0]
    assert page["success"] is True
    assert "VISIBLE REQUIREMENT" in page["page_text"]
    assert "GHOST OPACITY" not in page["page_text"]
    assert "GHOST DISPLAY" not in page["page_text"]
    assert page["page_text_blocks"][0]["bounds"]["x"] == 50
    assert page["screenshot_mode"] == "content_crop"
    with PillowImage.open(Path(page["screenshot_path"])) as image:
        assert image.width < 2000
        assert image.height < 2500
