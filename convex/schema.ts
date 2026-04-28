import { defineSchema } from "convex/server";

// This deployment exists primarily so the public-mirror repo IS itself a
// Convex project (mirror parity with test-repo-internal). It has no
// tables of its own. The actual mirroring + publishing flow runs in
// GitHub Actions, configured in `.github/workflows/`. Add tables here
// if your downstream public app grows real Convex needs.
export default defineSchema({});
