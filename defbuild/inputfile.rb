require 'set'
require 'pathname'

def to_path(filename)
	filename.is_a?(Pathname) ? filename : Pathname.new(filename).expand_path
end

module DefBuild
	class InputFile
		attr_reader :path, :context
		attr_accessor :tags
	
		def initialize(path, tags, context)
			tags = tags.to_set
			ext = /\.[^.]+$/.match(path.to_s)
			tags << ext[0] if ext
			@path = path
			@tags = tags
			@context = context
		end
	end
end

