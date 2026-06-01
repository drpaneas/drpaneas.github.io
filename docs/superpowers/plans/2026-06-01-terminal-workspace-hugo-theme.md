# Terminal Workspace Hugo Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new Hugo theme for `drpaneas.com` that looks like a retro amber terminal/tmux workspace in graphical browsers, stays practical for browsing and reading, and remains fully usable in Lynx.

**Architecture:** Implement the theme as a new standalone Hugo theme under `themes/terminal-workspace/`, keeping semantic HTML and Hugo-native navigation as the foundation. Add the tmux/workspace presentation and restrained browser-only enhancements on top via CSS, with immersive article pages and a compact workspace homepage.

**Tech Stack:** Hugo templates, Hugo taxonomies/lists/single layouts, CSS, Hugo config in `config.toml`, built-in syntax highlighting with theme CSS overrides

---

## Planned File Structure

### Modify

- `config.toml` - switch to the new theme and add terminal-workspace params

### Create

- `themes/terminal-workspace/theme.toml` - Hugo theme metadata
- `themes/terminal-workspace/layouts/_default/baseof.html` - shared page shell
- `themes/terminal-workspace/layouts/index.html` - homepage workspace
- `themes/terminal-workspace/layouts/_default/list.html` - archive/list pages
- `themes/terminal-workspace/layouts/_default/terms.html` - taxonomy overview pages
- `themes/terminal-workspace/layouts/_default/single.html` - immersive article page
- `themes/terminal-workspace/layouts/404.html` - simple not-found page
- `themes/terminal-workspace/layouts/partials/topbar.html` - tmux-like status bar
- `themes/terminal-workspace/layouts/partials/banner.html` - ASCII intro + quote pane
- `themes/terminal-workspace/layouts/partials/tag_filters.html` - wrapped inline tags
- `themes/terminal-workspace/layouts/partials/recent_posts.html` - homepage top-5 post list
- `themes/terminal-workspace/layouts/partials/post_preview.html` - homepage preview pane
- `themes/terminal-workspace/layouts/partials/post_meta.html` - post metadata block
- `themes/terminal-workspace/layouts/partials/breadcrumb.html` - article breadcrumb + back
- `themes/terminal-workspace/assets/css/main.css` - complete theme styling

### Verification Targets

- Local build output under a temp destination such as `/tmp/terminal-workspace-build`
- Lynx dump of generated `index.html`
- Lynx dump of one generated article page

## Task 1: Theme Scaffold And Config

**Files:**
- Create: `themes/terminal-workspace/theme.toml`
- Modify: `config.toml`
- Test: local Hugo build from repo root

- [ ] **Step 1: Capture the current failing baseline**

Run:

```bash
hugo
```

Expected:

```text
FAIL because the current `m10c` theme is incompatible with the installed Hugo version.
```

- [ ] **Step 2: Create the new theme metadata**

Create `themes/terminal-workspace/theme.toml`:

```toml
name = "terminal-workspace"
license = "MIT"
licenselink = "https://github.com/drpaneas/drpaneas.github.io"
description = "Retro terminal workspace Hugo theme for drpaneas.com"
homepage = "https://drpaneas.com"
tags = ["blog", "retro", "terminal", "tmux", "amber", "lynx"]
features = [
  "workspace homepage",
  "immersive article layout",
  "lynx-friendly semantic HTML",
  "language-accented code blocks"
]
min_version = "0.160.0"

[author]
  name = "Panos Georgiadis"
  homepage = "https://drpaneas.com"
```

- [ ] **Step 3: Switch Hugo to the new theme and add theme params**

Modify `config.toml`:

