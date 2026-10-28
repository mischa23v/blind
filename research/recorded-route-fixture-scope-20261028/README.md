# Native hosted-test fixture scope correction

Native run 40657202187 at adb8fd8 built both app modes and passed Core/Memory, but hosted/UI tests did not execute: three RecordedRouteStore fixtures referenced an undeclared entered semaphore. Two also lacked the factory-entry signal.

The isolated published-source correction adds those three local declarations and two signals before the existing release waits. Existing awaited entry, transition ordering, assertions and five-second fixture bounds remain. No production change or unfinished same-frame test is included. Source contract checks verify declaration, signal, awaited entry and lifecycle transition within each named method; they do not substitute for Swift/native execution.

Published preimage SHA256: 17a04706728b944848f65798741fa4ecc0619df8f93af030ccdde38324f9a116. Corrected test file SHA256: 223222e3039bd2f785fa364098c689aeae544263e93bb54c52b1dee4868951d4. The worktree additionally contains later candidate tests, so this correction publishes the isolated corrected file, not all worktree tests.
