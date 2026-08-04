# 04 — Component Library

> A screen is assembled from components. It never contains a raw `Container`, a raw `<div>` with styling, or a hand-rolled input. If a screen needs something the library does not have, the library grows — the screen does not improvise.

This is the second half of the "one place to change" requirement. Tokens fix the values; components fix the *shapes*. Together they mean a modal is the same height, the same padding, the same corner radius, and the same close-button position on every screen in both apps.

## 1. Principles

**P-C1 — Identical names and identical props across platforms.** `Button(variant: danger, size: md, loading: true)` in Dart and `<Button variant="danger" size="md" loading />` in TSX. A designer or engineer who learns the API once knows both apps. Divergence is a bug.

**P-C2 — Variants are semantic, sizes are enumerated.** `variant` names an intent (`accent`, `danger`, `ghost`), never an appearance (`purple`, `outlined-thin`). `size` is a closed enum, never a number. No component accepts `height`, `padding`, `fontSize`, or `color`.

**P-C3 — Variant implementation is a lookup table.** Every component resolves its variant through a `Map<Variant, VariantStyle>` (Dart) or `Record<Variant, string>` (TS) that reads from the color family rungs. Adding a variant is adding a row. This is the reference project's pattern and it is why its components stayed consistent.

**P-C4 — One styling escape hatch, applied last.** Every component accepts a single `class`/`className` (web) or `margin` (Flutter) override for *positioning only*, merged last so the caller wins. Never a color, never a size.

**P-C5 — Controlled and uncontrolled both work.** Interactive components accept a value plus a change callback. Flutter uses a controller or `value` + `onChanged`; web uses `value` + `onChange` with an optional `defaultValue`.

**P-C6 — Callbacks, not events.** Props are `onX` callbacks. No `createEventDispatcher`-style forwarding, no custom event buses.

**P-C7 — Accessible by construction.** A component that cannot be operated by keyboard or announced by a screen reader is not finished. See §8.

## 2. Inventory

Twenty-four primitives and twelve domain components. This is the complete v1 set; anything not here does not exist yet.

### Primitives — `components/`

| Component | Purpose |
|---|---|
| `Button` | Primary action control. 5 variants × 3 sizes, loading and icon slots. |
| `IconButton` | Icon-only action. Enforces the 44pt touch target regardless of icon size. |
| `TextButton` | Low-emphasis inline action, no border or fill. |
| `Input` | Single-line text field. Label, hint, error, prefix/suffix, clear. |
| `TextArea` | Multi-line text field with auto-grow and character counter. |
| `Select` | Single-choice dropdown with optional search. |
| `MultiSelect` | Multi-choice dropdown with checkboxes and a collapsed summary. |
| `Checkbox` | Boolean with optional label. |
| `Radio` / `RadioGroup` | Exclusive choice within a group. |
| `Switch` | Immediate-effect boolean toggle. |
| `Chip` | Compact selectable or removable tag. Used for interests and communities. |
| `Badge` | Non-interactive status label. Used for story visibility and vault state. |
| `Avatar` | Circular identity image with generated-avatar and initial fallbacks. |
| `Card` | The standard content surface. |
| `Modal` | Centered dialog with scrim, focus trap, and Escape handling. |
| `Sheet` | Bottom sheet with drag handle and snap points. The mobile-primary overlay. |
| `Drawer` | Edge-anchored panel. Web navigation and filter panels. |
| `Tooltip` | Hover and focus hint. |
| `Toast` / `Toaster` | Transient feedback, imperatively triggered. |
| `Tabs` | Segmented view switcher with an animated indicator. |
| `Divider` | Horizontal or vertical rule. |
| `Skeleton` | Loading placeholder matching final content geometry. |
| `Loader` | Indeterminate spinner, inline or full-screen. |
| `EmptyState` | Icon, title, description, and optional action for empty or error views. |
| `ListTile` | Standard row: leading, title, subtitle, trailing. |
| `AppBar` | Screen header with back affordance, title, and actions. |
| `BottomNav` | Mobile primary navigation. |
| `AppIcon` | Renders a generated icon at a token size with a token color. |
| `AppNetworkImage` | Remote image with loading, error, and fallback states. |
| `Pressable` | Bare interaction wrapper providing ripple, hover, focus ring, and disabled semantics. Every other interactive component composes it. |

