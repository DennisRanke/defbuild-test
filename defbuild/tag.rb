module DefBuild
	class Tag
		attr_reader :value
		
		def initialize(value)
			@value = value
		end
		
		def &(o)
			TagAnd.new(self, o)
		end
		
		def |(o)
			TagOr.new(self, o)
		end
		
		def ===(tag_list)
			tag_list.any? do |tag|
				tag.is_a?(Tag) ? @value === tag.value : @value === tag
			end
		end
		
		def matches?(tag_list)
			self === tag_list
		end
		
		def match(tag_list)
			tag_list.inject(0) {|acc, tag| acc + ((tag.is_a?(Tag) ? @value === tag.value : @value === tag) ? 1 : 0) }
		end
	end
	
	class TagAnd
		def initialize(a, b)
			@a = a
			@b = b
		end
		
		def ===(tag_list)
			@a === tag_list && @b === tag_list
		end
		
		def matches?(tag_list)
			self === tag_list
		end
		
		def match(tag_list)
			a = @a.match(tag_list)
			b = @b.match(tag_list)
			(a > 0 && b > 0) ? a + b : 0
		end
	end
	
	class TagOr
		def initialize(a, b)
			@a = a
			@b = b
		end
		
		def ===(tag_list)
			@a === tag_list || @b === tag_list
		end
		
		def matches?(tag_list)
			self === tag_list
		end
		
		def match(tag_list)
			[@a.match(tag_list), @b.match(tag_list)].max
		end
	end
end