```toml
baseurl = "https://drpaneas.com"
title = "drpaneas"
languageCode = "en-us"
theme = "terminal-workspace"
paginate = 18

[menu]
  [[menu.main]]
    identifier = "home"
    name = "Home"
    url = "/"
    weight = 1
  [[menu.main]]
    identifier = "tags"
    name = "Tags"
    url = "/tags/"
    weight = 2
  [[menu.main]]
    identifier = "about"
    name = "About"
    url = "/about/"
    weight = 3

[params]
  author = "Panos Georgiadis"
  description = "Not all those who wander are lost"

  [params.terminal_workspace]
    identity_ascii = """
 ____  ____  ____   __   __ _  ____   __   ____
(    \\(  _ \\(  _ \\ / _\\ (  ( \\(  __) / _\\ / ___)
 ) D ( )   / ) __//    \\/    / ) _) /    \\\\___ \\
(____/(__\\_)(__)  \\_/\\_/\\_)__)(____)\\_/\\_/(____/
"""
    identity_title = "Hi I'm Panos -> drpaneas"
    identity_subtitle = "Born in Greece - living in Germany."
    identity_interests = "💻 automation 🚀 devops ☸ kubernetes 🐧 linux 🕹️ emulation 🧐 QA 🖥 SRE 🦊 hacking 🧑‍🚀 astrophysics"
    quote_heading = "quotes / go by"
    quote_tagline = "Hack the Planet"
    quote_text = "All that is gold does not glitter, Not all those who wander are lost"
    home_post_limit = 5
    all_posts_label = "more posts ->"
    all_tags_label = "all tags ->"
```

- [ ] **Step 4: Add a minimal base layout so Hugo can render with the new theme**

Create `themes/terminal-workspace/layouts/_default/baseof.html`:

```html
<!doctype html>
<html lang="{{ .Site.LanguageCode | default "en-us" }}">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{{ if .IsHome }}{{ .Site.Title }}{{ else }}{{ .Title }} | {{ .Site.Title }}{{ end }}</title>
    <meta name="author" content="{{ .Site.Params.author }}" />
    <meta name="description" content="{{ if .IsHome }}{{ .Site.Params.description }}{{ else }}{{ .Description | default .Site.Params.description }}{{ end }}" />
    {{ $style := resources.Get "css/main.css" | minify | fingerprint }}
    <link rel="stylesheet" href="{{ $style.RelPermalink }}" />
  </head>
  <body>
    <main>
      {{ block "main" . }}{{ .Content }}{{ end }}
    </main>
  </body>
</html>
```

- [ ] **Step 5: Add a temporary minimal stylesheet**

Create `themes/terminal-workspace/assets/css/main.css`:

```css
:root {
  --bg: #120d05;
  --fg: #ffbf47;
}

html, body {
  margin: 0;
  padding: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: Iosevka, "IBM Plex Mono", "SFMono-Regular", monospace;
}
```

- [ ] **Step 6: Run Hugo to verify the new theme scaffold builds**

Run:

```bash
hugo --destination /tmp/terminal-workspace-build
```

Expected:

```text
PASS with a generated site using the new theme scaffold.
```

- [ ] **Step 7: Commit**

```bash
git add config.toml themes/terminal-workspace/theme.toml themes/terminal-workspace/layouts/_default/baseof.html themes/terminal-workspace/assets/css/main.css
git commit -m "feat: scaffold terminal workspace Hugo theme"
```

## Task 2: Build The Shared Workspace Shell

**Files:**
- Create: `themes/terminal-workspace/layouts/partials/topbar.html`
- Create: `themes/terminal-workspace/layouts/partials/banner.html`
- Modify: `themes/terminal-workspace/layouts/_default/baseof.html`
- Modify: `themes/terminal-workspace/assets/css/main.css`
- Test: `hugo --destination /tmp/terminal-workspace-build`

- [ ] **Step 1: Add the topbar partial**

Create `themes/terminal-workspace/layouts/partials/topbar.html`:

```html
{{ $section := cond .IsHome "home*" (cond (eq .Kind "taxonomy") "tags*" (cond (eq .Kind "term") "tags*" (cond (eq .Kind "page") "about*" "posts*"))) }}
<div class="workspace-topbar">
  <span>1:home{{ if .IsHome }}*{{ end }}</span>
  <span>2:posts{{ if and (not .IsHome) (or (eq .Kind "section") (eq .Kind "taxonomy") (eq .Kind "term")) }}*{{ end }}</span>
  <span>3:tags{{ if or (eq .Kind "taxonomy") (eq .Kind "term") }}*{{ end }}</span>
  <span>4:about{{ if eq .Kind "page" }}*{{ end }}</span>
  <span class="workspace-session">[session: drpaneas]</span>
</div>
```

