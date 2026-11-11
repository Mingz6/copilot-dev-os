---
name: grill-me
description: "Grill a plan until every branch of its decision tree has an answer, up a ladder: the agent grills itself from every source first, then the user, and only for what they can't answer, the colleague or PO who knows. Questions go out in batches, each with a recommended answer. Use when: '/grill-me', 'grill me', 'grill yourself', 'grill the PO', 'ask the team', 'challenge my plan', 'stress-test this idea', 'what am I missing', 'poke holes in this', 'help me think through this', or before any non-trivial feature where requirements feel fuzzy. /long-run uses it."
---

# Grill Me

Find the holes in a plan before anything gets built. Walk every branch of the decision tree (scope, behavior, integration, data, rollout, verification) until each leaf has an answer and a source for it.

## The ladder

Each question climbs only as far as it has to:

| Rung | Who answers | How |
|---|---|---|
| 1. Self | the agent, from sources | code, git history, the database, the tracker, chat and email threads, docs and the web. Technical choices stop here: decide the way a FAANG+ senior engineer would. |
| 2. The user | The user | one batched message; every question carries your recommended answer |
| 3. Colleague | the PO or developer who knows | only what the user answered "don't know" or "ask X"; one message per person; the user sends it |

Never skip a rung. A question that reaches the user says what you already checked. A question that reaches a colleague is one the user couldn't answer.

## Rung 1: grill yourself

1. List every question the plan raises, category by category (below). Three passes at least; each pass looks for what the last one missed.
2. For each question, search before you answer: the code and its git history, the data, the card and its comments, chat and email threads, meeting notes, docs. Quote the source.
3. Sort the results:
   - **Answered by a source** → a decision, with the source
   - **A technical choice** (approach, order, naming, how to test) → decide it yourself, one line of why. It never goes up the ladder.
   - **A business rule, intent or preference nobody wrote down** → rung 2
4. Challenge the plan itself: contradictions between the description, the acceptance criteria, the comments, the code and the data; cases nobody mentioned; whether it solves the actual problem or a symptom.

Inside /long-run this rung runs silently, then the run goes on.

## Rung 2: grill the user

Everything rung 1 couldn't settle goes to the user **in one message**, never one question at a time:

1. Number the questions and group them by topic. Order them along the decision tree, so an answer never makes a later question pointless.
2. Each question gets: your recommended answer and why, what changes if they pick otherwise, and what you checked. Offer lettered options when there are real alternatives.
3. Keep it short. If you're only half-sure a question matters, cut it.
4. Tell them how to answer fast: `1 ok, 2 b, 3 don't know`, or `all recommended`.
5. Follow-ups only for branches their answers opened. Aim for one round, never more than three.

```
Five things I couldn't settle from the code, the ticket or the chat history:

1. Nightly cleanup: delete accounts that have no matching customer record, or leave them? I'd delete (a); leaving them (b) keeps the test accounts people made by hand. Checked: the spec says "remove orphaned accounts" and never defines orphaned.
2. ...

Reply like "1 a, 2 ok, 3 don't know". "Don't know" goes to whoever owns it.
```

## Rung 3: grill a colleague

For each question the user couldn't answer:

1. **Who:** the person they named; otherwise the card's PO, the area owner (CODEOWNERS), or whoever discussed it on the card or in Teams.
2. **One message per person** with every question for them. PO questions go on the ticket and stay non-technical. Developer questions go to chat.
3. **Voice:** the user typing it themselves. First person, short, no bold labels or "Question —" headers, one number at most. Run the anti-AI Density Test; nobody should be able to tell an agent wrote it.
   ```
   Hi Sam, two things on the cleanup job before I finish it.

   1. If someone still has a login but their customer record is gone, should the nightly job delete the login or leave it?
   2. Is it OK if a change in prod takes up to a day to show up in staging?

   Either works for me, I just don't want to guess.
   ```
4. **Show** each draft in full. The user sends it; never message another person yourself.
5. Record who was asked, where and when. When the answer arrives, it becomes a decision with that person as the source.

## Question categories

- **Scope and boundaries:** what's in, what's explicitly out, where this ends and another card begins, who the users are
- **Behavior and edge cases:** empty, enormous or malformed input; the failure mode; concurrency; state left behind by a crash halfway through; permissions
- **Integration and dependencies:** what existing code this touches, other callers and repos, external services that are slow or down
- **Data:** schema changes, migrations, existing rows that don't fit the new rule, backfills, what the real data looks like
- **Rollout:** deploy order, feature flags, which environments, how to roll back, who needs telling
- **Verification:** how you'll know it works (the exact test, the exact click path), and what proves it's still working a week later

## Recording

- The spec's `## Decisions`, or the ticket
- Every answer names where it came from: `AccountRepository.cs:210`, `the user 09-26`, `Sam on the ticket 09-27`

## Ending

When every branch has an answer, write the decisions down as a short Working Contract. Inside /long-run, go build. On its own, show the contract and stop; don't ask "ready to build?".

## Standalone use

`/grill-me` on the user's own plan: rung 1 silently, then rung 2 with everything left, batched. They can say "one at a time" for the classic mode (one question, wait, the next) when they want to think out loud.

## Variants

- **`/grill-me`** — the ladder above, any domain (code, docs, planning, life decisions)
- **`/grill-with-docs`** — the same, but it also updates `CONTEXT.md` (the domain glossary) and proposes ADRs for hard-to-reverse decisions. See `context-glossary.instructions.md` for the CONTEXT.md format.

### /grill-with-docs Additional Behavior

1. **Challenge against the glossary.** If `CONTEXT.md` exists, check every term against it. "Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"
2. **Sharpen fuzzy language.** When a term is vague or overloaded, propose a precise canonical one.
3. **Update CONTEXT.md inline** as each term is settled. Don't batch.
4. **Offer ADRs sparingly**: only when a decision is hard to reverse, surprising without context, and the result of a real trade-off. Format: the `docs/adr/` convention in `sdd.instructions.md`.
