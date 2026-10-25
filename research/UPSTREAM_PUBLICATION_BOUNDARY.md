# Upstream fixture publication boundary

The separately retained local upstream audit contains BoardingPassKit's tests. Some tests include long boarding-pass literals whose passenger-data provenance is not established by the MIT software license. They were not used in this implementation's executable tests and are intentionally excluded from the publication candidate.

The full source audit remains in the local review workspace, outside this publication artifact. Published provenance records the upstream pin, original file paths and hashes, adaptation summary and MIT license; it does not redistribute unknown pass payloads. New executable tests use deliberately authored fixtures with blank private header/reservation fields and an explicitly synthetic fixed-length privacy sentinel.