- [ ] **Step 2: Add the banner partial**

Create `themes/terminal-workspace/layouts/partials/banner.html`:

```html
{{ $tw := .Site.Params.terminal_workspace }}
<section class="workspace-banner" aria-label="Site introduction">
  <div class="pane banner-pane">
    <div class="pane-title">greeting / intro</div>
    <pre class="identity-ascii">{{ $tw.identity_ascii }}</pre>
    <p class="identity-line">{{ $tw.identity_title }}</p>
    <p class="identity-line">{{ $tw.identity_subtitle }}</p>
    <p class="identity-line identity-interests">{{ $tw.identity_interests }}</p>
  </div>
  <aside class="pane quote-pane">
    <div class="pane-title">{{ $tw.quote_heading }}</div>
    <p class="quote-tagline">{{ $tw.quote_tagline }}</p>
    <blockquote class="quote-text">{{ $tw.quote_text }}</blockquote>
  </aside>
</section>
```

- [ ] **Step 3: Wrap the whole site in the workspace shell**

Modify `themes/terminal-workspace/layouts/_default/baseof.html`:

```html
<!doctype html>
<html lang="{{ .Site.LanguageCode | default "en-us" }}">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{{ if .IsHome }}{{ .Site.Title }}{{ else }}{{ .Title }} | {{ .Site.Title }}{{ end }}</title>
    <meta name="author" content="{{ .Site.Params.author }}" />
    <meta name="description" content="{{ if .IsHome }}{{ .Site.Params.description }}{{ else }}{{ .Description | default .Site.Params.description }}{{ end }}" />
    {{ $style := resources.Get "css/main.css" | minify | fingerprint }}
    <link rel="stylesheet" href="{{ $style.RelPermalink }}" />
  </head>
  <body>
    <main class="workspace-page">
      <section class="workspace-shell">
        {{ partial "topbar.html" . }}
        {{ block "main" . }}{{ .Content }}{{ end }}
      </section>
    </main>
  </body>
</html>
```

- [ ] **Step 4: Add shell and banner CSS**

Append to `themes/terminal-workspace/assets/css/main.css`:

```css
:root {
  --bg: #120d05;
  --fg: #ffbf47;
  --fg-strong: #ffd98a;
  --chrome: #6e4c12;
  --bar: #3a2a08;
}

html, body {
  margin: 0;
  padding: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: Iosevka, "IBM Plex Mono", "SFMono-Regular", monospace;
}

body::before {
  content: "";
  position: fixed;
  inset: 0;
  pointer-events: none;
  background: radial-gradient(circle at center, rgba(255, 191, 71, 0.05), rgba(0, 0, 0, 0.18));
}

.workspace-page {
  padding: 1rem;
}

.workspace-shell {
  position: relative;
  z-index: 1;
  border: 1px solid var(--chrome);
  padding: 0.75rem;
}

.workspace-topbar {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  background: var(--bar);
  color: #f6d690;
  padding: 0.3rem 0.6rem;
  margin-bottom: 0.75rem;
  font-size: 0.95rem;
}

.workspace-session {
  margin-left: auto;
}

.workspace-banner {
  display: grid;
  grid-template-columns: 1.05fr 1.1fr;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.pane {
  border: 1px dashed #7c5717;
  padding: 0.75rem;
}

.pane-title {
  color: var(--fg-strong);
  text-shadow: 0 0 6px rgba(255, 191, 71, 0.45);
  margin-bottom: 0.5rem;
}

.identity-ascii {
  margin: 0;
  white-space: pre-wrap;
  line-height: 1.3;
}

.identity-line,
.quote-text,
.quote-tagline {
  margin: 0.5rem 0 0;
}

.identity-interests {
  line-height: 1.5;
}
```

