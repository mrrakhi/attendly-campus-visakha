# Attendly Campus — online attendance portal starter

This is a deployable starter project for a student/admin attendance portal using:
- **Supabase Auth** for email/password authentication
- **Supabase Postgres** as the cloud database
- **Row Level Security (RLS)** to restrict students to their own attendance records
- **GitHub Pages** (or another static host) for free static hosting

## Files
- `index.html` — web app
- `schema.sql` — database tables, signup trigger, grants and RLS policies

## Before using real student data
This is a starter implementation. Test it with dummy accounts first and have a knowledgeable adult/college IT administrator review the SQL, access policies, and deployment. The frontend uses the Supabase publishable key only. **Never put a Supabase secret/service-role key in `index.html` or GitHub.**

## 1. Create a Supabase project
1. Create/sign in to a Supabase account at https://supabase.com/.
2. Create a new project and save the database password somewhere private.
3. In Project Settings / API Keys (wording may vary), copy the **Project URL** and **publishable key**. A legacy `anon` key is also a client key, but use the current publishable key when available.
4. Open `index.html` and replace:
   - `YOUR_SUPABASE_PROJECT_URL`
   - `YOUR_SUPABASE_PUBLISHABLE_KEY`
   with your project's values.
5. In Supabase, open **SQL Editor**, create a query, paste all of `schema.sql`, and run it.
6. In Authentication settings, configure email confirmation and the allowed redirect/site URLs for the domain you deploy to. Test signup and sign-in.

Supabase Auth uses JWTs and can work with RLS policies. Keep RLS enabled on every exposed table and never expose a secret/service-role key in browser code. See:
- https://supabase.com/docs/guides/auth
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/getting-started/api-keys

## 2. Create your first admin account safely
1. Deploy/run the app and use **Create account** with the email of the trusted staff member who should be the admin.
2. If email confirmation is enabled, confirm the account and sign in once.
3. In Supabase **SQL Editor**, run the following query, replacing the email with that exact account email:

```sql
update public.profiles
set role = 'admin'
where lower(email) = lower('trusted-admin@example.com');
```

4. Verify exactly one row was updated. If zero rows were updated, the account has not signed up yet or the email doesn't match.
5. Sign out and sign back in. The Admin panel should appear.

Only project owners with database access should grant admin roles. Never add a "make me admin" button to the public app.

## 3. Deploy free using GitHub Pages
1. Create/sign in to GitHub at https://github.com/.
2. Create a new repository, e.g. `attendly-campus`. Do not commit passwords or secret keys.
3. Upload `index.html` to the repository root. You may include `schema.sql` and this README for reference, but the SQL is not run by GitHub Pages.
4. In repository **Settings → Pages**, enable deployment from the `main` branch and `/ (root)` (the labels may vary).
5. Wait for GitHub Pages to provide the public URL.
6. In Supabase Authentication URL settings, add the deployed URL to the allowed site/redirect URLs. Then test account signup, email confirmation, login, and logout.

GitHub Pages hosts the frontend only. Supabase remains responsible for authentication and database. Free-tier quotas and policies may change, so review current provider terms.

## 4. How the portal works
- Students can create their own account, view their own attendance, and export their records.
- New public signups always receive the `student` role.
- Admins can add subjects, view registered student profiles, and mark/delete attendance.
- Attendance percentage is `Present periods / (Present periods + Absent periods) × 100`.
- Leave entries are displayed but excluded from the calculation in this starter.
- Students cannot read other students' attendance through the configured RLS policy.
- Admin role changes happen only in the database by a trusted project owner.

## 5. Important limitations / production checklist
- This is a starter, not a certified college ERP. Validate and test the SQL policies in a non-production project first.
- It does not yet support semester/course sections, class timetables, bulk CSV import, parent accounts, audit history, or formal leave approval.
- Duplicate attendance for the same student/subject/date is not blocked yet; add a unique key or explicit session table before production use.
- Add backups, database monitoring, admin MFA, privacy notice, and institution-approved retention policies before handling real student records.
- If your college needs official attendance, get permission from college administration before publishing or collecting student information.
