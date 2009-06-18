require 'tsort'
require 'thread'
require 'defbuild/helpers'
require 'tempfile'

module DefBuild
	class CompilerBase
		attr_accessor :input_tags, :output_tags
		attr_writer :output_path, :project, :verbose
		
		def tags_match?(tags)
			count = @input_tags.match(tags)
			count > 0 ? count : nil
		end
		
		def inspect
			sprintf "Compiler(%s => %s)", input_tags.inspect, output_tags.inspect
		end
		
		def process_files_base(files, num_jobs = 1)
			@output_path.mkpath
			process_files(files, num_jobs)
		end
		
		def tag(value)
			Tag.new(value)
		end
		
	private
	
		def make_relative(path)
			Helpers.make_relative(path)
		end
	
		def sh(*args)
			Helpers.sh(@verbose, *args)
		end
		
		def trace(*args)
			Helpers.trace(*args)
		end
		
		def response_sh(exe, *args)
			file = Tempfile.new('defbuild')
			args = args.flatten.map do |arg|
				if arg.is_a?(Pathname)
					arg = make_relative(arg)
				end
				if arg =~ /\s/
					arg = '"' + arg + '"'
				end
				arg
			end
			file.write args.join(' ')
			file.close
			if @verbose
				puts 'using response file:', File.read(file.path)
			end
			Helpers.sh(@verbose, exe, '@' + file.path)
			file.delete
		end
		
		def check_dependencies(infile, dfile)
			build = false
			if File.exist?(dfile)
				outputs, inputs = read_make_dependencies(dfile)
				inputs << infile
				build = Helpers.newer?(i, o)
			else
				build = true
			end
			yield if build
		end
		
		def check_optimized_dependencies(infile, dfile)
			if File.exist?(dfile)
				o, i = File.read(dfile).split('|')
				yield if Helpers.newer?((i || '').split(';') << infile, o.split(';'))
			else
				yield
			end
		end
		
		def create_optimized_dependencies(file)
			outputs, inputs = read_make_dependencies(file)
			File.open(file, 'w') {|f| f.write outputs.join(';') + '|' + inputs.join(';') }
		end
		
		def threaded(num_jobs)
			if num_jobs > 1
				(0...num_jobs).map do
					Thread.new do
						yield
					end
				end.each {|t| t.join }
			else
				yield
			end
		end
		
	private
		
		def read_make_dependencies(file)
			inputs = []
			outputs = []
			File.read(file).gsub(/\\\n/, ' ').scan(/("[^"]+"|[^":]+):(.*)/) do |o, i|
				i = i.scan(/("[^"]+"|(\\ |\S)+)/).map {|d| d.first.gsub(/\\ /, ' ') }
				o = o[1...-1] if o =~ /^".*"$/
				i = i.map do |n|
					n =~ /^".*"$/ ? n[1...-1] : n
				end
				inputs.concat(i)
				outputs << o
			end
			return outputs, inputs.uniq
		end
	end
	
	class SingleFileCompiler < CompilerBase
		def initialize(extension)
			@extension = extension
		end
		
		def process_files(files, num_jobs)
			files = files.dup
			mutex = Mutex.new
			
			threaded(num_jobs) do
				loop do
					file = nil
					mutex.synchronize { file = files.shift }
					break unless file
					output_filename = @output_path + (file.path.basename('.*').to_s + @extension)
					compile(file, output_filename)
				end
			end
		end
		
		def output_files(files)
			files.map {|f| InputFile.new(@output_path + (f.path.basename('.*').to_s + @extension), @output_tags, f.context) }
		end
	end
	
	class MultiFileCompiler < CompilerBase
		def process_files(files, num_jobs)
			compile(files) if Helpers.newer?(files.map {|f| f.path.to_s}, output_name.to_s)
		end
		
		def output_files(files)
			[InputFile.new(output_name, @output_tags, @project.global_context)]
		end
	end
	
	class CompilerSet
		include TSort
		def initialize
			@compilers = []
		end
		
		def <<(compiler)
			@compilers << compiler
			self
		end
		
		def find_compiler(tags)
			best_match = nil
			@compilers.each do |c2|
				m = c2.tags_match?(tags)
				if m && (!best_match || m > best_match.tags_match?(tags))
					best_match = c2
				end
			end
			return best_match
		end
		
		def sort
			@children = Hash.new {|h, k| h[k] = [] }
			@compilers.each do |c1|
				best_match = find_compiler(c1.output_tags)
				@children[best_match] << c1 if best_match
			end
			tsort
		end
		
		def tsort_each_node(&block)
			@compilers.each(&block)
		end
		
		def tsort_each_child(node, &block)
			@children[node].each(&block)
		end
	end
end

