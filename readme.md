# Mentioned Media

A minimalist Discourse plugin that automatically lists media (movies, TV shows, books, music, games) mentioned in topics.

## Features

- Automatically detects media links from IMDb, Wikipedia, Goodreads, Spotify, TMDB, IGDB, and Steam
- Displays a clean "Mentioned Media" widget showing all media referenced in a topic
- Zero configuration required (works out of the box)
- Minimal footprint (leverages Discourse's existing Onebox system)

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

## Supported Media Types

- **Movies**: IMDb, Wikipedia film pages, TMDB
- **TV Shows**: IMDb, Wikipedia TV pages, TMDB
- **Books**: Goodreads, Wikipedia book pages
- **Music**: Spotify albums/tracks
- **Games**: IGDB, Steam

## How it Works

The plugin hooks into Discourse's Onebox system to detect when media-related URLs are posted. When a post contains a link to supported media sites, the plugin:

1. Extracts the URL and metadata from Discourse's existing Onebox cache
2. Categorizes the media type
3. Stores references in topic custom fields
4. Displays all mentioned media in a widget below the topic

No additional API calls or external requests are made (everything uses data Discourse already fetched).

## License

Public Domain