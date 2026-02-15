module Jobs
	class ExtractMentionedMedia < ::Jobs::Base
		def execute(args)
			post = Post.find_by(id: args[:post_id])
			return unless post&.topic
			topic = post.topic
			all_posts = topic.posts
			media_items = []
			all_posts.each do |p|
				urls = p.raw.scan(/https?:\/\/[^\s<>]+/)
				cooked_doc = Nokogiri::HTML5.fragment(p.cooked)
				onebox_map = build_onebox_map(cooked_doc)
				urls.each do |url|
					clean_url = url.chomp('/').split('?').first
					next unless categorize_media(clean_url, "")
					onebox_title = onebox_map[normalize_url(url)]
					title = extract_best_title(clean_url, onebox_title)
					item = categorize_media(clean_url, title)
					media_items << item if item && !media_items.any? { |m| m[:url] == item[:url] }
				end
			end
			topic.custom_fields["mentioned_media"] = media_items.to_json
			topic.save_custom_fields
		end
		private
		def normalize_url(url)
			url.chomp('/').split('?').first.downcase
		end
		def build_onebox_map(doc)
			map = {}
			doc.css('aside[class*="onebox"]').each do |onebox|
				url = onebox['data-onebox-src']
				next unless url
				title = onebox.at_css('.onebox-body h3 a, .onebox-body h3, h3 a, h3')&.text&.strip
				title ||= onebox.at_css('meta[property="og:title"]')&.[]('content')&.strip
				title ||= onebox.at_css('meta[name="twitter:title"]')&.[]('content')&.strip
				map[normalize_url(url)] = title if title
			end
			doc.css('a.onebox').each do |link|
				next if link.ancestors('aside').any?
				url = link['href']
				next unless url
				title = link.text&.strip
				next if !title || title.empty? || title == url
				map[normalize_url(url)] = title
			end
			map
		end
		def categorize_media(url, title)
			return nil unless url
			uri = URI.parse(url) rescue nil
			return nil unless uri
			host = uri.host&.downcase || ""
			path = uri.path&.downcase || ""
			if host.include?("imdb.com") && path.include?("/title/")
				return { type: "movie", url: url, title: title, icon: "movie" }
			elsif (host.include?("themoviedb.org") || host.include?("tmdb.org")) && (path.include?("/movie/") || path.include?("/tv/"))
				type = path.include?("/movie/") ? "movie" : "tv"
				icon = type == "movie" ? "movie" : "tv"
				return { type: type, url: url, title: title, icon: icon }
			elsif host.include?("letterboxd.com") && path.include?("/film/")
				return { type: "movie", url: url, title: title, icon: "movie" }
			elsif host.include?("goodreads.com") && path.include?("/book/")
				return { type: "book", url: url, title: title, icon: "book" }
			elsif host.include?("spotify.com") && (path.include?("/album/") || path.include?("/track/"))
				return { type: "music", url: url, title: title, icon: "music" }
			elsif host.include?("music.apple.com") && (path.include?("/album/") || path.include?("/artist/"))
				return { type: "music", url: url, title: title, icon: "music" }
			elsif host.include?("igdb.com") || host.include?("steampowered.com") || host.include?("playstation.com") || host.include?("xbox.com") || host.include?("nintendo.com") || host.include?("epicgames.com") || host.include?("gog.com")
				return { type: "game", url: url, title: title, icon: "game" }
			elsif host.include?("wikipedia.org")
				if path.match?(/\/wiki\/.+_(film|tv_series|book|album|video_game)/i)
					type = case path
					when /_(film)/i then "movie"
					when /_(tv_series)/i then "tv"
					when /_(book)/i then "book"
					when /_(album)/i then "music"
					when /_(video_game)/i then "game"
					end
					return { type: type, url: url, title: title, icon: get_icon(type) }
				end
			end
			nil
		end
		def extract_best_title(url, onebox_title)
			if has_clean_slug?(url)
				parsed = parse_title_from_url(url)
				cleaned = sanitize_title(parsed)
				return cleaned if cleaned && !cleaned.empty?
			end
			cleaned = sanitize_title(onebox_title)
			return cleaned if cleaned && !cleaned.empty?
			fallback = url_fallback(url)
			cleaned = sanitize_title(fallback)
			return cleaned if cleaned && !cleaned.empty?
			type_name_fallback(url)
		end
		def has_clean_slug?(url)
			uri = URI.parse(url) rescue nil
			return false unless uri
			host = uri.host&.downcase || ""
			host.include?("letterboxd.com") ||
			host.include?("themoviedb.org") ||
			host.include?("tmdb.org") ||
			host.include?("goodreads.com") ||
			host.include?("wikipedia.org") ||
			host.include?("steampowered.com") ||
			host.include?("gog.com") ||
			host.include?("igdb.com") ||
			host.include?("epicgames.com") ||
			host.include?("nintendo.com")
		end
		def parse_title_from_url(url)
			uri = URI.parse(url) rescue nil
			return nil unless uri
			host = uri.host&.downcase || ""
			path = uri.path || ""
			parts = path.split("/").reject(&:empty?)
			return nil if parts.empty?
			if host.include?("wikipedia.org")
				return nil if parts.length < 2
				title = parts.last
				title.gsub("_", " ").gsub(/\s*\(film\)\s*$/i, "").gsub(/\s*\(TV_series\)\s*$/i, "").gsub(/\s*\(book\)\s*$/i, "").gsub(/\s*\(album\)\s*$/i, "").gsub(/\s*\(video_game\)\s*$/i, "")
			elsif host.include?("goodreads.com") || host.include?("themoviedb.org") || host.include?("tmdb.org") || host.include?("igdb.com") || host.include?("epicgames.com")
				slug = parts.last
				return nil unless slug
				if slug.include?("-")
					slug.split("-", 2).last.gsub("-", " ")
				else
					slug.gsub("-", " ")
				end
			elsif host.include?("letterboxd.com")
				slug = parts.last
				return nil unless slug
				slug.gsub("-", " ")
			elsif host.include?("steampowered.com") || host.include?("gog.com")
				parts.last.gsub("_", " ")
			elsif host.include?("nintendo.com")
				slug = parts.last
				return nil unless slug
				slug.gsub("-", " ").gsub(/\s+(switch|nintendo)\s*$/i, "").strip
			else
				nil
			end
		rescue
			nil
		end
		def sanitize_title(title)
			return nil if title.nil? || title.empty?
			title = title.gsub(/[_™®©:–—…]/, " ")
			title = title.split("|").first.strip
			title = title.split(" by ").first.strip
			title = title.split(" on ").first.strip
			title = title.split(" for ").first.strip
			title = title.split(" - ").first.strip
			title = title.gsub(/\s*\([^)]*\)\s*/, " ")
			title = title.gsub(/\s+/, " ").strip
			return nil if title.empty?
			return nil if title.match?(/^\d+$/)
			return nil if title.match?(/^tt\d+$/i)
			return nil if title.match?(/^up\d+/i)
			return nil if title.match?(/^[a-z0-9]{15,}$/i)
			title.split.map(&:capitalize).join(" ")
		end
		def url_fallback(url)
			uri = URI.parse(url) rescue nil
			return url unless uri
			path = uri.path || ""
			parts = path.split("/").reject(&:empty?)
			return url if parts.empty?
			fallback = parts.last || url
			fallback.gsub(/[-_]/, " ").split.map(&:capitalize).join(" ")
		rescue
			url
		end
		def type_name_fallback(url)
			item = categorize_media(url, "")
			return "Unknown Media" unless item
			case item[:type]
			when "movie" then "Movie"
			when "tv" then "TV Show"
			when "book" then "Book"
			when "music" then "Music"
			when "game" then "Video Game"
			else "Media"
			end
		end
		def get_icon(type)
			case type
			when "movie" then "movie"
			when "tv" then "tv"
			when "book" then "book"
			when "music" then "music"
			when "game" then "game"
			else "link"
			end
		end
	end
end