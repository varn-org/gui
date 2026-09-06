--- What the gallery reads rather than hard-codes, so a test can point a demo somewhere it controls.
return {
    --- The address the network demo asks.
    address = os.getenv("VARN_GUI_DEMO_URL") or "https://example.com",

    --- Whether the network demo asks as soon as it opens, which is how a screenshot catches the answer.
    fetchOnOpen = os.getenv("VARN_GUI_DEMO_FETCH") ~= nil,
}
