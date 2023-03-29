load("@rules_dotnet//dotnet:defs.bzl", "csharp_test")
load(
    "//common:browsers.bzl",
    "COMMON_TAGS",
    "chrome_data",
    "edge_data",
    "firefox_data",
)

_BROWSERS = {
    "chrome": {
        "args": [
            "--params=ActiveDriverConfig=Chrome",
        ] + select({
            "@selenium//common:use_pinned_linux_chrome": [
                "--params=DriverServiceLocation=$(location @linux_chromedriver//:chromedriver)",
                "--params=BrowserLocation=$(location @linux_chrome//:chrome-linux)/chrome",
            ],
            "@selenium//common:use_pinned_macos_chrome": [
                "--params=DriverServiceLocation=$(location @mac_chromedriver//:chromedriver)",
                "--params=BrowserLocation=$(location @mac_chrome//:Chromium.app)/Contents/MacOS/Chromium",
            ],
            "@selenium//common:use_local_chromedriver": [],
            "//conditions:default": [
                # Skip test
            ],
        }),
        "data": chrome_data,
    },
    "edge": {
        "args": [
            "--params=ActiveDriverConfig=Edge",
        ] + select({
            "@selenium//common:use_pinned_macos_edge": [
                "--params=DriverServiceLocation=$(location @mac_edgedriver//:msedgedriver)",
                "\"--params=BrowserLocation=$(location @mac_edge//:Edge.app)/Contents/MacOS/Microsoft Edge\"",
            ],
            "@selenium//common:use_local_msedgedriver": [],
            "//conditions:default": [
                "-Dselenium.skiptest=false",
            ],
        }),
        "data": edge_data,
    },
    "firefox": {
        "args": [
            "--params=ActiveDriverConfig=Firefox",
        ] + select({
            "@selenium//common:use_pinned_linux_firefox": [
                "--params=DriverServiceLocation=$(location @linux_geckodriver//:geckodriver)",
                "--params=BrowserLocation=$(location @linux_firefox//:firefox)/firefox",
            ],
            "@selenium//common:use_pinned_macos_firefox": [
                "--params=DriverServiceLocation=$(location @mac_geckodriver//:geckodriver)",
                "--params=BrowserLocation=$(location @mac_firefox//:Firefox.app)/Contents/MacOS/firefox",
            ],
            "@selenium//common:use_local_geckodriver": [],
            "//conditions:default": [
                "-Dselenium.skiptest=false",
            ],
        }),
        "data": firefox_data,
    },
    "ie": {
        "args": [
            "--params=ActiveDriverConfig=IE",
        ],
        "data": [],
    },
    "safari": {
        "args": [
            "--params=ActiveDriverConfig=Safari",
        ],
        "data": [],
    },
}

_HEADLESS_ARGS = select({
    "@selenium//common:use_headless_browser": [
        "--params=Headless=true",
    ],
    "//conditions:default": [],
})

def _is_test(src, test_suffixes):
    for suffix in test_suffixes:
        if src.endswith(suffix):
            return True
    return False

def dotnet_nunit_test_suite(
        name,
        srcs,
        deps = [],
        target_frameworks = None,
        test_suffixes = ["Test.cs"],
        size = None,
        tags = [],
        data = [],
        browsers = None,
        **kwargs):
    test_srcs = [src for src in srcs if _is_test(src, test_suffixes)]
    lib_srcs = [src for src in srcs if not _is_test(src, test_suffixes)]

    extra_deps = [
        "@dotnet_deps//nunitlite",
    ]

    if browsers and len(browsers):
        default_browser = browsers[0]
    else:
        default_browser = None

    tests = []
    for src in test_srcs:
        suffix = src.rfind(".")
        test_name = src[:suffix]

        if not browsers or not len(browsers):
            csharp_test(
                name = test_name,
                srcs = lib_srcs + [src] + ["@rules_dotnet//dotnet/private/rules/common/nunit:shim.cs"],
                deps = deps + extra_deps,
                target_frameworks = target_frameworks,
                data = data,
                tags = tags,
                **kwargs
            )
            tests.append(test_name)
        else:
            for browser in browsers:
                browser_test_name = "%s-%s" % (test_name, browser)

                if browser == default_browser:
                    native.test_suite(
                        name = test_name,
                        tests = [browser_test_name],
                    )

                csharp_test(
                    name = browser_test_name,
                    srcs = lib_srcs + [src] + ["@rules_dotnet//dotnet/private/rules/common/nunit:shim.cs"],
                    deps = deps + extra_deps,
                    target_frameworks = target_frameworks,
                    args = _BROWSERS[browser]["args"] + _HEADLESS_ARGS,
                    data = data + _BROWSERS[browser]["data"],
                    tags = tags + [browser] + COMMON_TAGS,
                    **kwargs
                )
                tests.append(browser_test_name)

    native.test_suite(
        name = name,
        tests = tests,
        tags = ["manual"] + tags,
    )
