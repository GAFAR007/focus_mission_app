# Focus Mission - Frontend Agent Rules

This frontend serves ADHD learners.

Design is NOT optional.
Engagement is core functionality.

If a proposed UI choice increases cognitive load, simplify it.

---

## 0) Purpose

Create an engaging, gamified learning experience where:

- Students never face blank pages
- Progress builds visibly
- Screens feel rewarding
- Tasks stay small and achievable
- The next action is always obvious

---

## 1) UI Principles (ADHD-FIRST)

Every screen must:

- Show one primary action
- Limit visible options
- Show progress clearly
- Show XP or completion feedback
- Keep copy short and concrete
- Avoid clutter

Never:

- Show too many competing buttons
- Lead with dense paragraphs
- Use tiny fonts or tiny tap targets
- Hide the primary CTA
- Force the learner to infer what to do next

If the first three seconds of a screen do not tell the learner what to do, the screen is too complicated.

---

## 2) Visual Rules

Required visual direction:

- Border radius of 20 or more by default
- Large padding and breathing room
- Bold headings
- Soft gradients
- Friendly avatars or supportive illustration
- Consistent rounded card layout
- Clear contrast and readable hierarchy

Avoid:

- Sharp material defaults
- Flat grey boxes
- Text-heavy panels
- Multi-column mobile layouts
- Mixed visual styles on the same screen

Student, teacher, and mentor screens can vary in tone, but must still feel like the same product.

---

## 3) UI Consistency Rule

Use shared theme tokens and shared widgets whenever possible.

Keep consistency across:

- Button treatment
- Card shape
- Spacing rhythm
- Progress indicators
- Reward styling
- Empty-state presentation

Do not create one-off visual systems inside feature folders unless the design language truly needs a new pattern.

---

## 4) Screen Responsibility Rule

Each screen must have one clear job.

Examples:

- Login -> choose role
- Home -> show today's mission
- Mission -> display the current block set
- Result -> show progress and reward

Do NOT merge unrelated flows into mega-pages.
Do NOT stack too many decisions on one screen.

---

## 5) Clean Architecture-ish Frontend Separation

Keep responsibilities separate:

- Screens and widgets handle presentation
- Providers or controllers handle screen state
- Services handle API access
- Models represent app/domain data
- Theme and shared widgets define reusable UI rules

Do not:

- Call HTTP clients directly from widget trees
- Bury business rules inside paint-heavy widgets
- Duplicate API logic across features

All API access must go through a frontend service layer.

---

## 6) Dynamic Block Rendering

Learning blocks must render by type, not by subject-specific hardcoding.

Supported block types should remain reusable:

- multipleChoice
- fillGap
- dragOrder
- sentenceBuilder

Rules:

- Rendering logic must be extensible
- Block UI should share a consistent shell
- Subject-specific content should plug into the same interaction model

Never hardcode mission UI around a single subject if the block system is meant to scale.

---

## 7) ADHD Engagement Enhancers

Encourage:

- Micro animations
- XP count-up moments
- Confetti or reward burst on completion
- Streak indicators
- Progress percentage
- Unlock visuals for newly available content

Avoid:

- Long delays
- Heavy transitions
- Motion that distracts from the task
- Reward effects that slow the next action

Reward must feel immediate and light.

---

## 8) Accessibility and Cognitive Load Rules

Prioritize:

- Obvious hierarchy
- Short labels
- Consistent status colors
- Readable text sizes
- Step-by-step flows
- Strong contrast

Avoid:

- Ambiguous icon-only actions
- Long forms without chunking
- Walls of text
- Too many simultaneous states

This app should help attention, not compete for it.

---

## 9) Documentation Rules (MANDATORY)

Every new or substantially modified widget, screen, service, provider, or model file must include:

```text
/**
 * WHAT:
 * WHY:
 * HOW:
 */
```

Add WHY comments for:

- State transitions
- UX constraints
- Fallback UI branches
- Progress calculations
- Animation decisions

No silent logic.

If state changes affect learner flow, document why the update happens.

---

## 10) Prevent Overengineering

Avoid:

- Premature reusable systems with no second consumer
- Deep widget abstraction for tiny differences
- Complex state management without a real problem
- Feature-wide rewrites for visual polish alone

Prefer a small, readable component that fits the current product over an overly generic framework.

---

## 11) Prevent Chaotic Refactors

Do not:

- Reorganize the feature tree casually
- Replace shared widget patterns without reason
- Rewrite navigation, theming, or state patterns in unrelated tasks
- Mix broad cleanup into UX tickets

Refactors must be:

- Scoped
- Behavior-aware
- Documented
- Approved when structural

---

## 12) Frontend File Placement

Frontend source of truth:

```text
focus_mission_app/lib/
├── AGENTS.md
├── core/
│   ├── constants/
│   ├── theme/
│   └── utils/
├── features/
├── shared/
└── main.dart
```

Respect this structure:

- Shared design tokens live in `core/theme`
- Reusable UI belongs in `shared/widgets`
- Features stay grouped by role or flow

---

## 13) STOP Conditions

STOP and simplify if UI starts becoming:

- Text-heavy
- Multi-column complex
- Form-heavy
- Admin-dashboard styled
- Visually inconsistent
- Hard to scan in a few seconds

This product is for attention-sensitive learners first.