- [ ] **Step 5: Run Hugo and verify the shell renders**

Run:

```bash
hugo --destination /tmp/terminal-workspace-build
```

Expected:

```text
PASS and generated HTML contains the topbar and banner partial output.
```

- [ ] **Step 6: Commit**

```bash
git add themes/terminal-workspace/layouts/_default/baseof.html themes/terminal-workspace/layouts/partials/topbar.html themes/terminal-workspace/layouts/partials/banner.html themes/terminal-workspace/assets/css/main.css
git commit -m "feat: add workspace shell and identity banner"
```

## Task 3: Build The Practical Workspace Homepage

**Files:**
- Create: `themes/terminal-workspace/layouts/index.html`
- Create: `themes/terminal-workspace/layouts/partials/tag_filters.html`
- Create: `themes/terminal-workspace/layouts/partials/recent_posts.html`
- Create: `themes/terminal-workspace/layouts/partials/post_preview.html`
- Modify: `themes/terminal-workspace/assets/css/main.css`
- Test: homepage build plus Lynx dump

- [ ] **Step 1: Add wrapped inline quick tag filters**

Create `themes/terminal-workspace/layouts/partials/tag_filters.html`:

```html
{{ $tw := .Site.Params.terminal_workspace }}
{{ $tags := .Site.Taxonomies.tags }}
<section class="pane" aria-label="Quick tag filters">
  <div class="pane-title">tags / quick filters</div>
  <div class="tag-cloud">
    {{ range $name, $_ := $tags }}
      {{ with $.Site.GetPage (printf "/tags/%s" $name) }}
        <a href="{{ .RelPermalink }}">{{ .Title }}</a>
      {{ end }}
    {{ end }}
    <a class="all-tags-link" href="/tags/">{{ $tw.all_tags_label }}</a>
  </div>
</section>
```

- [ ] **Step 2: Add a top-5 recent posts pane**

Create `themes/terminal-workspace/layouts/partials/recent_posts.html`:

```html
{{ $limit := .Site.Params.terminal_workspace.home_post_limit | default 5 }}
<section class="pane" aria-label="Recent posts">
  <div class="pane-title">recent posts / top {{ $limit }}</div>
  {{ range first $limit (where .Site.RegularPages "Type" "post") }}
    <div><a href="{{ .RelPermalink }}">{{ .Date.Format "2006-01-02" }}  {{ .Title }}</a></div>
  {{ end }}
  <div class="posts-more"><a href="/post/">{{ .Site.Params.terminal_workspace.all_posts_label }}</a></div>
</section>
```

- [ ] **Step 3: Add a preview pane for the most recent post**

Create `themes/terminal-workspace/layouts/partials/post_preview.html`:

```html
{{ $featured := index (first 1 (where .Site.RegularPages "Type" "post")) 0 }}
<section class="pane" aria-label="Post preview">
  <div class="pane-title">preview / {{ $featured.File.LogicalName }}</div>
  <h2 class="preview-title"><a href="{{ $featured.RelPermalink }}">{{ $featured.Title }}</a></h2>
  <p class="preview-meta">{{ $featured.Date.Format "2006-01-02" }} / {{ $featured.ReadingTime }} min / tags:
    {{ range $i, $tag := $featured.Params.tags }}{{ if $i }}, {{ end }}{{ $tag }}{{ end }}
  </p>
  <p>{{ with $featured.Summary }}{{ . | plainify }}{{ else }}{{ $featured.Description }}{{ end }}</p>
</section>
```

- [ ] **Step 4: Compose the homepage**

Create `themes/terminal-workspace/layouts/index.html`:

```html
{{ define "main" }}
  {{ partial "banner.html" . }}
  {{ partial "tag_filters.html" . }}
  <section class="home-grid">
    {{ partial "recent_posts.html" . }}
    {{ partial "post_preview.html" . }}
  </section>
{{ end }}
```

- [ ] **Step 5: Style the homepage panes and tag wrapping**

Append to `themes/terminal-workspace/assets/css/main.css`:

