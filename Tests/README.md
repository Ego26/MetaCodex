# Tests

    node Tests/run.js Tests/smoke_test.lua   # does the addon actually load?
    node Tests/run.js                        # catalog logic only

Both run in a real Lua VM (fengari).

## smoke_test.lua

Loads the addon **in the order of the real TOC** against a stubbed WoW API
and then operates it: logs in, reads the gear, builds the list, hands it to
a fake Auctionator, opens the window, runs `/mc probe`.

It exists because of two bugs that a syntax check cannot see:

- The window opened in game but the buttons showed translation keys
  instead of text. A second `RegisterLocale` call for the same language had
  replaced the first block instead of merging into it.
- Rows in a scroll frame must be re-anchored on every refresh. A forgotten
  `ClearAllPoints` stacks them on top of each other, and nothing says so
  until you look at it.

The stub in `wow_stub.lua` deliberately does **not** model what Blizzard's
functions mean — that cannot be done honestly, and anyone trying ends up
testing their own stub. It answers one question: does the source run from
top to bottom without hitting a nil? Every frame records what was done to
it, so anchors and texts can be asserted afterwards.

Everything beyond that — whether `GetItemStats` really reports sockets,
whether Auctionator accepts our search strings — needs the running client.
That is what `/mc probe` is for.