### Domain components — `components/domain/` (Flutter) and `features/*/…` on web

| Component | Purpose |
|---|---|
| `StoryCard` | Feed representation of a story: author, excerpt, community, reactions. |
| `StoryHeader` | Author row with avatar, display name, timestamp, visibility badge. |
| `StoryBody` | Renders story text in the `reading` type style with the max-width cap. |
| `StoryComposer` | The write surface: title, body, community picker, visibility picker. |
| `VisibilityPicker` | Selects `draft` / `private` / `public` / `scheduled`, with schedule time. |
| `ReactionBar` | Like, comment count, share. |
| `CommentTile` | One comment with author, body, and relative time. |
| `CommentComposer` | Inline comment input. |
| `CommunityCard` | Community name, description, member count, join control. |
| `InterestPicker` | Chip grid for selecting interests during onboarding. |
| `VaultTile` | One vault item: type icon, encrypted-name display, size, lock state. |
| `PasscodePad` | Numeric passcode entry with masked display and shake-on-error. |
| `TicketStatusCard` | Ticket state, timeline, and next action. |

## 3. Component APIs

Full signatures for the components whose contract matters most. The pattern shown here applies to all of them.

### Button

```dart
enum ButtonVariant { accent, neutral, danger, ghost, solid }
enum ButtonSize { sm, md, lg }

class Button extends StatelessWidget {
  const Button({
    super.key,
    required this.label,
    required this.onPressed,          // null ⇒ disabled
    this.variant = ButtonVariant.accent,
    this.size = ButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
    this.margin,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final AppIconData? leadingIcon;
  final AppIconData? trailingIcon;
  final bool loading;
  final bool fullWidth;
  final EdgeInsets? margin;
  final String? semanticLabel;
}
```

```tsx
type ButtonVariant = 'accent' | 'neutral' | 'danger' | 'ghost' | 'solid';
type ButtonSize = 'sm' | 'md' | 'lg';

interface ButtonProps extends Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, 'className'> {
  label: string;
  variant?: ButtonVariant;
  size?: ButtonSize;
  leadingIcon?: AppIconName;
  trailingIcon?: AppIconName;
  loading?: boolean;
  fullWidth?: boolean;
  className?: string;   // positioning only
}
```

Variant resolution, showing P-C3 concretely:

```dart
final _variantStyles = <ButtonVariant, _ButtonStyle>{
  ButtonVariant.accent: _ButtonStyle.family((c) => c.accent),
  ButtonVariant.neutral: _ButtonStyle.family((c) => c.neutral),
  ButtonVariant.danger: _ButtonStyle.family((c) => c.danger),
  ButtonVariant.ghost: _ButtonStyle.transparent(),
  ButtonVariant.solid: _ButtonStyle.filled((c) => c.accent),
};
```

`_ButtonStyle.family` reads `subtle` for background, `muted` for border, `base` for label, and `hover` for the pressed state — the four rungs from [03-design-tokens.md](03-design-tokens.md). `filled` inverts: `base` for background, `contrast` for label. Five variants, two style strategies, zero hardcoded colors.

Size resolution reads `size.control.sm/md/lg` for height, a spacing token for horizontal padding, and `labelMd`/`labelLg` for the text style. Nothing is a literal.

**`loading` replaces the label with a spinner while preserving the button's measured width**, so the layout does not jump — a small detail that is invisible when right and obvious when wrong.

### Input