```css
.tag-cloud {
  line-height: 1.9;
}

.tag-cloud a {
  display: inline-block;
  margin-right: 0.7rem;
  white-space: nowrap;
  color: var(--fg);
  text-decoration: none;
}

.tag-cloud a:hover,
.tag-cloud a:focus,
.all-tags-link,
.posts-more a,
.preview-title a:hover,
.preview-title a:focus {
  color: var(--fg-strong);
  text-shadow: 0 0 6px rgba(255, 191, 71, 0.45);
}

.home-grid {
  display: grid;
  grid-template-columns: 1.15fr 1.35fr;
  gap: 0.75rem;
}

.preview-title {
  margin: 0 0 0.4rem;
}

.preview-title a {
  color: var(--fg);
  text-decoration: none;
}

.preview-meta,
.posts-more {
  margin-top: 0.7rem;
}
```

- [ ] **Step 6: Run Hugo and verify homepage output**

Run:

```bash
hugo --destination /tmp/terminal-workspace-build
lynx -dump /tmp/terminal-workspace-build/index.html
```

Expected:

```text
Hugo build passes.
Lynx dump shows banner text, quick tag links, top 5 posts, preview content, and "more posts ->".
```

- [ ] **Step 7: Commit**

```bash
git add themes/terminal-workspace/layouts/index.html themes/terminal-workspace/layouts/partials/tag_filters.html themes/terminal-workspace/layouts/partials/recent_posts.html themes/terminal-workspace/layouts/partials/post_preview.html themes/terminal-workspace/assets/css/main.css
git commit -m "feat: add practical workspace homepage"
```

## Task 4: Archive, Taxonomy, And Article Views

**Files:**
- Create: `themes/terminal-workspace/layouts/_default/list.html`
- Create: `themes/terminal-workspace/layouts/_default/terms.html`
- Create: `themes/terminal-workspace/layouts/_default/single.html`
- Create: `themes/terminal-workspace/layouts/partials/post_meta.html`
- Create: `themes/terminal-workspace/layouts/partials/breadcrumb.html`
- Modify: `themes/terminal-workspace/assets/css/main.css`
- Test: build plus Lynx dump of an article page

- [ ] **Step 1: Add the reusable post metadata partial**

Create `themes/terminal-workspace/layouts/partials/post_meta.html`:

```html
{{ if ne .Type "page" }}
  <p class="post-meta">
    {{ .Date.Format "2006-01-02" }} / {{ .ReadingTime }} min
    {{ with .Params.tags }} / tags:
      {{ range $i, $tag := . }}{{ if $i }}, {{ end }}
        {{ with $.Site.GetPage (printf "/tags/%s" $tag) }}<a href="{{ .RelPermalink }}">{{ .Title }}</a>{{ end }}
      {{ end }}
    {{ end }}
  </p>
{{ end }}
```

- [ ] **Step 2: Add the breadcrumb + back partial**

Create `themes/terminal-workspace/layouts/partials/breadcrumb.html`:

```html
<nav class="breadcrumb-back" aria-label="Breadcrumb">
  <a href="/">workspace</a> /
  <a href="/post/">posts</a> /
  <span>{{ .File.LogicalName }}</span>
</nav>
```

- [ ] **Step 3: Build archive/list pages**

Create `themes/terminal-workspace/layouts/_default/list.html`:

```html
{{ define "main" }}
  {{ if .IsHome }}{{ partial "banner.html" . }}{{ end }}
  <section class="pane list-pane">
    <div class="pane-title">{{ .Title | lower }} / archive</div>
    {{ range .Pages }}
      <article class="archive-entry">
        <h2><a href="{{ .RelPermalink }}">{{ .Title }}</a></h2>
        {{ partial "post_meta.html" . }}
      </article>
    {{ end }}
  </section>
{{ end }}
```

- [ ] **Step 4: Build taxonomy overview pages**

Create `themes/terminal-workspace/layouts/_default/terms.html`:

