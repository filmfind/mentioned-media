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
				doc.css('aside.onebox').each do |onebox|
					link = onebox.at_css('a.onebox') || onebox.at_css('a')
					next unless link
					url = link['href']
					next unless url
					onebox_title = onebox.at_css('.onebox-body h3, .onebox-body h4, h3, h4, .source, [class*="title"]')&.text&.strip
					link_text = link.text.strip
					title = extract_best_title(url, onebox_title, link_text)
					item = categorize_media(url, title)
					media_items << item if item && !media_items.any? { |m| m[:url] == item[:url] }
				end
			end
			media_items.sort_by! { |m| [m[:type], m[:title].to_s.downcase] }
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
			if host.include?("imdb.com")
				if path.include?("/title/")
					return { type: "movie", url: url, title: title, icon: "movie" }
				end
			elsif host.include?("wikipedia.org") || host.include?("en.m.wikipedia.org")
				if path.match?(/\/wiki\/.+_(film|TV_series|book|album|video_game)/)
					type = case path
					when /_(film)/ then "movie"
					when /_(TV_series)/ then "tv"
					when /_(book)/ then "book"
					when /_(album)/ then "music"
					when /_(video_game)/ then "game"
					end
					icon = get_icon_for_type(type)
					return { type: type, url: url, title: title, icon: icon }
				end
			elsif host.include?("goodreads.com")
				if path.include?("/book/")
					return { type: "book", url: url, title: title, icon: "book" }
				end
			elsif host.include?("themoviedb.org") || host.include?("tmdb.org")
				if path.include?("/movie/") || path.include?("/tv/")
					type = path.include?("/movie/") ? "movie" : "tv"
					icon = type == "movie" ? "movie" : "tv"
					return { type: type, url: url, title: title, icon: icon }
				end
			elsif host.include?("spotify.com")
				if path.include?("/album/") || path.include?("/track/")
					return { type: "music", url: url, title: title, icon: "music" }
				end
			elsif host.include?("letterboxd.com")
				if path.include?("/film/")
					return { type: "movie", url: url, title: title, icon: "movie" }
				end
			elsif host.include?("music.apple.com")
				if path.include?("/album/") || path.include?("/artist/")
					return { type: "music", url: url, title: title, icon: "music" }
				end
			elsif host.include?("igdb.com") || host.include?("steampowered.com") || host.include?("playstation.com") || host.include?("xbox.com") || host.include?("nintendo.com") || host.include?("epicgames.com") || host.include?("gog.com")
				return { type: "game", url: url, title: title, icon: "game" }
			end
			nil
		end
		def extract_best_title(url, onebox_title, link_text)
			return onebox_title if onebox_title && !onebox_title.empty? && onebox_title != url
			return link_text if link_text && !link_text.empty? && link_text != url
			parse_title_from_url(url)
		end
		def parse_title_from_url(url)
			uri = URI.parse(url) rescue nil
			return "Unknown" unless uri
			host = uri.host&.downcase || ""
			path = uri.path || ""
			if host.include?("wikipedia.org")
				parts = path.split("/").reject(&:empty?)
				return "Unknown" if parts.length < 2
				title = parts.last
				title = title.gsub("_", " ")
				title = title.gsub(/\s*\((film|TV_series|book|album|video_game)\)\s*$/i, "")
				return clean_title(title)
			elsif host.include?("goodreads.com") || host.include?("themoviedb.org") || host.include?("tmdb.org")
				parts = path.split("/").reject(&:empty?)
				slug = parts.last
				return "Unknown" unless slug
				if slug.include?("-")
					title = slug.split("-", 2).last
					title = title.gsub("-", " ")
					return clean_title(title)
				end
			elsif host.include?("steampowered.com")
				parts = path.split("/").reject(&:empty?)
				title = parts.last
				return "Unknown" unless title
				title = title.gsub("_", " ")
				return clean_title(title)
			elsif host.include?("letterboxd.com")
				parts = path.split("/").reject(&:empty?)
				return "Unknown" if parts.length < 2
				title = parts.last
				title = title.gsub("-", " ")
				return clean_title(title)
			end
			"Unknown"
		rescue
			"Unknown"
		end
		def clean_title(title)
			return "Unknown" if title.nil? || title.empty?
			return "Unknown" if title.match?(/^\d+$/)
			return "Unknown" if title.match?(/^tt\d+$/i)
			title.split.map(&:capitalize).join(" ")
		end
		def get_icon_for_type(type)
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