```dart
class Input extends StatelessWidget {
  const Input({
    super.key,
    this.controller,
    this.value,
    this.onChanged,
    this.label,
    this.hint,
    this.helper,
    this.error,                       // non-null ⇒ error styling + announced
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscure = false,
    this.clearable = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.autofocus = false,
    this.size = InputSize.md,
    this.margin,
  });
}
```

```tsx
interface InputProps {
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
  label?: string;
  hint?: string;
  helper?: string;
  error?: string;
  prefixIcon?: AppIconName;
  suffixIcon?: AppIconName;
  onSuffixClick?: () => void;
  type?: 'text' | 'password' | 'email' | 'number';
  clearable?: boolean;
  disabled?: boolean;
  readOnly?: boolean;
  maxLength?: number;
  autoFocus?: boolean;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}
```

Notes on the contract:

- **`error` is a string, not a boolean.** A boolean error tells the user something is wrong without telling them what. The string is displayed and announced via `aria-describedby` / Flutter `Semantics`.
- **`helper` and `error` occupy the same slot**, with `error` winning. This keeps the field's total height stable whether or not validation has fired.
- The reference's input had **no prop types at all** and used prop spreading, which meant no autocomplete and no compile-time safety. Every prop here is typed and explicit.

### Modal

```dart
class Modal extends StatelessWidget {
  const Modal({
    super.key,
    required this.child,
    this.title,                       // String or Widget
    this.titleWidget,
    this.leadingIcon,
    this.size = ModalSize.md,
    this.showClose = true,
    this.dismissible = true,          // scrim tap + Escape
    this.onClose,
    this.actions,                     // pinned footer
    this.scrollable = true,
  });
}

// Imperative helper — the normal way to open one
Future<T?> showAppModal<T>(BuildContext context, {required WidgetBuilder builder, ...});
```

```tsx
interface ModalProps {
  open: boolean;
  onClose: () => void;
  title?: string | React.ReactNode;
  leadingIcon?: AppIconName;
  size?: 'sm' | 'md' | 'lg';
  showClose?: boolean;
  dismissible?: boolean;
  actions?: React.ReactNode;
  scrollable?: boolean;
  children: React.ReactNode;
}
```

`size` maps to `size.modal.widthSm/widthMd/widthLg`, clamped to the viewport minus `space6` on each side. No caller passes a width.

**What this fixes from the reference:** its modal accepted a free-form `width` string, doubled as a dropdown and popover via a six-value `position` prop, had no focus trap, and did not restore focus on close. Here, `Modal` is a dialog and only a dialog; dropdown positioning belongs to `Select` and `Tooltip`. Focus trap and focus restoration are built in, and `aria-labelledby` is wired to the title automatically.

### Sheet

The mobile-primary overlay. Most flows that would be a modal on desktop are a sheet on phone.

```dart
class Sheet extends StatelessWidget {
  const Sheet({
    super.key,
    required this.child,
    this.title,
    this.snapPoints = const [0.5, 0.92],   // fractions of screen height
    this.initialSnap = 0,
    this.showHandle = true,
    this.dismissible = true,
    this.onClose,
    this.actions,
  });
}
```

Drag-to-dismiss, snap points, top corners at `radius.xl`, and a handle sized from `size.sheet.*`. Respects `maxHeightPercent` so a sheet never fully covers the screen — the visible sliver of context behind it is what tells the user they can dismiss it.

The reference had **no sheet or drawer component**; both of its drawer-like surfaces were hand-rolled `<aside>` elements with duplicated scroll-lock and transition logic. One component, used everywhere.

### Toast

Imperative API over a singleton store, mounted once at the app root. Directly adapted from the reference's `toast.svelte.ts`, which was the cleanest piece of that library.

```dart
enum ToastKind { neutral, success, warning, danger }

class AppToast {
  static void show(String message, {String? description, ToastKind kind, Duration? duration, ToastAction? action});
  static void success(String message, {String? description});
  static void warning(String message, {String? description});
  static void danger(String message, {String? description});
  static void dismiss(int id);
}
```

