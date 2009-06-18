module DefBuild
	class Context
		def initialize(project, parent)
			project.register_context(self)
			@parent = parent
			@imports = []
			@attributes = {}
		end
		
		def add_import(import)
			@imports << import
		end
		
		def resolve_imports
			@imports = @imports.map do |import|
				import.is_a?(Project::Import) ? import.module.exports : import
			end.flatten
		end
		
		def add_attribute(id, *values)
			attribute = (@attributes[id] ||= [])
			raise "Trying to add values to scalar attribute #{id.inspect}" unless attribute.is_a?(Array)
			attribute.concat(values)
		end
		
		def set_attribute(id, value)
			if @attributes.include?(id)
				raise "Trying to set attribute #{id.inspect} but it already has a value"
			end
			@attributes[id] = value
		end
		
		def get_attribute_set(id)
			get_attribute_list(id).uniq
		end
		
		def get_attribute_list(id)
			values = @parent ? @parent.get_attribute_list(id) : []
			@imports.each do |import|
				values.concat(import.get_attribute_list(id))
			end
			my_values = @attributes[id]
			if my_values
				if my_values.is_a?(Array)
					values.concat(my_values)
				else
					values << my_values
				end
			end
			return values
		end
		
		def get_attribute_value(id)
			attribute = @attributes[id]
			return attribute.is_a?(Array) ? attribute.last : attribute if attribute
			@imports.each do |import|
				value = import.get_attribute_value(id)
				return value if value
			end
			return @parent ? @parent.get_attribute_value(id) : nil
		end
		
		def get_local_attributes(id)
			@attributes[id] || []
		end
	end
end

