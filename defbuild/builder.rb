module DefBuild
	class Builder
		def build(project, num_jobs = 1)
			pwd = Dir.getwd
			Dir.chdir(project.path)
			
			compilers = project.compiler_set.sort
			files = {:out => []}
			compilers.each {|c| files[c] = [] }
			
			project_files = project.files.reject {|f| f.tags.include?('EXCLUDE') }
			project_files.each {|f| files[project.compiler_set.find_compiler(f.tags) || :out] << f }
			compilers.each do |compiler|
				compiler.process_files_base(files[compiler], num_jobs)
				compiler.output_files(files[compiler]).each {|f| files[project.compiler_set.find_compiler(f.tags) || :out] << f }
			end
			
			Dir.chdir(pwd)
			
			return files[:out]
		end
		
		def clean(project)			
			compilers = project.compiler_set.sort
			files = {:out => []}
			output_files = []
			compilers.each {|c| files[c] = [] }
			
			project_files = project.files.reject {|f| f.tags.include?('EXCLUDE') }
			project_files.each {|f| files[project.compiler_set.find_compiler(f.tags) || :out] << f }
			input_files = {}
			files.values.flatten.each {|f| input_files[f.path] = true }
			compilers.each do |compiler|
				compiler.output_files(files[compiler]).each do |f|
					files[project.compiler_set.find_compiler(f.tags) || :out] << f
					output_files << f.path unless input_files.include?(f.path)
				end
			end
			
			printf "Cleaning %s output files\n", output_files.size
			output_files.each do |file|
				if file.exist? && Helpers::is_child_dir_of(file, project.build_path)
					file.delete
				end
			end
		end
	end
end

