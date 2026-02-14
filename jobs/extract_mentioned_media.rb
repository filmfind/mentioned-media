module Jobs
	class ExtractMentionedMedia < ::Jobs::Base
		def execute(args)
			post = Post.find_by(id: args[:post_id])
			return unless post&.topic
			topic = post.topic
			all_posts = topic.posts
			media_items = []
			all_posts.each do |p|
				doc = Nokogiri::HTML5.fragment(p.cooked)
				doc.css('a[href]').each do |link|
					url = link['href']
					next unless url
					next unless categorize_media(url, "")
					onebox = link.ancestors('aside.onebox').first
					onebox_title = onebox&.at_css('.onebox-body h3 a, .onebox-body h3, h3 a, h3')&.text&.strip
					onebox_title ||= onebox&.at_css('meta[property="og:title"]')&.[]('content')&.strip
					onebox_title ||= onebox&.at_css('meta[name="twitter:title"]')&.[]('content')&.strip
					link_text = link.text.strip
					title = extract_best_title(url, onebox_title, link_text)
					item = categorize_media(url, title)
					media_items << item if item && !media_items.any? { |m| m[:url] == item[:url] }
				end
			end
			topic.custom_fields["mentioned_media"] = media_items.to_json
			topic.save_custom_fields
		end
		private
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
			elsif host.include?("wikipedia.org") || host.include?("en.m.wikipedia.org")
				if path.match?(/\/wiki\/.+_(film|TV_series|book|album|video_game)/)
					type = case path
					when /_(film)/ then "movie"
					when /_(TV_series)/ then "tv"
					when /_(book)/ then "book"
					when /_(album)/ then "music"
					when /_(video_game)/ then "game"
					end
					return { type: type, url: url, title: title, icon: get_icon(type) }
				end
			end
			nil
		end
		def extract_best_title(url, onebox_title, link_text)
			if has_clean_slug?(url)
				parsed = parse_title_from_url(url)
				return sanitize_title(parsed) if parsed && !parsed.empty?
			end
			return sanitize_title(onebox_title) if onebox_title && !onebox_title.empty? && onebox_title != url
			return sanitize_title(link_text) if link_text && !link_text.empty? && link_text != url
			parsed = parse_title_from_url(url)
			return sanitize_title(parsed) if parsed && !parsed.empty?
			url_fallback(url)
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
			host.include?("epicgames.com")
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
			elsif host.include?("goodreads.com") || host.include?("themoviedb.org") || host.include?("tmdb.org") || host.include?("letterboxd.com") || host.include?("igdb.com") || host.include?("epicgames.com")
				slug = parts.last
				return nil unless slug
				if slug.include?("-")
					slug.split("-", 2).last.gsub("-", " ")
				else
					slug.gsub("-", " ")
				end
			elsif host.include?("steampowered.com") || host.include?("gog.com")
				parts.last.gsub("_", " ")
			else
				nil
			end
		rescue
			nil
		end
		def sanitize_title(title)
			return nil if title.nil? || title.empty?
			return nil if title.match?(/^\d+$/)
			return nil if title.match?(/^tt\d+$/i)
			return nil if title.match?(/^UP\d+-[A-Z0-9_-]+$/i)
			return nil if title.match?(/^[A-Z0-9]{10,}$/i)
			title = title.split("|").first.strip
			title = title.gsub(/\s*\([^)]*\)\s*/, " ")
			title = title.gsub(/[_™®©]/, " ")
			title = title.gsub(/\s+/, " ").strip
			return nil if title.empty?
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