```ts
toast.show(message, options);
toast.success(message, options);
toast.warning(message, options);
toast.danger(message, options);
toast.dismiss(id);
```

Defaults: `motion.duration` is not used here — visible duration is 4000 ms, or sticky when `duration` is zero or negative. Position is top-center on mobile, top-right on web; it is **not** a per-call option, because a toast appearing in a different place each time is disorienting. The reference supported six positions per toast, which is five more than any product needs.

Max three visible; further toasts queue. `role="status"` with `aria-live="polite"`, or `SemanticsService.announce` on Flutter.

### Badge — the domain-driven case

```dart
enum BadgeVariant { neutral, accent, success, warning, danger, draft, private, public, scheduled, vaultLocked, vaultHidden }
```

The last five read from the `story.*` and `vault.*` domain tokens rather than the generic families. This is the same idea as the reference treating `bullish`/`bearish` as first-class tokens distinct from `success`/`error`: **when a color carries domain meaning, it gets a domain name.** A story's `public` badge is green, but it is not "success" — and if we ever change the public-story color, we must not accidentally change every success state with it.

### VaultTile and PasscodePad — security-relevant components

`VaultTile` never renders a plaintext filename from an unopened item. The real name lives inside the encrypted metadata blob; until the vault is unlocked, the tile shows a type icon, size, and date only. This is enforced by the component's API — it accepts a `VaultItem` whose `displayName` is `String?` and is null while locked, so a caller cannot accidentally leak it.

`PasscodePad` has three non-obvious requirements, all enforced in the component:
- **No clipboard.** Paste is disabled; a passcode pasted from a notes app is a passcode stored in plaintext.
- **No autofill, no keyboard suggestions, no screenshot in the recents thumbnail** (`FLAG_SECURE` on Android, screen-capture obscuring on iOS).
- **Failure feedback carries no information.** A wrong passcode shakes and says "Incorrect passcode" — never "3 attempts remaining" beyond the final warning, and never "no item found with that label", which would confirm a label's existence.

## 4. Composition rules

**Screens compose components; they do not style.** A screen file contains layout (`Column`, `Row`, `Padding` with token values) and components. If a screen contains a `BoxDecoration`, that is a missing component.

**`Pressable` is the interaction floor.** Every tappable surface — buttons, list rows, chips, cards — wraps `Pressable`, which provides the hover overlay (`opacity.hover`), press overlay (`opacity.press`), focus ring (`border.focusRing` in `color.border.focus`), disabled opacity, minimum touch target, and correct semantics. Centralizing this is why focus rings will actually be consistent.

**Loading has three shapes and they are not interchangeable:**

| Shape | Use when |
|---|---|
| `Skeleton` | The content's geometry is known. Feeds, lists, cards. Always preferred. |
| `Loader` inline | A specific control is working. Inside `Button` via `loading`. |
| `Loader` full-screen | Blocking, unavoidable, and brief. Vault unlock, app boot. Nothing else. |

A spinner where a skeleton belongs makes an app feel slower than it is. Feeds use skeletons, always.

**Empty states are never bare.** Any list that can be empty renders `EmptyState` with an icon, a sentence explaining why it is empty, and — where an action exists — a button. "No stories yet" alone is a dead end; "No stories yet. Your first one can be a draft nobody sees." is an invitation.

## 5. Icons

### One system, one contract

The reference ran **three** parallel icon systems: 18 local Svelte components, a CDN-loaded Material Symbols font referenced by string, and raw SVG `path` strings passed as props. Three vocabularies, one of them render-blocking and 200 KB+, one of them completely untyped. We run one.

