---
description: 'React 18 standards — hooks, components, state, effects, performance. No React 19 features (pinned via watchlist). Use when writing or reviewing React component code.'
applyTo: '**/*.jsx, **/*.tsx'
---

# ReactJS Development Instructions

React-specific patterns. General clean code, error handling, TypeScript, and commenting are in their own instructions.

## Project Context
- React 18 — not yet upgraded to 19
- Do NOT use React 19 features (use(), useFormStatus, useActionState, useOptimistic, Server Components, ref as prop, context without Provider)
- Functional components with hooks only (no class components)

## Component Design
- Single responsibility — one concern per component
- Composition over inheritance (render props, children, compound components)
- Organize by feature/domain, not by file type
- Keep components small; extract custom hooks for reusable stateful logic

## State Management
- `useState` for local state, `useReducer` for complex state logic
- React Query for server state, Zustand for shared client state
- `useContext` for cross-tree sharing — split contexts to avoid unnecessary re-renders

## Hooks
- `useEffect` with proper dependency arrays; always add cleanup functions
- `useMemo`/`useCallback` only when profiling shows a real perf problem
- `useRef` for DOM access and mutable values that shouldn't trigger re-renders
- Rules of hooks: top level only, never inside conditions/loops

## Performance
- `React.memo` only when profiling shows unnecessary re-renders
- Code splitting with `React.lazy` + `Suspense`
- Virtual scrolling for large lists
- Profile with React DevTools before optimizing

## Accessibility
- Semantic HTML (`<button>`, `<nav>`, `<main>`) — not `<div onClick>`
- Every interactive element must be keyboard-accessible
- All form inputs need `<label>` (use `htmlFor`) or `aria-label`
- `aria-live="polite"` for dynamic content updates; `role="alert"` only for urgent errors
- Color contrast: 4.5:1 normal text, 3:1 large text (WCAG AA)
- Focus management: move focus on route changes/modal opens; return on close
- Test with axe-core and keyboard-only navigation
