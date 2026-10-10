# Brief: file a GitHub sensitive-data purge request

Fill every `<...>` before dispatching. The user who owns the repo asked for
this ticket.

---

File a GitHub Support ticket asking GitHub to purge cached views of removed
commits, in the user's real logged-in Chrome via Fast Browser.

If a sign-in, 2FA, passkey or CAPTCHA screen appears that the existing
session does not get past, stop and report what is on screen. Never type
credentials. If the first Fast Browser call fails with `SIDECAR_LOST`, run
`browser_tabs` list and retry once.

Work in a new tab. Run the whole form as one `browser_run_code_unsafe` flow
where you can, with waits baked in:

1. Open `https://support.github.com/contact` (it redirects to
   `help.github.com`). On "Select an account" pick
   `<owner account or organization>`; when two entries share that name, take
   the one listed under **Organization**. Click **Continue**.
2. Click **Repositories** (a popular-product button).
3. Select the radio **Repository features** (not **Deletes**). Tick Feature
   type **Branches**. Fill:
   - **Subject**: `Purge cached views of removed commits in <owner>/<repo>`
   - **Please describe your repository issue**: the body below
   - the repository URL field: `https://github.com/<owner>/<repo>`

   Click **Continue**.
4. The Solution page shows "Analyzing your support request…" first; wait for
   **Continue to create a ticket**, then click it.
5. The Create a ticket page shows only From, CCs and Type of Issue; that is
   expected. Read `sessionStorage` keys
   `contact-next:repositories-form:contact_next[subject]` and
   `contact-next:repositories-form:contact_next[description]`. Both must hold
   the text from step 3; if not, start again at step 1 in this tab. Set
   **Type of Issue** to **General question or feature request**.
   <SUBMIT: "Click **Submit**." for a real ticket, or "Do NOT click Submit; stop here and report." for a dry run>
6. After submitting: click **View tickets**, open the newest ticket, and
   confirm its page shows the subject and the first sha.

Body:

```
Data that should not be public was committed to <owner>/<repo> and has been removed from history. The default branch<, and tag ...> were rewritten without it and force-pushed; no branch or tag in the repository contains these commits anymore.

Please dereference these commits, remove their cached views, and run a garbage collection so they cannot be fetched by sha:
- <sha 1> (<the commit that added the data>)
- <sha 2> (<what pointed at it: an old tag commit, an old pull request head>)

File path(s): <path>
Affected pull requests whose refs still point at those commits: <#N, #M>
```

Do not add any other text, attachments or personal details. Return a short
report: whether it submitted, the ticket number and URL, what the step 5
`sessionStorage` check found, and anything that blocked you.