```
packages/icons/
├── svg/                       Source of truth — one optimized SVG per icon
│   ├── lock.svg
│   ├── vault.svg
│   ├── story-draft.svg
│   └── ...
├── generate.ts                Emits both platforms
└── icons.json                 Registry: name, category, keywords
```

Source SVG requirements, validated by the generator:

1. `viewBox="0 0 24 24"`, no `width`/`height` attributes.
2. All strokes and fills are `currentColor`. A hard-coded color fails the build.
3. `stroke-width="1.75"`, `stroke-linecap="round"`, `stroke-linejoin="round"` — one visual language across the set.
4. No `<style>` blocks, no `id` attributes (they collide when inlined), no transforms baked in.
5. Optimized with SVGO before commit.

### Generated output

**Flutter** — `app/lib/gen/icons.g.dart` produces a typed registry, and the SVGs are copied into `assets/icons/`:

```dart
// GENERATED FILE — DO NOT EDIT.
class AppIcons {
  static const lock = AppIconData('lock');
  static const vault = AppIconData('vault');
  static const storyDraft = AppIconData('story_draft');
  // ...
  static const Map<String, AppIconData> byName = { /* ... */ };
}
```

Rendered through the one component that may touch `flutter_svg`:

```dart
AppIcon(AppIcons.lock, size: IconSize.md, color: context.tokens.color.vault.locked)
```

`AppIcon`'s only props are `size` (a token enum) and `color` (a token color). It cannot be given a raw dimension.

**Web** — `web/src/gen/icons/*.tsx` produces per-icon components via SVGR, tree-shaken by the bundler:

```tsx
<AppIcon name="lock" size="md" className="text-vault-locked" />
```

Color comes from the CSS `color` property through `currentColor`, exactly as in the reference's icon contract — which was the one part of its icon story that was right.

### Categories

| Category | Examples |
|---|---|
| Navigation | `home`, `search`, `bell`, `user`, `menu`, `chevron-*`, `arrow-*`, `close` |
| Story | `story-draft`, `story-private`, `story-public`, `story-scheduled`, `pencil`, `clock` |
| Social | `heart`, `heart-filled`, `comment`, `share`, `users`, `user-plus`, `user-check` |
| Vault | `vault`, `lock`, `unlock`, `eye`, `eye-off`, `key`, `shield`, `file-*`, `upload`, `download` |
| Feedback | `check-circle`, `alert-circle`, `alert-triangle`, `info`, `loader` |
| Settings | `settings`, `palette`, `mail`, `device`, `log-out`, `trash` |

## 6. Images and assets

### Bundled assets

Flutter generates `app/lib/gen/assets.g.dart` from the `assets/` tree, so every reference is compile-checked:

```dart
Image.asset(AppAssets.images.onboardingWelcome)
```

A missing or renamed file becomes a compile error rather than a runtime blank. Web imports assets directly from `public/` or via the bundler, typed through a small `AppImages` map so the same discipline holds.

### Remote images

Exactly one component, on each platform, is allowed to load a remote image. It handles the full lifecycle so no call site reimplements it:

```dart
AppNetworkImage(
  url: story.coverUrl,
  fallbackText: story.authorDisplayName,   // renders initials when there is no image
  shape: ImageShape.rounded,               // circle | rounded | square
  size: AvatarSize.md,                     // or explicit token-derived constraints
  blurHash: story.coverBlurHash,
)
```

Behaviour: `Skeleton` while loading, `blurHash` placeholder when available, initials on error or empty URL, `cached_network_image` for disk caching, `loading="lazy"` and `decoding="async"` on web.

This consolidates what the reference implemented **twice** — once in `SvaKoshAvatar` and again in `SymbolImage`, with the same image-then-initials fallback logic duplicated. `Avatar` here is a thin wrapper over `AppNetworkImage` that fixes the shape to a circle and the fallback to initials.

### Avatars are a special case

