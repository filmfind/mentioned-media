# name: mentioned-media
# about: Automatically lists media (movies, TV, books, music, games) mentioned in topics
# version: 0.1
# authors: Filmfind, Web Guy
# url: https://github.com/filmfind/mentioned-media

enabled_site_setting :mentioned_media_enabled

after_initialize do
	module ::MentionedMedia
		PLUGIN_NAME = "mentioned-media"
		class Engine < ::Rails::Engine
			engine_name PLUGIN_NAME
			isolate_namespace MentionedMedia
		end
	end
	require_relative "jobs/extract_mentioned_media"
	on(:post_created) do |post, opts|
		Jobs.enqueue(:extract_mentioned_media, post_id: post.id)
	end
	on(:post_edited) do |post, topic_changed|
		Jobs.enqueue(:extract_mentioned_media, post_id: post.id)
	end
	add_to_serializer(:topic_view, :mentioned_media) do
		media_json = object.topic.custom_fields["mentioned_media"]
		media_json ? JSON.parse(media_json) : []
	end
end