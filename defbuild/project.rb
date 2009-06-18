require 'defbuild/inputfile'
require 'defbuild/compilerbase'
require 'defbuild/defmodule'
require 'defbuild/context'
require 'defbuild/compilerbase'
require 'defbuild/tag'
require 'ostruct'

module DefBuild
	class Project
		Import = Struct.new :name, :module, :imported_from
		
		attr_reader :global_context, :files, :compiler_set, :path, :filename, :build_tags, :globals
		attr_reader :build_path, :verbose, :contexts, :modules
		attr_accessor :name
	
		def initialize(project_filename, build_tags)
			@filename = project_filename
			@path = project_filename.dirname
			@build_path = @path + 'build' + build_tags.join('/')
			@modules = []
			@imports = {}
			@import_paths = []
			@contexts = []
			@files = []
			@file_mapping = {}
			@global_context = Context.new(self, nil)
			@compiler_set = CompilerSet.new
			@build_tags = build_tags
			@globals = OpenStruct.new
			@name = 'unnamed'
		end
		
		def read_module(filename)
			path = to_path(filename)
			current_dir = Dir.getwd
			Dir.chdir(path.dirname)
			src = path.readlines
			src = src.map do |line|
				case line
				when /^\s*!\s*(\S+)((\s+(\S+))*)\s*$/
					tags = ($2 || '').strip
					"add_file('#{$1}', '#{tags}')\n"
				else
					line
				end
			end
			
			mod = DefModule.new(self, path.dirname)
			@modules << mod
			mod.instance_eval(src.join, filename.to_s)
			
			Dir.chdir(current_dir)
			
			return mod
		end
		
		def add_import(module_name, importing_module)
			import = @imports[module_name] || Import.new(module_name, nil, [])
			import.imported_from << importing_module
			@imports[module_name] = import
			return import
		end
		
		def add_import_path(path)
			@import_paths << to_path(path)
		end
		
		def register_context(context)
			@contexts << context
		end
		
		def find_module(name, default_filename = 'module.def')
			@import_paths.each do |path|
				module_path = path + name
				if module_path.exist?
					filename = module_path.file? ? module_path : module_path + default_filename
					return filename if filename.file?
				end
			end
			return nil
		end
		
		def resolve_imports
			while @imports.any? {|n, i| !i.module}
				@imports.each do |name, import|
					next if import.module
					full_path = find_module(name)
					if full_path
						import.module = read_module(full_path)
					else
						STDERR.printf "Module '%s' could not be found.\nImported from:\n", name
						import.imported_from.each do |mod|
							STDERR.printf "  %s\n", mod.path
						end
						exit 1
					end
				end
			end
			
			@contexts.each {|context| context.resolve_imports }
		end
		
		def add_file(input_file)
			file = @file_mapping[input_file.path]
			if file
				file.tags = file.tags + input_file.tags
			else
				@files << input_file
				@file_mapping[input_file.path] = input_file
			end
		end
		
		def self.load(filename, build_tags = [])
			filename = to_path(filename)
			project = self.new(filename, build_tags)
			project.add_import_path(filename.dirname)
			project.read_module(filename)
			project.resolve_imports
			return project
		end
	end
end

