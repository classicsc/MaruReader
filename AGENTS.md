# Agent instructions for MaruReader

## Project Overview

MaruReader is a Japanese language learning tool for iOS/iPadOS that combines a Yomitan-compatible dictionary with an ebook reader, manga reader, and web browser. It is licensed under GPLv3.

## Building

Build and test commands are provided by `just`. Use it instead of invoking `xcodebuild` directly for routine build and test runs. Tests can take upwards of 3 minutes (sometimes over 5 minutes for a brand new simulator) so set timeouts/waits accordingly.

Do not run `just` recipes (or xcodebuild commands) in parallel, each invocation needs a lock on the build folder. Run unsandboxed if your environment has sandboxing.

## Idealized Workflow

This demonstrates the red/green TDD pattern and best practices for major changes. It is not a prescription or a replacement for common sense. You don't have to explain why you didn't follow this process to the letter unless asked, but you should generally complete as much of this as the environment allows and the nature of the task demands.

1. Keep track of what you're doing with your environment's todo system, and/or with notes in the `build/`  folder.
1. Plan the scope and structure of your patch.
1. Decide acceptance criteria and test strategy.
    - Most non-minor changes, and even minor changes that could use a regression test, need unit test coverage. Expectations of existing tests might also require updates.
    - Changes that touch the UI require interactive validation in simulator. If available in your environment, the CLI tool `axe` can be used to launch a simulator, capture screenshots and recordings, read the accessibility hierarchy, and interact with the running app with various gestures to validate many types of UI changes, so it doesn't have to be left as a "next step".
1. If existing expectations are being updated, run tests now to verify current state.
1. Write tests and update expectations.
1. Run tests and validation to verify failing ("red") state
    - If your environment supports sub-agents, sub-agents make it easier to perform comprehensive testing.
    - For example, a sub-agent can validate current UI state and prepare a tightly scoped report for you, perhaps with a script for repeatable validation with `axe`.
1. Implement code changes.
1. Run a build, fix any compile errors or new warnings.
1. Run tests and validation, fix any failures to get to "green" state.
    - Again, using sub-agents if available can streamline the testing process.
1. Stage changes, run formatting, verify build still works. If formatting breaks build, back out the breaking change(s) and use `swiftformat --lint` to identify the specific rule which needs to be disabled at the broken line.
1. If your environment has a code review function or a suitable sub-agent, get a code review. If there are findings to address, run build, tests, and validation after patching.
1. Commit changes.
