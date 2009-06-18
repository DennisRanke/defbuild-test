require 'defbuild/project'
require 'fileutils'

module DefBuild
	class ProjectFileWriterBase
		attr_reader :project, :projects, :builds
		
		def initialize(project_filename, builds)
			builds << 'default' if builds.empty?
			@builds = builds
			@project_mapping = {}
			@projects = builds.map do |build|
				@project_mapping[build] = DefBuild::Project.load(project_filename, build.split('/'))
			end
			@project = @projects.first
		end
		
		def open_file(filename, &block)
			old_pwd = Dir.getwd
			FileUtils.mkpath(File.dirname(filename))
			Dir.chdir(File.dirname(filename))
			File.open(File.basename(filename), 'w', &block)
			Dir.chdir(old_pwd)
		end
		
		def get_attribute(id, build = nil)
			attributes = []
			(build ? [@project_mapping[build]] : @projects).each do |project|
				project.contexts.each do |context|
					attributes.concat(context.get_local_attributes(id))
				end
			end
			return attributes.uniq
		end
		
		def get_files(build = nil)
			files = []
			(build ? [@project_mapping[build]] : @projects).each do |project|
				files.concat(project.files.map {|f| f.path })
			end
			return files.uniq
		end
		
		def find_project(build)
			@project_mapping[build]
		end
		
		def build_command(build)
			"#{Helpers::ruby_exe} #{to_path(__FILE__).dirname.parent + 'defbuild.rb'} -j 2 -b #{build} #{find_project(build).filename}"
		end
	end
end
