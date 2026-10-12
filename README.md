# Deploy and Host Formbricks on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/formbricks-surveys?utm_medium=integration&utm_source=button&utm_campaign=formbricks-surveys)

[Formbricks](https://formbricks.com/) is the open-source alternative to Typeform and Qualtrics: link surveys, website and in-app surveys, NPS and CSAT, with targeting, multi-language surveys, webhooks and an API, on data you own. This template runs Formbricks 6 with every service it needs to start: Postgres with pgvector, Valkey, Formbricks Hub, Cube and SpiceDB. Uploads go to a Railway bucket.

## About Hosting Formbricks

Formbricks 6 is no longer a single container. It refuses to start without SpiceDB for authorization, and it needs Hub (feedback records) and Cube (analytics) as well. This template runs the full stack in six services and a bucket:

- **Formbricks**: the official `ghcr.io/formbricks/formbricks:6.0.2` image. A small wrapper runs what upstream's compose does in one-shot jobs before the server starts: database migrations, loading the SpiceDB schema, and setting CORS on the bucket. The health check on `/health` waits for all of that, and upgrading means bumping the image tag.
- **SpiceDB**: the official `authzed/spicedb:v1.52.0` image (the `-debug` variant, which includes a shell). It migrates its datastore on boot and keeps relationships in Postgres's built-in `postgres` database, separate from the app's data.
- **Hub**: the official `ghcr.io/formbricks/hub:0.8.7` image. It shares the Formbricks database, as upstream does, so it waits for Formbricks to create its tables and then runs its own goose and River migrations.
- **Cube**: the official `ghcr.io/formbricks/cube:1.7.47-1` image, with upstream's `cube.js` and feedback-record schema built in, since Railway can't bind-mount config files.
- **Postgres 17 with pgvector** and **Valkey 8** (sessions, cache, rate limits, background jobs), each with its own volume.
- **A Railway bucket** for survey images, file-upload answers and logos. Formbricks uploads straight from the browser with presigned POSTs, so the app sets the bucket's CORS rule for your domain on every boot.

Every secret (auth, encryption, cron, Hub and Cube keys, SpiceDB key, database and Valkey passwords) is generated per deployment.

## Common Use Cases

- Customer feedback, NPS and CSAT surveys without sending data to a SaaS vendor
- In-app and website surveys that target users by attributes and actions, through the Formbricks JS or mobile SDKs
- Product research, onboarding and churn surveys shared as links or embedded in pages
- A self-hosted Typeform replacement for forms with logic, hidden fields and file uploads

## Dependencies for Formbricks Hosting

- Postgres 17 with pgvector (included, private network only)
- Valkey 8 (included, private network only)
- SpiceDB, Formbricks Hub and Cube (included, private network only)
- A Railway bucket (included)

### Deployment Dependencies

- [Formbricks self-hosting documentation](https://formbricks.com/docs/self-hosting/overview)
- [Formbricks on GitHub](https://github.com/formbricks/formbricks)
- [Template source on GitHub](https://github.com/nomideusz/formbricks-railway)

### Implementation Details

**Create the owner account first.** Open the Formbricks service's Railway domain as soon as the deploy is green. A fresh instance allows exactly one sign-up without an invite: that account creates the organization and becomes its owner. Until then, anyone who finds the URL could claim it. After that, public sign-up is closed and new people join by invite (Organization settings → Members).

**Email (optional).** Without SMTP, email verification and password-reset emails are off (`EMAIL_VERIFICATION_DISABLED=1`, `PASSWORD_RESET_DISABLED=1`), and invites give you a link to copy. To send email, fill in the optional `MAIL_FROM`, `MAIL_FROM_NAME`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD` and `SMTP_SECURE_ENABLED` (`1` for port 465) variables, then set the two `*_DISABLED` flags to `0`. Railway only allows outbound SMTP on the Pro plan. Don't set any of them to an empty string: Formbricks rejects empty values at startup.

**Custom domain.** After adding one, set `WEBAPP_URL` and `NEXTAUTH_URL` to `https://your-domain` and redeploy. The bucket CORS rule follows `WEBAPP_URL` (and `PUBLIC_URL`, if you serve link surveys from a separate domain) on the next boot.

**Back up these values.** `ENCRYPTION_KEY` protects 2FA secrets and single-use survey links, and `NEXTAUTH_SECRET` signs sessions. Changing the first breaks them; changing the second logs everyone out.

**Workspaces and Enterprise features.** Without a license, Formbricks 6 allows one workspace per organization. SSO, roles, the Feedback Data inbox and Analysis dashboards (the features that use Hub and Cube) need `ENTERPRISE_LICENSE_KEY`. Hub and Cube still have to run: Formbricks 6 won't start without them.

**AI features** (survey generation, taxonomy) are off until you configure an AI provider with the `AI_*` variables. See the Formbricks docs.

**Resources.** On Railway the stack idled at about 1 GB of RAM: Formbricks itself about 650 MB, Postgres about 200 MB, Cube about 95 MB, SpiceDB about 60 MB, and Hub and Valkey about 20 MB each. Formbricks alone is over the Trial plan's 512 MB per-service limit, so use the Hobby plan or higher.

## Why Deploy Formbricks on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Formbricks on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
