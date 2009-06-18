module DefBuild
	class DefModule
		attr_reader :exports, :path
	
		def initialize(project, path)
			@path = path
			@project = project
			@build_tags = project.build_tags
			@exports = []
			@current_context = Context.new(project, project.global_context)
		end
		
		def import(module_name)
			@current_context.add_import(@project.add_import(module_name, self))
		end
		
		def export
			old_context = @current_context
			@current_context = Context.new(@project, nil)
			@exports << @current_context
			yield
			old_context.add_import(@current_context)
			@current_context = old_context
		end
		
		def context
			old_context = @current_context
			@current_context = Context.new(@project, old_context)
			yield
			@current_context = old_context
		end
		
		def add_file(glob, tags)
			tags = tags.split
			Dir[glob].each do |filename|
				path = to_path(filename)
				@project.add_file(InputFile.new(path, tags, @current_context))
			end
		end
		
		def add_path(id, *paths)
			paths = paths.map {|path| to_path(path) }
			@current_context.add_attribute(id, *paths)
		end
		
		def set_path(id, path)
			@current_context.set_attribute(id, to_path(path))
		end
		
		def add_attribute(id, *attr)
			@current_context.add_attribute(id, *attr)
		end
		
		def set_attribute(id, attr)
			@current_context.set_attribute(id, attr)
		end
		
		def add_global_path(id, *paths)
			paths = paths.map {|path| to_path(path) }
			@project.global_context.add_attribute(id, *paths)
		end
		
		def set_global_path(id, path)
			@project.global_context.set_attribute(id, to_path(path))
		end
		
		def add_global_attribute(id, *attr)
			@project.global_context.add_attribute(id, *attr)
		end
		
		def set_global_attribute(id, attr)
			@project.global_context.set_attribute(id, attr)
		end
		
		def define_compiler(base_class, output_dir, input_tags, output_tags, *args, &block)
			compiler_class = Class.new(base_class)
			compiler_class.class_eval(&block)
			compiler = compiler_class.new(*args)
			add_compiler(output_dir, compiler, input_tags, output_tags)
			return compiler_class
		end	
		
		def tag(value)
			Tag.new(value)
		end
		
		def module_search_path(path)
			@project.add_import_path(path)
		end
		
		def inject(name)
			filename = @project.find_module(name, 'inject.def')
			instance_eval(filename.read, filename.to_s)
		end
		
	private
		
		def add_compiler(output_dir, compiler, input_tags, output_tags)
			compiler.project = @project
			compiler.output_path = @project.build_path + output_dir
			compiler.input_tags = input_tags
			compiler.output_tags = to_tags(output_tags)
			@project.compiler_set << compiler
		end
		
		def to_tags(list)
			list = [list] unless list.is_a?(Array)
			list.map do |tag|
				case tag
				when Tag, TagAnd, TagOr
					tag
				else
					Tag.new(tag)
				end
			end
		end
	end
end

