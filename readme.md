# Mentioned Media

A minimalist Discourse plugin that automatically lists media (movies, TV shows, books, music, games) mentioned in topics.

## Features

- Automatically detects media links from popular sites
- Displays a clean "Mentioned Media" widget showing all media referenced in a topic
- Intelligent title extraction from URLs and oneboxes
- Zero configuration required (works out of the box)
- Minimal footprint (scans raw post content, no external API calls)

## Installation

1. Add the plugin to your `app.yml`:
```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/filmfind/mentioned-media.git
```

2. Rebuild your container:
```bash
cd /var/discourse
./launcher rebuild app
```

## Supported Sites

**Movies:**
- IMDb
- TMDB
- Letterboxd
- Wikipedia

**TV Shows:**
- IMDb
- TMDB
- Wikipedia

**Books:**
- Goodreads
- Wikipedia

**Music:**
- Spotify
- Apple Music

**Games:**
- Steam
- PlayStation
- Xbox
- Nintendo
- Epic Games
- GOG
- IGDB

## How it Works

The plugin scans post content for media URLs and builds a list of all media mentioned in a topic:

1. Extracts URLs from raw post content (including embedded players)
2. Parses clean titles from URL slugs when available
3. Falls back to onebox metadata for sites with ID-based URLs
4. Categorizes media by type and displays with appropriate icons
5. Stores references in topic custom fields for persistence

Media appears in the order mentioned, making it easy to follow discussion context.

## License

Public Domain (CC0)