Per **P4**, users cannot upload a profile photo. Avatars are generated from a server-issued `avatar_seed` — a deterministic identicon-style illustration, or an AI-generated abstract portrait produced at signup. The client renders from the seed and caches the result. There is no upload path in the API, so there is no code path through which a real face can enter the system.

`Avatar` therefore takes an `avatarSeed`, not a URL:

```dart
Avatar(seed: user.avatarSeed, size: AvatarSize.md, fallbackText: user.displayName)
```

### Vault media

Vault thumbnails are decrypted on-device and held **in memory only**. They are never written to the standard image cache, because `cached_network_image`'s disk cache is readable by anything with filesystem access. `AppNetworkImage` refuses vault URLs; a separate `VaultImage` component handles decrypt-and-render with an explicit in-memory-only cache that is cleared when the vault locks.

## 7. Copy and microcopy

Copy is a component-adjacent concern and lives in one place per platform (`core/constants/strings.dart`, `lib/copy/*.ts`), never inline in a widget. Rules that matter specifically for this product:

- **Never blame the user.** "That username is taken" not "Invalid username".
- **Never expose internals.** No status codes, no exception names, no collection names in user-facing text.
- **Say what happens next.** "OTP sent. Check your email — the code expires in 10 minutes."
- **Security copy is plain, not scary.** "Only you can open this. We cannot." beats "AES-256-GCM encrypted".
- **Destructive copy names the consequence.** Never "Are you sure?" — always "Resetting your password will permanently delete your vault. This cannot be undone."
- **Complete sentences with terminal punctuation**, matching the backend's message convention in [08-api-contract.md](08-api-contract.md).

## 8. Accessibility baseline

Every component ships meeting all of these. This is a definition-of-done item, not a follow-up ticket.

| Requirement | Detail |
|---|---|
| Contrast | Body and label text ≥ 4.5:1 against its surface; large text and icons ≥ 3:1. Verified per theme by a CI script that walks the token pairs. |
| Touch targets | ≥ 44×44 logical px, enforced centrally in `Pressable`. |
| Focus visible | Every interactive element renders a `border.focusRing` ring on keyboard focus. Never `outline: none` without a replacement. |
| Focus management | `Modal`, `Sheet`, and `Drawer` trap focus while open and restore it to the trigger on close. |
| Keyboard operation | `Select`/`MultiSelect` support arrow keys, Home/End, type-ahead, Enter, and Escape. `Tabs` supports arrow navigation. |
| Semantics | Icon-only controls have `semanticLabel`/`aria-label`. `Switch` uses `role="switch"` + `aria-checked`. Dropdowns use `role="listbox"`/`option` + `aria-expanded`. Toasts use `aria-live="polite"`. |
| Labels | Every field is programmatically associated with its label; `error` is wired to `aria-describedby` / `Semantics.hint`. |
| Text scaling | Layouts survive 160% text scale without clipping or overlap. |
| Reduced motion | All transitions collapse to `instant` when the OS requests it. |
| Screen reader flow | Story cards announce as a single unit with author, community, and excerpt — not as six unrelated fragments. |

The reference project got a good half of this (`role="switch"`, `aria-modal`, Escape handling, `aria-hidden` on decorative SVGs) and missed the rest: no focus trap, no focus restoration, tooltips that were hover-only, and dropdowns with no keyboard navigation or listbox semantics. Those four gaps are the ones most likely to recur, so they are called out explicitly in the component review checklist.

## 9. Definition of done for a component

A component is not mergeable until all of it is true:

1. Same name, same props, same variant and size enums on both platforms.
2. Zero raw values — passes `design-guard`.
3. Every variant and size rendered in the gallery (a `/gallery` route on web, a debug screen in Flutter), in every theme.
4. Keyboard-operable and screen-reader-announced per §8.
5. Loading, empty, error, and disabled states defined where applicable.
6. Widget/unit test covering variant resolution and the primary interaction.
7. Survives 160% text scale.
8. No new dependency added for it.
