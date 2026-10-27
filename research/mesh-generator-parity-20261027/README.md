# Preserve mesh linkage during project generation

The generator previously omitted the mesh package that the committed app project already links. It now retains the same local package, product and framework IDs without enabling diagnostics or changing app source. The committed PBX file was not regenerated or changed.

85 serial Node checks passed, including11 new graph/mutation/default-flag cases plus existing optional-backend/privacy regressions. The focused cases compare mesh graph linkage with the committed project, reject missing edges, and preserve default/optional configuration behavior. These are in-memory source checks, not a native build of a regenerated project or runtime activation. See RESULT.json and tests.log.
