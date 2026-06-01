# Terminal Workspace Hugo Theme Design

## Summary

Design a new Hugo theme from scratch for `drpaneas.com` that feels like a retro amber terminal or tmux workspace while remaining fully usable as a normal static blog and fully compatible with Lynx. The theme should feel personal, technical, and text-first rather than like a fake shell application.

The browser experience should present the site as a calm workspace with panes, restrained CRT-inspired styling, and subtle focus-based glow. The underlying HTML must remain semantic and readable without CSS or JavaScript. Lynx should receive the same content structure and navigation paths as graphical browsers, only without the visual framing.

## Goals

- Build a new standalone Hugo theme rather than modifying the existing theme in place.
- Create a retro amber terminal aesthetic with a tmux-like workspace feel.
- Keep the site practical for reading and browsing, not just visually clever.
- Preserve complete compatibility with Lynx and text-first browsing.
- Make the homepage feel personal through a compact banner, quote, and clear browsing entry points.
- Keep the implementation lightweight and maintainable.

## Non-Goals

- Building a fake shell parser in v1.
- Making command input the primary navigation model.
- Creating a client-heavy app shell.
- Requiring JavaScript for navigation or layout.
- Simulating constant CRT motion or heavy retro effects.
- Turning the blog into a dashboard with dense status widgets.

## Chosen Direction

### Overall style

- Hybrid amber terminal
- Iosevka as the primary font
- Browser-only subtle amber background falloff
- Stronger glow only for active or important elements
- No constant sweep animation
- No heavy decorative clutter outside the chosen identity banner and workspace framing

### Workspace model

- The site visually resembles a tmux-like workspace.
- The workspace metaphor is presentation only, not the data model.
- Underneath, pages remain normal Hugo pages with semantic HTML.

### Homepage

The homepage uses a compact workspace layout rather than a long scrolling dashboard:

- Top bar with tmux-like session framing
- Top banner split into two panes:
  - left: ASCII greeting plus compact identity text
  - right: quote pane with:
    - `Hack the Planet`
    - `All that is gold does not glitter, Not all those who wander are lost`
- Wrapped inline tags as quick filters
- Recent posts pane showing only the newest 5 posts
- Clear `more posts ->` path to the full archive
- Preview pane for the selected or featured post

### Identity banner content

The top banner should use the more personal version, not the strictly terminalized one.

Left banner pane:

- ASCII greeting block
- `Hi I'm Panos -> drpaneas`
- `Born in Greece - living in Germany.`
- Emoji-flavored interests line:
  `automation devops kubernetes linux emulation QA SRE hacking astrophysics`
  with the more expressive browser presentation allowed in the banner only

Right banner pane:

- Heading like `quotes / go by`
- `Hack the Planet`
- `All that is gold does not glitter, Not all those who wander are lost`

Emoji are allowed only in the identity banner. The rest of the UI remains terminal-native and text-first.

## Information Architecture

### Homepage structure

The homepage should have four conceptual regions:

1. top status bar
2. identity + quote banner
3. tags / quick filters
4. content row:
   - recent posts
   - preview pane

This keeps the homepage practical even with many posts or many tags.

### Tags and categories

- Tags should be displayed inline and wrapped like text, not as a tall vertical list.
- The homepage should show quick tag filters, not the entire taxonomy tree as a sidebar.
- A clear link to `all tags` should exist.
- Full taxonomy listing can live on dedicated archive/taxonomy pages.

### Posts

- Homepage shows only the latest 5 posts.
- Full post browsing happens on archive/list pages.
- Preview pane on the homepage gives context without requiring the homepage to list everything.

### Article pages

Article pages use immersive terminal article mode:

- the article becomes the dominant content region
- the reading experience feels like opening a file in a focused terminal buffer
- article metadata remains visible near the top
- a breadcrumb + back pattern provides clear return to the workspace/archive

The immersive article page should not trap the user. Returning to posts must always be obvious.

## Templates and Components

The theme should be implemented as a small, explicit set of templates and partials.

### Core templates

- base layout for global shell and page framing
- homepage layout for workspace view
- list/archive layout for post listings
- taxonomy list layout
- single post/page layout
- 404 layout

### Core components

- workspace shell
- top status bar
- banner pane
- quote pane
- tags quick-filter strip
- recent posts pane
- preview pane
- article pane
- breadcrumb/back bar
- post metadata block
- pagination/archive navigation

