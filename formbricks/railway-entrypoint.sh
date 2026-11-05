#!/bin/sh
# Railway has no compose-style one-shot jobs, so this runs upstream's
# formbricks-migrate and authzed-initialize steps before the normal start script.
set -eu
cd /home/nextjs
export NODE_ENV=production

node validate-env.mjs --server
# Railway starts this as soon as the Postgres container is up, not when it accepts connections.
node packages/database/dist/scripts/wait-for-database.js
node packages/database/dist/scripts/apply-migrations.js

# Load the AuthZed schema and backfill relationships (idempotent, upstream runs it on
# every `compose up`). SpiceDB may still be migrating its datastore on first boot.
# Like upstream, the server still starts if it never succeeds; the log says why.
# A changed schema is only written once its current digest is confirmed, and Railway has no
# maintenance step to do that in. Confirm it here only if the change purely adds to the schema,
# as 6.0 to 6.1 does. Anything removed or rewritten stays blocked and logged for the deployer.
additive_digest() {
  formbricks-authzed schema check 2>/dev/null | tail -n 1 | node -e '
    const r = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const kinds = Object.keys(r.differenceKinds || {});
    if (r.remoteDigest && kinds.every((k) => /(_added|_doc_comment_changed)$/.test(k))) console.log(r.remoteDigest);
    else console.error("AuthZed schema needs review:", JSON.stringify(r.differenceKinds));
  '
}
n=0
until formbricks-authzed upgrade prepare || {
  digest=$(additive_digest) && [ -n "$digest" ] && formbricks-authzed upgrade prepare --expected-current-digest "$digest"
}; do
  n=$((n + 1))
  if [ "$n" -ge 30 ]; then echo "WARNING: AuthZed prepare did not succeed; see formbricks.com/docs/self-hosting/advanced/authzed-operations"; break; fi
  sleep 5
done

# Uploads are browser-direct presigned POSTs to the bucket, and Railway buckets
# start with no CORS rule. Allow the app (and PUBLIC_URL for link surveys).
if [ -n "${S3_ENDPOINT_URL:-}" ] && [ -n "${S3_BUCKET_NAME:-}" ]; then
  node - <<'JS' || echo "Could not set bucket CORS; browser uploads may fail"
const { S3Client, PutBucketCorsCommand } = require("@aws-sdk/client-s3");
const e = process.env;
const origins = [...new Set([e.WEBAPP_URL, e.PUBLIC_URL].filter(Boolean).map((u) => new URL(u).origin))];
new S3Client({
  endpoint: e.S3_ENDPOINT_URL,
  region: e.S3_REGION || "auto",
  forcePathStyle: e.S3_FORCE_PATH_STYLE === "1",
  credentials: { accessKeyId: e.S3_ACCESS_KEY, secretAccessKey: e.S3_SECRET_KEY },
})
  .send(new PutBucketCorsCommand({
    Bucket: e.S3_BUCKET_NAME,
    CORSConfiguration: { CORSRules: [{
      AllowedOrigins: origins, AllowedMethods: ["GET", "HEAD", "POST", "PUT"],
      AllowedHeaders: ["*"], ExposeHeaders: ["ETag"], MaxAgeSeconds: 3000,
    }] },
  }))
  .then(() => console.log("Bucket CORS set for", origins.join(", ")))
  .catch((err) => { console.error(err.name, err.message); process.exit(1); });
JS
fi

export SKIP_STARTUP_MIGRATION=true
exec ./start.sh
