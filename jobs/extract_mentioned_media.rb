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
				doc.css('a').each do |link|
					url = link['href']
					next unless url
					item = categorize_media(url)
					media_items << item if item && !media_items.any? { |m| m[:url] == item[:url] }
				end
			end
			media_items.sort_by! { |m| [m[:type], m[:title].to_s.downcase] }
			topic.custom_fields["mentioned_media"] = media_items.to_json
			topic.save_custom_fields
		end
		private
		def categorize_media(url)
			return nil unless url
			uri = URI.parse(url) rescue nil
			return nil unless uri
			host = uri.host&.downcase || ""
			path = uri.path&.downcase || ""
			if host.include?("imdb.com")
				if path.include?("/title/")
					title = extract_title_from_url(url)
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
					title = extract_title_from_url(url)
					icon = get_icon_for_type(type)
					return { type: type, url: url, title: title, icon: icon }
				end
			elsif host.include?("goodreads.com")
				if path.include?("/book/")
					title = extract_title_from_url(url)
					return { type: "book", url: url, title: title, icon: "book" }
				end
			elsif host.include?("themoviedb.org") || host.include?("tmdb.org")
				if path.include?("/movie/") || path.include?("/tv/")
					type = path.include?("/movie/") ? "movie" : "tv"
					title = extract_title_from_url(url)
					icon = type == "movie" ? "movie" : "tv"
					return { type: type, url: url, title: title, icon: icon }
				end
			elsif host.include?("spotify.com")
				if path.include?("/album/") || path.include?("/track/")
					title = extract_title_from_url(url)
					return { type: "music", url: url, title: title, icon: "music" }
				end
			elsif host.include?("igdb.com") || host.include?("steampowered.com")
				title = extract_title_from_url(url)
				return { type: "game", url: url, title: title, icon: "game" }
			end
			nil
		end
		def extract_title_from_url(url)
			uri = URI.parse(url) rescue nil
			return "Unknown" unless uri
			path_parts = uri.path.split("/").reject(&:empty?)
			title = path_parts.last || "Unknown"
			title.gsub(/[-_]/, " ").split.map(&:capitalize).join(" ")
		rescue
			"Unknown"
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