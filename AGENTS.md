# Agent instructions for MaruReader

## Project Overview

MaruReader is a Japanese language learning tool for iOS/iPadOS that combines a Yomitan-compatible dictionary with an ebook reader, manga reader, and web browser. It is licensed under GPLv3.

## Building

Build commands are provided by `just`.

Do not run `just` recipes in parallel. Run unsandboxed if your environment has sandboxing.

When running unit tests, runtime warnings like `Multiple NSEntityDescriptions claim the NSManagedObject subclass '...' so +entity is unable to disambiguate.` are expected since tests use an in-memory store which duplicates the entity descriptions from the sqlite store, no need to report these.

## Idealized Workflow

This demonstrates the red/green TDD pattern and best practices for code changes. It is not a prescription or a replacement for common sense. You don't have to explain why you didn't follow this process to the letter unless asked, but you should generally complete as much of this as the environment allows and the nature of the task demands.

0. Keep track of what you're doing with your environment's todo system, and/or with notes in the `build/`  folder.
1. Plan the scope and structure of your patch.
2. Decide acceptance criteria and test strategy.
    - Most non-minor changes, and even minor changes that could use a regression test, need unit test coverage. Expectations of existing tests might also require updates.
    - Changes that touch the UI require interactive validation in simulator. If available in your environment, the CLI tool `axe` can be used to validate many types of UI changes, so it doesn't have to be left as a "next step".
3. If existing expectations are being updated, run tests now to verify current state.
4. Write tests and update expectations.
5. Run tests and validation to verify failing ("red") state
    - If your environment supports sub-agents, sub-agents make it easier to perform comprehensive testing.
    - For example, a sub-agent can validate current UI state and prepare a tightly scoped report for you, perhaps with a script for repeatable validation with `axe`.
6. Implement code changes.
7. Run a build, fix any compile errors or new warnings.
8. Stage changes, run formatting, verify build still works.
9. Run tests and validation, fix any failures to get to "green" state.
    - Again, using sub-agents if available can streamline the testing process.
10. If your environment has a code review function or a suitable sub-agent, get a code review. If there are findings to address, run build, tests, and validation after patching.
11. Commit changes.