```html
{{ define "main" }}
  <section class="pane list-pane">
    <div class="pane-title">{{ .Title | lower }} / all</div>
    <div class="tag-cloud">
      {{ range .Pages }}
        <a href="{{ .RelPermalink }}">{{ .Title }}</a>
      {{ end }}
    </div>
  </section>
{{ end }}
```

- [ ] **Step 5: Build immersive article pages**

Create `themes/terminal-workspace/layouts/_default/single.html`:

```html
{{ define "main" }}
  <article class="pane article-pane">
    {{ partial "breadcrumb.html" . }}
    <div class="pane-title">article / {{ .File.LogicalName }}</div>
    <h1>{{ .Title }}</h1>
    {{ partial "post_meta.html" . }}
    <div class="post-content">
      {{ .Content }}
    </div>
  </article>
{{ end }}
```

- [ ] **Step 6: Style archive and article pages**

Append to `themes/terminal-workspace/assets/css/main.css`:

```css
.list-pane,
.article-pane {
  line-height: 1.55;
}

.archive-entry {
  margin-bottom: 1rem;
}

.archive-entry h2,
.article-pane h1 {
  margin: 0 0 0.4rem;
}

.breadcrumb-back {
  margin-bottom: 0.75rem;
}

.breadcrumb-back a,
.post-meta a,
.archive-entry a {
  color: var(--fg);
  text-decoration: none;
}

.breadcrumb-back a:hover,
.breadcrumb-back a:focus,
.post-meta a:hover,
.post-meta a:focus,
.archive-entry a:hover,
.archive-entry a:focus {
  color: var(--fg-strong);
  text-shadow: 0 0 6px rgba(255, 191, 71, 0.45);
}

.post-content {
  margin-top: 1rem;
}
```

- [ ] **Step 7: Run Hugo and verify the article fallback flow**

Run:

```bash
hugo --destination /tmp/terminal-workspace-build
lynx -dump /tmp/terminal-workspace-build/blog/2021/04/26/about/index.html
```

Expected:

```text
Build passes.
Lynx dump shows breadcrumb navigation, title, metadata (when available), and article content in readable order.
```

- [ ] **Step 8: Commit**

```bash
git add themes/terminal-workspace/layouts/_default/list.html themes/terminal-workspace/layouts/_default/terms.html themes/terminal-workspace/layouts/_default/single.html themes/terminal-workspace/layouts/partials/post_meta.html themes/terminal-workspace/layouts/partials/breadcrumb.html themes/terminal-workspace/assets/css/main.css
git commit -m "feat: add archives and immersive article layout"
```

## Task 5: Add Language-Accented Code Blocks

**Files:**
- Modify: `themes/terminal-workspace/assets/css/main.css`
- Test: build and inspect one generated article with code blocks

- [ ] **Step 1: Define the shared code block shell**

Append to `themes/terminal-workspace/assets/css/main.css`:

```css
pre,
code,
.highlight {
  font-family: Iosevka, "IBM Plex Mono", "SFMono-Regular", monospace;
}

.highlight pre {
  padding: 0.75rem;
  border: 1px dashed #7c5717;
  background: rgba(255, 191, 71, 0.03);
  overflow-x: auto;
}

code {
  padding: 0.1rem 0.3rem;
  border: 1px solid #7c5717;
  background: rgba(255, 191, 71, 0.04);
}
```

- [ ] **Step 2: Add per-language accent hooks**

Append to `themes/terminal-workspace/assets/css/main.css`:

```css
.highlight.language-bash,
.highlight[data-lang="bash"] {
  border-left: 3px solid #f6d690;
}

.highlight.language-go,
.highlight[data-lang="go"] {
  border-left: 3px solid #79d3ff;
}

.highlight.language-asm,
.highlight.language-assembly,
.highlight[data-lang="assembly"] {
  border-left: 3px solid #ff89d0;
}

.highlight.language-c,
.highlight[data-lang="c"] {
  border-left: 3px solid #89f0b5;
}
```

- [ ] **Step 3: Add restrained token emphasis**

Append to `themes/terminal-workspace/assets/css/main.css`:

```css
.highlight .k,
.highlight .kd,
.highlight .kn {
  color: #ffd98a;
}

.highlight .s,
.highlight .s1,
.highlight .s2 {
  color: #f4e0ae;
}

.highlight .c,
.highlight .c1,
.highlight .cm {
  color: #b88a37;
}
```

- [ ] **Step 4: Build and inspect a page with code snippets**

Run:

```bash
hugo --destination /tmp/terminal-workspace-build
rg "highlight|language-bash|language-go|language-c" /tmp/terminal-workspace-build -n
```

Expected:

```text
Build passes and generated HTML contains syntax-highlighted code blocks ready for the shared shell plus language accent CSS.
```

- [ ] **Step 5: Commit**

```bash
git add themes/terminal-workspace/assets/css/main.css
git commit -m "feat: add language-accented code block styling"
```

## Task 6: Finish Fallbacks, 404, And Accessibility Polish

**Files:**
- Create: `themes/terminal-workspace/layouts/404.html`
- Modify: `themes/terminal-workspace/assets/css/main.css`
- Test: Hugo build, Lynx homepage dump, Lynx article dump

- [ ] **Step 1: Add a simple 404 page**

Create `themes/terminal-workspace/layouts/404.html`:

```html
{{ define "main" }}
  <section class="pane">
    <div class="pane-title">404 / not found</div>
    <p>The requested path could not be found.</p>
    <p><a href="/">return to workspace</a></p>
  </section>
{{ end }}
```

- [ ] **Step 2: Add reduced-motion and responsive fallbacks**

Append to `themes/terminal-workspace/assets/css/main.css`:

```css
@media (max-width: 900px) {
  .workspace-banner,
  .home-grid {
    grid-template-columns: 1fr;
  }

  .workspace-session {
    margin-left: 0;
  }
}

@media (prefers-reduced-motion: reduce) {
  * {
    animation: none !important;
    transition: none !important;
  }

  .pane-title,
  a:hover,
  a:focus {
    text-shadow: none;
  }
}
```

- [ ] **Step 3: Add visible keyboard focus states**

Append to `themes/terminal-workspace/assets/css/main.css`:

```css
a:focus-visible {
  outline: 2px solid #ffd98a;
  outline-offset: 2px;
}
```

- [ ] **Step 4: Run final build and text-browser checks**

Run:

```bash
hugo --destination /tmp/terminal-workspace-build
lynx -dump /tmp/terminal-workspace-build/index.html
lynx -dump /tmp/terminal-workspace-build/tags/index.html
```

Expected:

```text
All commands succeed.
Lynx output shows a coherent homepage, tags page, and article navigation without missing structure.
```

- [ ] **Step 5: Commit**

```bash
git add themes/terminal-workspace/layouts/404.html themes/terminal-workspace/assets/css/main.css
git commit -m "feat: finalize fallback and accessibility polish"
```

## Self-Review

### 1. Spec coverage

- Workspace shell: covered by Tasks 1-2.
- Compact homepage with banner, wrapped tags, top 5 posts, preview: covered by Task 3.
- Immersive article mode with breadcrumb return: covered by Task 4.
- Amber styling, Iosevka, restrained glow: covered by Tasks 2, 4, and 6.
- Language-accented code blocks for bash, Go, assembly, and C: covered by Task 5.
- Lynx/plain HTML compatibility and progressive enhancement boundaries: covered by Tasks 1, 4, and 6.

No uncovered spec requirements remain.

### 2. Placeholder scan

- No `TBD`, `TODO`, or deferred placeholders remain.
- Every task names exact file paths.
- Every verification step names exact commands and expected outcomes.

### 3. Type consistency

- Theme name is consistently `terminal-workspace`.
- Config namespace is consistently `params.terminal_workspace`.
- Shared shell terminology uses `workspace shell`, `pane`, `pane-title`, and `workspace-topbar` consistently.
- Homepage links consistently use `more posts ->` and `all tags ->`.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-01-terminal-workspace-hugo-theme.md`. Two execution options:

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
