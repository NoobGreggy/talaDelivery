# TalaDelivery Admin — AI Coding Rules

## Framework
- Angular 21 with standalone components
- TypeScript strict mode
- Tailwind CSS for all styling

## Angular Rules
- Always use standalone components (no NgModules)
- Use signals for state: signal(), computed(), effect()
- Use input() and output() for component I/O
- Use inject() instead of constructor injection
- Use modern control flow: @if, @for, @switch (never *ngIf, *ngFor, *ngSwitch)
- Use [class.x]="expression" instead of ngClass
- Use [style.x]="expression" instead of ngStyle
- Lazy-load all feature routes
- Never put HTTP requests directly in components — use services
- Use Angular Reactive Forms with typed forms
- Use HTTP interceptors for auth

## Styling Rules
- Use Tailwind CSS utility classes only
- No custom CSS unless absolutely necessary
- No external component libraries
- Follow the design tokens: sky-500 primary, slate-50 background, white surfaces
- Use emerald for success, amber for warning, red for danger

## Architecture Rules
- Component → Feature Service → ApiClientService → Laravel API
- Keep components small and focused
- One component per file
- Feature isolation under src/app/features/
- Shared components under src/app/shared/components/
- Core services under src/app/core/

## Code Style
- No `any` types
- No unnecessary abstractions
- No huge components
- No unnecessary state management libraries
- No comments unless asked
- Use descriptive signal and variable names
- Prefer readonly and immutability

## Accessibility
- All interactive elements must support keyboard navigation
- Use semantic HTML
- Add ARIA labels where needed
- Ensure readable contrast ratios (WCAG AA)

## Testing
- Run `ng build` after changes to verify no compilation errors
- Run `ng test` for unit tests