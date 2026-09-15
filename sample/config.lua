--- What the gallery reads rather than hard-codes, so a test can point a demo somewhere it controls.
return {
    --- The address the network demo asks.
    ---
    --- A browser only lets a page read an answer the other end allows it to, so a demo that runs on all
    --- three asks somewhere that says so. httpbin answers every origin.
    address = os.getenv("VARN_GUI_DEMO_URL") or "https://httpbin.org/get",

    --- Whether the network demo asks as soon as it opens, which is how a screenshot catches the answer.
    fetchOnOpen = os.getenv("VARN_GUI_DEMO_FETCH") ~= nil,
}