The theme should favor a small number of reusable pieces instead of one-off page-specific UI.

## Visual Rules

### Color and tone

- amber-on-dark CRT-inspired palette
- dark background with warm text
- restrained contrast choices for long-form reading
- subtle radial falloff in graphical browsers

### Typography

- primary font: Iosevka
- terminal-native text treatment across the UI
- calm line lengths and spacing for readable long posts
- code blocks and inline code receive slightly stronger emphasis

### Code snippet styling

Code snippets should use language-accented terminal blocks.

- code remains real text, never image-based
- all code blocks share one common terminal-style shell
- each language receives a subtle accent color inside that shared shell
- inline code remains simpler and less decorative than full code blocks
- code styling must remain readable without relying on glow alone

Initial language targets:

- bash
- go
- assembly
- c

Recommended direction for accents:

- bash: warm amber or sand-toned accent
- go: cyan or blue accent
- assembly: magenta or purple accent
- c: green or teal accent

The code block treatment may borrow a small amount of visual polish from tools like Ray.so, but it should not look like an exported image card or break the terminal-workspace cohesion.

### Glow behavior

Glow is a progressive enhancement for graphical browsers only.

Strongest glow should apply to:

- active pane titles
- hovered/focused links
- highlighted tags or active filters
- selected post preview
- code blocks and highlighted inline code

Glow should not be globally strong. The page should feel calm and readable.

### Motion

- no constant sweep animation in v1
- no moving scanlines
- no looping CRT effects
- reduced-motion users should get even softer or no enhancement

## Interaction Model

### v1 interaction

Navigation remains standard and link-driven:

- click a tag to filter or browse related content
- click a post to open the article page
- click `more posts ->` to open the archive
- click breadcrumbs or back links to return from article view

### Not in v1

- no `ls` / `cat` parser
- no command prompt navigation
- no fake terminal input field as required navigation

If command-style interaction is ever explored later, it should be a phase-two enhancement on top of a working blog theme.

## Lynx and Fallback Requirements

The theme must be correct before styling is applied.

### Required plain-HTML behavior

- proper headings
- normal links
- normal lists
- readable article structure
- wrapped text
- normal taxonomy navigation
- article pages with breadcrumb return links

### Fallback expectations

- Lynx sees a coherent blog, not broken remnants of a visual shell
- CSS layout may disappear, but information order remains logical
- emoji in the banner may degrade imperfectly, but the text should remain understandable
- browser-only effects must never block reading or navigation
- code blocks must remain readable as normal text even in simple environments

## Accessibility Requirements

- keyboard navigation must remain clear
- active elements need visible focus treatment
- reduced-motion environments should get softer or no enhancement
- all interactive controls must be readable without visual effects
- reading flow must remain clear for assistive technologies and text browsers

## Scalability Considerations

- Homepage avoids giant tag lists by wrapping quick filters inline.
- Homepage avoids giant post lists by showing only the newest 5 posts.
- Dedicated archive/list pages handle the full post history.
- Dedicated taxonomy pages handle full tag/category browsing.
- Preview pane should not depend on loading the whole archive into the homepage.

## Implementation Boundaries

The theme should feel like a terminal workspace, but it must remain a blog theme, not a simulated terminal application.

In practical terms:

- Hugo-native structure first
- CSS presentation second
- optional browser polish last

The implementation must prioritize maintainability over novelty.

## Acceptance Criteria

A successful implementation should satisfy all of the following:

- homepage renders as a compact tmux-like workspace
- top banner includes ASCII intro, personal line, and quote pane
- tags wrap inline and do not create a giant sidebar
- homepage shows top 5 posts only
- `more posts ->` leads to broader archive browsing
- preview pane remains visible on the homepage
- article pages use immersive reading mode
- breadcrumb/back navigation is obvious on article pages
- amber terminal styling and Iosevka are applied consistently
- glow is restrained and strongest only on active elements
- code blocks use shared terminal framing with language-specific accents
- Lynx can browse the site meaningfully without CSS or JavaScript

## Recommendation

Implement the theme in two layers:

1. semantic Hugo theme with correct templates and navigation
2. visual terminal workspace styling and progressive enhancement

That order keeps the project honest, testable, and compatible with text browsers while still delivering the retro browser experience you want.
