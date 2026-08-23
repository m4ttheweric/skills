---
name: matt:wrap-up
description: Use when wrapping up a session, checking in before continuing, or when the user asks what you need from them, what decisions are open, what the next steps are, remaining details, or invokes wrap-up / check-in.
---

# Wrap-up

Please go through any important details, decisions you need me to make, or next steps in a form format.

## Output

The reply is one optional sentence of context, then a form, then stop. Wait for answers before doing more work.

Use this runtime's structured-question tool. Inspect the tool list in this session and call whatever actually presents questions with options. Names vary (`AskUserQuestion`, `AskQuestion`, `ask_user`, and others). Trust the live tool list over any name in this skill.

If this runtime has no such tool, the chat message itself is the form: numbered questions, lettered options, then stop.

If the tool caps how many questions fit in one call, fill the first call and wait. Send the rest after answers return. Don't overflow into a dump, and don't recap leftover questions in the context sentence.

Put every still-open item in the form, one question per item:

| Bucket            | Question is                                          | Options                                                                                       |
| ----------------- | ---------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Important details | a confirmation or pick among facts that still matter | concrete values                                                                               |
| Decisions         | a choice only the user can make                      | the real alternatives, recommended option first and labeled `(Recommended)` when you have one |
| Next steps        | whether or in what order to do remaining agent work  | do now / later / skip                                                                         |

Omit a bucket when it is empty.

You may use either single choice or multiple choice formats to fit the situation as needed.

## Example

Session: local-app HTTPS install. Port, publish, and slug are undecided. `lcl add` and a health check are still left.

Form title: Wrap-up

1. Port: `8787` / `3000`
2. Publish publicly: Yes / No
3. Domain slug: `local-app` / `training`
4. After you answer, I should: run `lcl add` + health check now / wait until you say so

## Common mistakes

- A summary or checklist instead of a form
- Dumping a compact list because the user said be quick
- Putting next steps in prose after the questions
- Asking the user to type `B / slug / both` instead of picking options
- Skipping the form because this isn't the harness you last used
- Recapping leftover questions in the context sentence because the form is full
